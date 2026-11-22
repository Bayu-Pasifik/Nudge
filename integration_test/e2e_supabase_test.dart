import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/db/repository.dart';
import 'package:nudge/core/sync/supabase_remote.dart';
import 'package:nudge/core/sync/sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Real Supabase, two simulated devices on the same account. Run with:
///   flutter test integration_test/e2e_supabase_test.dart -d DEVICE_ID
///     --dart-define=NUDGE_E2E=true --dart-define=SUPABASE_URL=... \
///     --dart-define=SUPABASE_PUBLISHABLE_KEY=... \
///     --dart-define=E2E_EMAIL=... --dart-define=E2E_PASSWORD=...
const _e2e = bool.fromEnvironment('NUDGE_E2E');
const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _email = String.fromEnvironment('E2E_EMAIL');
const _password = String.fromEnvironment('E2E_PASSWORD');

class Dev {
  Dev(this.name, this.client, SharedPreferences prefs)
      : db = AppDatabase(NativeDatabase.memory()) {
    repo = Repository(db);
    remote = SupabaseRemote(client);
    engine = SyncEngine(db, remote, prefs, namespace: name);
  }
  final String name;
  final SupabaseClient client;
  final AppDatabase db;
  late final Repository repo;
  late final SupabaseRemote remote;
  late final SyncEngine engine;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('two devices sync through real Supabase', (tester) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      Future<SupabaseClient> login() async {
        final c = SupabaseClient(_url, _key);
        await c.auth.signInWithPassword(email: _email, password: _password);
        return c;
      }

      final a = Dev('A', await login(), prefs);
      final b = Dev('B', await login(), prefs);
      String? boardId;

      try {
        // --- device A creates data and pushes
        boardId = await a.repo.createBoard('E2E ${DateTime.now().millisecondsSinceEpoch}');
        final list = await a.repo.createList(boardId, 'Todo');
        final card = await a.repo.createCard(list, 'Bayar listrik');
        final item = await a.repo.addChecklistItem(card, 'Cek meteran');
        final reminder = await a.repo.addReminder(
          card,
          DateTime.now().add(const Duration(hours: 1)),
          intervalMinutes: 5,
          maxCount: 7,
          escalationJson: '[{"after":3,"level":2}]',
          quietStartMinute: 1320,
          quietEndMinute: 420,
        );
        final r1 = await a.engine.sync();
        expect(r1.pushed, 5, reason: 'board, list, card, item, reminder');

        // --- device B pulls everything, intact
        final r2 = await b.engine.sync();
        expect(r2.applied, greaterThanOrEqualTo(5));
        final bCard = await (b.db.select(b.db.cards)..where((c) => c.id.equals(card))).getSingle();
        expect(bCard.title, 'Bayar listrik');
        final bRem = await (b.db.select(b.db.reminders)..where((r) => r.id.equals(reminder))).getSingle();
        expect(bRem.nagIntervalMinutes, 5);
        expect(bRem.nagMaxCount, 7);
        expect(bRem.escalation, '[{"after":3,"level":2}]');
        expect(bRem.quietStartMinute, 1320);
        // time zone round trip: same instant, still local time for the UI
        final aRem = await (a.db.select(a.db.reminders)..where((r) => r.id.equals(reminder))).getSingle();
        expect(bRem.remindAt.isAtSameMomentAs(aRem.remindAt), isTrue);
        expect(bRem.remindAt.isUtc, isFalse);

        // --- B edits; A pulls
        await Future<void>.delayed(const Duration(seconds: 1));
        await b.repo.updateCard(card, title: 'Bayar listrik & air');
        await b.engine.sync();
        await a.engine.sync();
        final aCard = await (a.db.select(a.db.cards)..where((c) => c.id.equals(card))).getSingle();
        expect(aCard.title, 'Bayar listrik & air');

        // --- completion on A stops nagging on B
        await Future<void>.delayed(const Duration(seconds: 1));
        await a.repo.setCardCompleted(card, true);
        await a.engine.sync();
        await b.engine.sync();
        expect(await b.repo.activeReminders(), isEmpty,
            reason: 'nagging must stop on the other device');
        final done = await (b.db.select(b.db.reminders)..where((r) => r.id.equals(reminder))).getSingle();
        expect(done.state, 'done');

        // --- offline-style stale edit loses (B edits with an old clock)
        final stale = Repository(b.db, clock: () => DateTime.now().subtract(const Duration(hours: 2)));
        await stale.updateCard(card, title: 'STALE dari B');
        await b.engine.sync();
        await a.engine.sync();
        final after = await (a.db.select(a.db.cards)..where((c) => c.id.equals(card))).getSingle();
        expect(after.title, isNot('STALE dari B'));

        // --- checklist + delete propagate
        await Future<void>.delayed(const Duration(seconds: 1));
        await a.repo.setChecklistItemDone(item, true);
        await a.repo.deleteCard(card);
        await a.engine.sync();
        await b.engine.sync();
        final bItem = await (b.db.select(b.db.checklistItems)..where((i) => i.id.equals(item))).getSingle();
        expect(bItem.done, isTrue);
        final gone = await (b.db.select(b.db.cards)..where((c) => c.id.equals(card))).getSingle();
        expect(gone.deletedAt, isNotNull);

        // --- idempotent: nothing left to push or apply
        final idle = await a.engine.sync();
        expect(idle.pushed, 0);

        // --- realtime: A's change makes B's channel fire
        final fired = Completer<void>();
        final sub = b.remote.changes().listen((_) {
          if (!fired.isCompleted) fired.complete();
        });
        await Future<void>.delayed(const Duration(seconds: 3)); // subscribe
        await Future<void>.delayed(const Duration(seconds: 1));
        await a.repo.updateBoard(boardId, title: 'Realtime ping');
        await a.engine.sync();
        await fired.future.timeout(const Duration(seconds: 15),
            onTimeout: () => throw TestFailure('no realtime event within 15s'));
        await sub.cancel();
      } finally {
        if (boardId != null) {
          try {
            await a.client.from('boards').delete().eq('id', boardId); // cascades
          } catch (e) {
            // ignore: avoid_print
            print('cleanup failed: $e');
          }
        }
        await a.remote.dispose();
        await b.remote.dispose();
        await a.client.auth.signOut();
        await b.client.auth.signOut();
        await a.db.close();
        await b.db.close();
      }
    });
  }, skip: !_e2e, timeout: const Timeout(Duration(minutes: 3)));
}
