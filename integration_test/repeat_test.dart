import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/db/repository.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('repository', () {
    late AppDatabase db;
    late Repository repo;
    late String board, list;
    final now = DateTime(2026, 11, 22, 10);

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = Repository(db, clock: () => now);
      board = await repo.createBoard('Rumah');
      list = await repo.createList(board, 'Rutin');
    });
    tearDown(() => db.close());

    Future<TodoCard> card(String id) =>
        (db.select(db.cards)..where((c) => c.id.equals(id))).getSingle();
    Future<Reminder> rem(String id) =>
        (db.select(db.reminders)..where((r) => r.id.equals(id))).getSingle();

    testWidgets('finishing a daily task reopens it for tomorrow', (tester) async {
      final c = await repo.createCard(list, 'Minum vitamin');
      final item = await repo.addChecklistItem(c, 'Pagi');
      await repo.setChecklistItemDone(item, true);
      final r = await repo.addReminder(
        c,
        DateTime(2026, 11, 22, 8),
        repeatRule: 'daily',
      );

      await repo.setCardCompleted(c, true);

      expect((await card(c)).completedAt, isNull, reason: 'never left completed');
      final after = await rem(r);
      expect(after.remindAt, DateTime(2026, 11, 23, 8));
      expect(after.state, 'scheduled');
      expect(after.snoozedUntil, isNull);
      final items = await db.select(db.checklistItems).get();
      expect(items.single.done, isFalse, reason: 'fresh checklist each cycle');
    });

    testWidgets('due date moves with the cycle', (tester) async {
      final c = await repo.createCard(list, 'Laporan mingguan');
      await repo.updateCard(c, dueAt: Value(DateTime(2026, 11, 20, 17)));
      await repo.addReminder(c, DateTime(2026, 11, 20, 9), repeatRule: 'weekly');

      await repo.setCardCompleted(c, true);

      expect((await card(c)).dueAt, DateTime(2026, 11, 27, 17));
      final r = (await db.select(db.reminders).get()).single;
      expect(r.remindAt, DateTime(2026, 11, 27, 9));
    });

    testWidgets('monthly clamps the day', (tester) async {
      final c = await repo.createCard(list, 'Bayar tagihan');
      final r = await repo.addReminder(
        c,
        DateTime(2026, 1, 31, 9),
        repeatRule: 'monthly',
      );
      await repo.setCardCompleted(c, true);
      // Anchored on 31 Jan and "now" is 22 Nov: first 31st-or-clamped after now.
      expect((await rem(r)).remindAt, DateTime(2026, 11, 30, 9));
    });

    testWidgets('a non-repeating card still completes normally',
        (tester) async {
      final c = await repo.createCard(list, 'Sekali saja');
      final r = await repo.addReminder(c, DateTime(2026, 11, 22, 18));
      await repo.setCardCompleted(c, true);
      expect((await card(c)).completedAt, isNotNull);
      expect((await rem(r)).state, 'done');
    });

    testWidgets('un-completing and deleting the reminder stop repeating',
        (tester) async {
      final c = await repo.createCard(list, 'Rutin');
      final r = await repo.addReminder(c, DateTime(2026, 11, 22, 8),
          repeatRule: 'daily');
      await repo.deleteReminder(r);
      await repo.setCardCompleted(c, true);
      expect((await card(c)).completedAt, isNotNull,
          reason: 'with the repeating reminder gone it completes for real');
    });
  });

  group('ui', () {
    testWidgets('choose Harian in the reminder sheet and finish the card',
        (tester) async {
      final db = await pumpNudge(tester);
      final repo = Repository(db);
      final board = await repo.createBoard('Rumah');
      final list = await repo.createList(board, 'Todo');
      await repo.createCard(list, 'Siram tanaman');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rumah'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siram tanaman'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('add-reminder')));
      await tester.tap(find.byKey(const Key('add-reminder')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('preset-10m')));
      await tester.ensureVisible(find.byKey(const Key('repeat-daily')));
      await tester.tap(find.byKey(const Key('repeat-daily')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('save-reminder')));
      await tester.tap(find.byKey(const Key('save-reminder')));
      await tester.pumpAndSettle();

      final r = (await db.select(db.reminders).get()).single;
      expect(r.repeatRule, 'daily');
      expect(find.textContaining('Harian'), findsWidgets);

      await tester.tap(find.byKey(const Key('detail-complete')));
      await tester.pumpAndSettle();
      final card = (await db.select(db.cards).get()).single;
      expect(card.completedAt, isNull);
      final next = (await db.select(db.reminders).get()).single;
      expect(next.remindAt.isAfter(r.remindAt), isTrue);
      expect(next.remindAt.difference(r.remindAt).inHours, inInclusiveRange(23, 25));
    });
  });
}
