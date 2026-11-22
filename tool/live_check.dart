// Live check of the Supabase schema, RLS and triggers.
//
//   $env:SUPABASE_URL=...; $env:SUPABASE_KEY=...; dart run tool/live_check.dart
//
// Creates two throwaway users, exercises the real server, then deletes the
// data it created. Credentials come from the environment only.
// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';

import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
var _failures = 0;
var _passes = 0;

void check(String name, bool ok, [String? detail]) {
  if (ok) {
    _passes++;
    print('  PASS  $name');
  } else {
    _failures++;
    print('  FAIL  $name${detail == null ? '' : '  -> $detail'}');
  }
}

Future<bool> rejects(Future<Object?> Function() op) async {
  try {
    await op();
    return false;
  } on PostgrestException {
    return true;
  }
}

String ts([Duration offset = Duration.zero]) =>
    DateTime.now().toUtc().add(offset).toIso8601String();

Future<void> main() async {
  final url = Platform.environment['SUPABASE_URL'];
  final key = Platform.environment['SUPABASE_KEY'];
  if (url == null || key == null) {
    print('Set SUPABASE_URL and SUPABASE_KEY.');
    exit(2);
  }

  // Either pre-created users (no sign-up emails, avoids rate limits):
  //   USER_A_EMAIL / USER_A_PASSWORD / USER_B_EMAIL / USER_B_PASSWORD
  // or fresh sign-ups (needs "Confirm email" OFF and email quota available).
  final env = Platform.environment;
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final emailA = env['USER_A_EMAIL'] ?? 'nudge.a.$stamp@mailinator.com';
  final emailB = env['USER_B_EMAIL'] ?? 'nudge.b.$stamp@mailinator.com';
  final passA = env['USER_A_PASSWORD'] ?? 'Nudge-test-12345';
  final passB = env['USER_B_PASSWORD'] ?? 'Nudge-test-12345';
  final existing = env['USER_A_EMAIL'] != null && env['USER_B_EMAIL'] != null;

  // Pure Dart has no storage for the PKCE verifier: use the implicit flow.
  const opts = AuthClientOptions(authFlowType: AuthFlowType.implicit);
  final a = SupabaseClient(url, key, authOptions: opts);
  final b = SupabaseClient(url, key, authOptions: opts);

  print('1. Auth (${existing ? 'sign in' : 'sign up'})');
  Future<String?> login(SupabaseClient c, String email, String pass) async {
    try {
      final r = existing
          ? await c.auth.signInWithPassword(email: email, password: pass)
          : await c.auth.signUp(email: email, password: pass);
      if (r.session == null) {
        print('     no session (email confirmation is ON)');
        return null;
      }
      return r.user!.id;
    } on AuthException catch (e) {
      print('     auth error: ${e.message}');
      return null;
    }
  }

  final idA = await login(a, emailA, passA);
  final idB = await login(b, emailB, passB);
  check('user A has a session', idA != null);
  check('user B has a session', idB != null);
  if (idA == null || idB == null) {
    print('\nCannot continue without sessions.');
    exit(1);
  }
  final board = _uuid.v4();
  final list = _uuid.v4();
  final card = _uuid.v4();
  final item = _uuid.v4();
  final reminder = _uuid.v4();
  final now = ts();

  try {
    print('2. Owner can write and read own data');
    await a.from('boards').insert({
      'id': board, 'user_id': idA, 'title': 'Board A',
      'created_at': now, 'updated_at': now,
    });
    await a.from('lists').insert({
      'id': list, 'user_id': idA, 'board_id': board, 'title': 'List A',
      'created_at': now, 'updated_at': now,
    });
    await a.from('cards').insert({
      'id': card, 'user_id': idA, 'list_id': list, 'board_id': board,
      'title': 'Card A', 'created_at': now, 'updated_at': now,
    });
    await a.from('checklist_items').insert({
      'id': item, 'user_id': idA, 'card_id': card, 'text': 'Item',
      'created_at': now, 'updated_at': now,
    });
    await a.from('reminders').insert({
      'id': reminder, 'user_id': idA, 'card_id': card, 'remind_at': now,
      'created_at': now, 'updated_at': now,
    });
    final mine = await a.from('cards').select().eq('id', card);
    check('A reads own card', mine.length == 1);
    check('server_updated_at is stamped',
        mine.isNotEmpty && mine.first['server_updated_at'] != null);

    print('3. Isolation between users');
    check('B cannot see A\'s boards',
        (await b.from('boards').select().eq('id', board)).isEmpty);
    check('B cannot see A\'s cards',
        (await b.from('cards').select().eq('id', card)).isEmpty);
    check('B cannot see A\'s reminders',
        (await b.from('reminders').select().eq('id', reminder)).isEmpty);

    await b.from('cards').update({'title': 'hacked'}).eq('id', card);
    final after = await a.from('cards').select('title').eq('id', card);
    check('B cannot update A\'s card', after.first['title'] == 'Card A');

    await b.from('cards').delete().eq('id', card);
    check('B cannot delete A\'s card',
        (await a.from('cards').select().eq('id', card)).length == 1);

    check(
      'B cannot insert a row owned by A',
      await rejects(() => b.from('boards').insert({
            'id': _uuid.v4(), 'user_id': idA, 'title': 'spoof',
            'created_at': now, 'updated_at': now,
          })),
    );
    check(
      'B cannot attach a list to A\'s board (FK bypass)',
      await rejects(() => b.from('lists').insert({
            'id': _uuid.v4(), 'user_id': idB, 'board_id': board,
            'title': 'sneaky', 'created_at': now, 'updated_at': now,
          })),
    );
    check(
      'B cannot attach a card to A\'s list',
      await rejects(() => b.from('cards').insert({
            'id': _uuid.v4(), 'user_id': idB, 'list_id': list,
            'board_id': board, 'title': 'sneaky',
            'created_at': now, 'updated_at': now,
          })),
    );
    check(
      'B cannot attach a reminder to A\'s card',
      await rejects(() => b.from('reminders').insert({
            'id': _uuid.v4(), 'user_id': idB, 'card_id': card,
            'remind_at': now, 'created_at': now, 'updated_at': now,
          })),
    );

    print('4. Last-write-wins guard');
    await a.from('cards').upsert({
      'id': card, 'user_id': idA, 'list_id': list, 'board_id': board,
      'title': 'STALE', 'created_at': now,
      'updated_at': ts(const Duration(days: -1)),
    }, onConflict: 'id');
    var row = (await a.from('cards').select('title').eq('id', card)).first;
    check('stale write (older updated_at) is ignored', row['title'] == 'Card A');

    await a.from('cards').upsert({
      'id': card, 'user_id': idA, 'list_id': list, 'board_id': board,
      'title': 'Newer', 'created_at': now,
      'updated_at': ts(const Duration(minutes: 5)),
    }, onConflict: 'id');
    row = (await a.from('cards').select('title').eq('id', card)).first;
    check('newer write wins', row['title'] == 'Newer');

    print('5. Completing a card settles its reminders');
    final before = (await a.from('reminders').select('state').eq('id', reminder))
        .first['state'];
    await a.from('cards').update({
      'completed_at': ts(const Duration(minutes: 6)),
      'updated_at': ts(const Duration(minutes: 6)),
    }).eq('id', card);
    final settled =
        (await a.from('reminders').select('state').eq('id', reminder)).first;
    check('reminder was "$before" before', before == 'scheduled');
    check('reminder becomes "done" via trigger', settled['state'] == 'done');

    print('6. Constraints');
    check(
      'bad reminder state is rejected',
      await rejects(() => a.from('reminders').update({'state': 'bogus'}).eq('id', reminder)),
    );
    check(
      'nag interval out of range is rejected',
      await rejects(() => a
          .from('reminders')
          .update({'nag_interval_minutes': 0}).eq('id', reminder)),
    );

    print('7. Pull cursor');
    final since = await a
        .from('cards')
        .select('id, server_updated_at')
        .gte('server_updated_at', now)
        .order('server_updated_at');
    check('cursor query returns the card', since.any((r) => r['id'] == card));
  } finally {
    print('Cleanup');
    try {
      await a.from('boards').delete().eq('id', board); // cascades
    } catch (e) {
      print('  cleanup A failed: $e');
    }
    await a.auth.signOut();
    await b.auth.signOut();
    await a.dispose();
    await b.dispose();
  }

  print('\n$_passes passed, $_failures failed');
  exit(_failures == 0 ? 0 : 1);
}
