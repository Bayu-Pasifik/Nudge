import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/db/repository.dart';
import 'package:nudge/core/sync/fake_remote.dart';
import 'package:nudge/core/sync/sync_engine.dart';
import 'package:nudge/core/sync/sync_tables.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two simulated devices (own DB + own clock) syncing through a fake server.
class Device {
  Device(this.name, FakeRemote remote, SharedPreferences prefs)
      : db = AppDatabase(NativeDatabase.memory()) {
    repo = Repository(db, clock: () => now);
    engine = SyncEngine(db, remote, prefs, namespace: name);
  }

  final String name;
  final AppDatabase db;
  late final Repository repo;
  late final SyncEngine engine;
  DateTime now = DateTime(2026, 11, 22, 10);

  void advance([Duration d = const Duration(minutes: 1)]) => now = now.add(d);

  Future<TodoCard> card(String id) =>
      (db.select(db.cards)..where((c) => c.id.equals(id))).getSingle();
  Future<Reminder> reminder(String id) =>
      (db.select(db.reminders)..where((r) => r.id.equals(id))).getSingle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeRemote remote;
  late Device a;
  late Device b;

  Future<void> setUpDevices() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    remote = FakeRemote();
    a = Device('A', remote, prefs);
    b = Device('B', remote, prefs);
    addTearDown(() async {
      await a.db.close();
      await b.db.close();
    });
  }

  /// Board > list > card (+ checklist item + reminder) created on [d].
  Future<({String board, String list, String card, String item, String reminder})>
      seed(Device d) async {
    final board = await d.repo.createBoard('Rumah');
    final list = await d.repo.createList(board, 'Todo');
    final card = await d.repo.createCard(list, 'Bayar listrik');
    final item = await d.repo.addChecklistItem(card, 'Cek meteran');
    final reminder = await d.repo.addReminder(
      card,
      DateTime(2026, 11, 22, 18),
      intervalMinutes: 5,
      maxCount: 7,
      escalationJson: '[{"after":3,"level":2}]',
      quietStartMinute: 1320,
      quietEndMinute: 420,
    );
    return (board: board, list: list, card: card, item: item, reminder: reminder);
  }

  testWidgets('push: dirty rows reach the server and become clean',
      (tester) async {
    await setUpDevices();
    final ids = await seed(a);

    final r1 = await a.engine.sync();
    expect(r1.pushed, 5); // board, list, card, checklist item, reminder
    expect(remote.tables['boards']!.keys, contains(ids.board));
    expect(remote.tables['cards']![ids.card]!['title'], 'Bayar listrik');
    expect(remote.tables['cards']![ids.card]!['user_id'], remote.userId);
    expect(remote.tables['reminders']![ids.reminder]!['nag_interval_minutes'], 5);

    for (final t in syncTables) {
      expect(await t.dirty(a.db, remote.userId), isEmpty, reason: t.name);
    }

    // Nothing left to do: a second sync neither pushes nor changes anything.
    final r2 = await a.engine.sync();
    expect(r2.pushed, 0);
    expect(r2.applied, 0);
  });

  testWidgets('pull: a fresh device receives everything, fully intact',
      (tester) async {
    await setUpDevices();
    final ids = await seed(a);
    await a.engine.sync();

    final r = await b.engine.sync();
    expect(r.applied, 5);
    expect(r.pushed, 0, reason: 'pulled rows are clean, nothing to push back');

    final card = await b.card(ids.card);
    expect(card.title, 'Bayar listrik');
    expect(card.listId, ids.list);
    final rem = await b.reminder(ids.reminder);
    expect(rem.nagIntervalMinutes, 5);
    expect(rem.nagMaxCount, 7);
    expect(rem.escalation, '[{"after":3,"level":2}]');
    expect(rem.quietStartMinute, 1320);
    expect(rem.remindAt, DateTime(2026, 11, 22, 18));
    final items = await b.db.select(b.db.checklistItems).get();
    expect(items.single.text_, 'Cek meteran');

    // And B can immediately use it through its own repository.
    final boards = await b.repo.watchBoards().first;
    expect(boards.single.title, 'Rumah');
  });

  testWidgets('last write wins: the newer edit survives on both devices',
      (tester) async {
    await setUpDevices();
    final ids = await seed(a);
    await a.engine.sync();
    await b.engine.sync();

    // Both edit the same card offline; B's edit is later.
    a.advance(const Duration(minutes: 5));
    await a.repo.updateCard(ids.card, title: 'Edit dari A');
    b.now = a.now.add(const Duration(minutes: 3));
    await b.repo.updateCard(ids.card, title: 'Edit dari B');

    await a.engine.sync(); // A pushes first
    await b.engine.sync(); // B pulls A's (older) edit: ignored, pushes its own
    await a.engine.sync(); // A pulls the winner

    expect((await a.card(ids.card)).title, 'Edit dari B');
    expect((await b.card(ids.card)).title, 'Edit dari B');
    expect(remote.tables['cards']![ids.card]!['title'], 'Edit dari B');
  });

  testWidgets('a newer remote edit replaces an older local dirty edit',
      (tester) async {
    await setUpDevices();
    final ids = await seed(a);
    await a.engine.sync();
    await b.engine.sync();

    b.advance(const Duration(minutes: 1));
    await b.repo.updateCard(ids.card, title: 'Lokal lama');
    a.now = b.now.add(const Duration(minutes: 10));
    await a.repo.updateCard(ids.card, title: 'Remote baru');
    await a.engine.sync();

    await b.engine.sync();
    expect((await b.card(ids.card)).title, 'Remote baru');
  });

  testWidgets('completing on one device settles the reminder on the other',
      (tester) async {
    await setUpDevices();
    final ids = await seed(a);
    await a.engine.sync();
    await b.engine.sync();
    expect((await b.reminder(ids.reminder)).state, 'scheduled');

    a.advance();
    await a.repo.setCardCompleted(ids.card, true);
    await a.engine.sync();
    await b.engine.sync();

    expect((await b.card(ids.card)).completedAt, isNotNull);
    expect((await b.reminder(ids.reminder)).state, 'done',
        reason: 'nagging must stop on the other device too');
    // B's open-reminder list no longer contains it => no more nags there.
    expect(await b.repo.activeReminders(), isEmpty);
  });

  testWidgets('un-completing propagates too', (tester) async {
    await setUpDevices();
    final ids = await seed(a);
    await a.engine.sync();
    await b.engine.sync();
    a.advance();
    await a.repo.setCardCompleted(ids.card, true);
    await a.engine.sync();
    await b.engine.sync();

    b.now = a.now.add(const Duration(minutes: 2));
    await b.repo.setCardCompleted(ids.card, false);
    await b.engine.sync();
    await a.engine.sync();
    expect((await a.card(ids.card)).completedAt, isNull);
  });

  testWidgets('deletes (tombstones) propagate', (tester) async {
    await setUpDevices();
    final ids = await seed(a);
    await a.engine.sync();
    await b.engine.sync();

    a.advance();
    await a.repo.deleteCard(ids.card);
    await a.engine.sync();
    await b.engine.sync();

    expect((await b.card(ids.card)).deletedAt, isNotNull);
    final open = await b.repo.watchOpenCards().first;
    expect(open, isEmpty);
  });

  testWidgets('offline: changes stay dirty and sync later', (tester) async {
    await setUpDevices();
    final ids = await seed(a);

    remote.offline = true;
    await expectLater(a.engine.sync(), throwsStateError);
    expect((await a.card(ids.card)).dirty, isTrue);
    expect(remote.tables, isEmpty);

    // Keeps working locally while offline.
    a.advance();
    await a.repo.updateCard(ids.card, title: 'Diedit offline');

    remote.offline = false;
    await a.engine.sync();
    expect(remote.tables['cards']![ids.card]!['title'], 'Diedit offline');
    expect((await a.card(ids.card)).dirty, isFalse);
  });

  testWidgets('an edit made while pushing is not marked clean',
      (tester) async {
    await setUpDevices();
    final ids = await seed(a);
    final cards = syncTables.firstWhere((t) => t.name == 'cards');

    final snapshot = (await cards.dirty(a.db, remote.userId)).single;
    // User edits again after the snapshot but before markClean.
    a.advance(const Duration(seconds: 1));
    await a.repo.updateCard(ids.card, title: 'Ketik lagi');
    await cards.markClean(a.db, snapshot.id, snapshot.updatedAt);

    final card = await a.card(ids.card);
    expect(card.dirty, isTrue, reason: 'newer edit must still be pushed');
    await a.engine.sync();
    expect(remote.tables['cards']![ids.card]!['title'], 'Ketik lagi');
  });

  testWidgets('the server ignores stale writes', (tester) async {
    await setUpDevices();
    final ids = await seed(a);
    await a.engine.sync();

    final stale = Map.of(remote.tables['cards']![ids.card]!)
      ..['title'] = 'stale'
      ..['updated_at'] =
          DateTime(2020).toUtc().toIso8601String(); // far in the past
    await remote.upsert('cards', [stale]);
    expect(remote.tables['cards']![ids.card]!['title'], 'Bayar listrik');
  });

  testWidgets('rows from another user are never mixed in', (tester) async {
    await setUpDevices();
    await seed(a);
    await a.engine.sync();
    // A different account has its own (empty) server state.
    final other = FakeRemote(userId: 'user-2');
    final prefs = await SharedPreferences.getInstance();
    final c = Device('C', other, prefs);
    addTearDown(c.db.close);
    final r = await c.engine.sync();
    expect(r.pulled, 0);
    expect(await c.repo.watchBoards().first, isEmpty);
  });

  testWidgets('ordering of new items is kept across devices', (tester) async {
    await setUpDevices();
    final ids = await seed(a);
    final c2 = await a.repo.createCard(ids.list, 'Kedua');
    final c3 = await a.repo.createCard(ids.list, 'Ketiga');
    await a.repo.moveCard(c3, ids.list, 0);
    await a.engine.sync();
    await b.engine.sync();

    final cards = await b.repo.watchCards(ids.board).first;
    expect(cards.map((c) => c.title), ['Ketiga', 'Bayar listrik', 'Kedua']);
    expect(c2, isNotEmpty);
    // Value import is exercised so analyzer keeps it for later tests.
    expect(const Value(1).present, isTrue);
  });
}
