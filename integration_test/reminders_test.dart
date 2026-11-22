import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/db/repository.dart';
import 'package:nudge/core/nag/local_notifications_gateway.dart';
import 'package:nudge/core/nag/nag_actions.dart';
import 'package:nudge/core/nag/nag_scheduler.dart';
import 'package:nudge/core/nag/notification_gateway.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryNotificationGateway gateway;

  Future<(AppDatabase, Repository, String)> openCard(WidgetTester tester) async {
    gateway = InMemoryNotificationGateway();
    final db = await pumpNudge(tester, gateway: gateway);
    final repo = Repository(db);
    final board = await repo.createBoard('Rumah');
    final list = await repo.createList(board, 'Todo');
    final card = await repo.createCard(list, 'Minum obat');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minum obat'));
    await tester.pumpAndSettle();
    return (db, repo, card);
  }

  /// Lets the debounced coordinator rebuild the schedule.
  Future<void> settleSchedule(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('add a reminder from the card: nag sequence gets scheduled',
      (tester) async {
    final (db, _, cardId) = await openCard(tester);

    await tester.ensureVisible(find.byKey(const Key('add-reminder')));
    await tester.tap(find.byKey(const Key('add-reminder')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preset-1h')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('interval-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('max-10')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-reminder')));
    await tester.tap(find.byKey(const Key('save-reminder')));
    await tester.pumpAndSettle();
    await settleSchedule(tester);

    final rows = await db.select(db.reminders).get();
    expect(rows.length, 1);
    expect(rows.single.cardId, cardId);
    expect(rows.single.nagIntervalMinutes, 5);
    expect(rows.single.nagMaxCount, 10);
    expect(rows.single.escalation, isNotNull);

    final s = gateway.scheduled;
    expect(s, isNotEmpty);
    expect(s.length, lessThanOrEqualTo(10), reason: 'maxCount caps the sequence');
    expect(s.first.title, 'Minum obat');
    expect(s.first.body, 'Rumah › Todo');
    expect(s.first.index, 0);
    // ~1 hour from now, then every 5 minutes (quiet hours may drop repeats).
    final inFuture = s.first.at.difference(DateTime.now());
    expect(inFuture.inMinutes, inInclusiveRange(58, 61));
    expect(find.textContaining('Ulang tiap 5 mnt'), findsOneWidget);
  });

  testWidgets('completing the card stops all nagging', (tester) async {
    final (_, repo, cardId) = await openCard(tester);
    await repo.addReminder(
      cardId,
      DateTime.now().add(const Duration(minutes: 30)),
      intervalMinutes: 5,
    );
    await settleSchedule(tester);
    expect(gateway.scheduled, isNotEmpty);

    await tester.tap(find.byKey(const Key('detail-complete')));
    await tester.pumpAndSettle();
    await settleSchedule(tester);
    expect(gateway.scheduled, isEmpty);
  });

  testWidgets('deleting the reminder removes its notifications',
      (tester) async {
    final (db, repo, cardId) = await openCard(tester);
    final id = await repo.addReminder(
      cardId,
      DateTime.now().add(const Duration(minutes: 30)),
    );
    await settleSchedule(tester);
    expect(gateway.scheduled, isNotEmpty);

    await tester.ensureVisible(find.byKey(Key('delete-reminder-$id')));
    await tester.tap(find.byKey(Key('delete-reminder-$id')));
    await tester.pumpAndSettle();
    await settleSchedule(tester);
    expect(gateway.scheduled, isEmpty);
    final row = await (db.select(db.reminders)..where((r) => r.id.equals(id)))
        .getSingle();
    expect(row.deletedAt, isNotNull);
  });

  testWidgets('"Selesai" and "Tunda" notification actions', (tester) async {
    final (db, repo, cardId) = await openCard(tester);
    final reminderId = await repo.addReminder(
      cardId,
      DateTime.now().add(const Duration(minutes: 1)),
      intervalMinutes: 10,
    );
    final scheduler = NagScheduler(repo, gateway);
    await scheduler.rescheduleAll();
    final payload = NagPayload(reminderId, cardId);

    // Tunda: sequence restarts ~10 minutes from now.
    await handleNagAction(repo, scheduler, NagAction.snooze, payload);
    final snoozed = await (db.select(db.reminders)
          ..where((r) => r.id.equals(reminderId)))
        .getSingle();
    expect(snoozed.snoozedUntil, isNotNull);
    expect(gateway.scheduled.first.at.difference(DateTime.now()).inMinutes,
        inInclusiveRange(9, 10));

    // Selesai: card completed, reminder done, nothing left scheduled.
    await handleNagAction(repo, scheduler, NagAction.done, payload);
    final card = await (db.select(db.cards)..where((c) => c.id.equals(cardId)))
        .getSingle();
    expect(card.completedAt, isNotNull);
    final done = await (db.select(db.reminders)
          ..where((r) => r.id.equals(reminderId)))
        .getSingle();
    expect(done.state, 'done');
    expect(gateway.scheduled, isEmpty);
  });

  testWidgets('reminder past its max count becomes "missed"', (tester) async {
    final (db, repo, cardId) = await openCard(tester);
    final id = await repo.addReminder(
      cardId,
      DateTime.now().subtract(const Duration(hours: 2)),
      intervalMinutes: 10,
      maxCount: 3,
    );
    await NagScheduler(repo, gateway).rescheduleAll();
    final r = await (db.select(db.reminders)..where((x) => x.id.equals(id)))
        .getSingle();
    expect(r.state, 'missed');
    expect(gateway.scheduled, isEmpty);
  });

  testWidgets('escalation levels rise across the scheduled sequence',
      (tester) async {
    final (_, repo, cardId) = await openCard(tester);
    await repo.addReminder(
      cardId,
      DateTime.now().add(const Duration(minutes: 2)),
      intervalMinutes: 1,
      escalationJson: '[{"after":3,"level":2},{"after":6,"level":3}]',
    );
    await NagScheduler(repo, gateway, perReminderLimit: 8).rescheduleAll();
    final levels = gateway.scheduled.map((n) => n.level).toList();
    expect(levels.first, 1);
    expect(levels, containsAllInOrder([1, 2, 3]));
  });

  testWidgets('global cap keeps only the earliest notifications',
      (tester) async {
    final (_, repo, cardId) = await openCard(tester);
    await repo.addReminder(
      cardId,
      DateTime.now().add(const Duration(minutes: 2)),
      intervalMinutes: 1,
    );
    await NagScheduler(repo, gateway, maxTotal: 5).rescheduleAll();
    expect(gateway.scheduled.length, 5);
    final times = gateway.scheduled.map((n) => n.at).toList();
    expect([...times]..sort(), times, reason: 'earliest first');
  });
}
