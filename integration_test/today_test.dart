import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/db/repository.dart';
import 'package:nudge/core/nag/local_notifications_gateway.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryNotificationGateway gateway;

  Future<(AppDatabase, Repository, String)> start(WidgetTester tester) async {
    gateway = InMemoryNotificationGateway();
    final db = await pumpNudge(tester, gateway: gateway, startOnBoards: false);
    final repo = Repository(db);
    final board = await repo.createBoard('Rumah');
    final list = await repo.createList(board, 'Todo');
    await tester.pumpAndSettle();
    return (db, repo, list);
  }

  testWidgets('groups cards: overdue, today, pinned; ignores the rest',
      (tester) async {
    final (_, repo, list) = await start(tester);
    final now = DateTime.now();
    final overdue = await repo.createCard(list, 'Bayar pajak');
    await repo.updateCard(overdue,
        dueAt: Value(DateTime(now.year, now.month, now.day - 2)));
    final today = await repo.createCard(list, 'Kirim laporan');
    await repo.updateCard(today,
        dueAt: Value(DateTime(now.year, now.month, now.day, 23, 59)));
    final pinned = await repo.createCard(list, 'Catatan penting');
    await repo.updateCard(pinned, pinned: true);
    await repo.createCard(list, 'Tidak mendesak');
    await tester.pumpAndSettle();

    expect(find.text('Terlewat'), findsOneWidget);
    expect(find.text('Hari ini'), findsWidgets); // title + group header
    expect(find.text('Ter-pin'), findsOneWidget);
    expect(find.text('Bayar pajak'), findsOneWidget);
    expect(find.text('Kirim laporan'), findsOneWidget);
    expect(find.text('Catatan penting'), findsOneWidget);
    expect(find.text('Tidak mendesak'), findsNothing);
    expect(find.text('Rumah › Todo'), findsNWidgets(3));
  });

  testWidgets('complete from Today removes the item; tap opens the card',
      (tester) async {
    final (db, repo, list) = await start(tester);
    final id = await repo.createCard(list, 'Telepon bank');
    await repo.updateCard(id, pinned: true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Telepon bank'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-title')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('today-complete-Telepon bank')));
    await tester.pumpAndSettle();
    expect(find.text('Telepon bank'), findsNothing);
    expect(find.byKey(const Key('today-empty')), findsOneWidget);
    final card = await (db.select(db.cards)..where((c) => c.id.equals(id)))
        .getSingle();
    expect(card.completedAt, isNotNull);
  });

  testWidgets('a reminder due today shows up with its time', (tester) async {
    final (_, repo, list) = await start(tester);
    final id = await repo.createCard(list, 'Minum obat');
    final at = DateTime.now().add(const Duration(minutes: 20));
    // Only meaningful if +20min is still today.
    if (at.day != DateTime.now().day) return;
    await repo.addReminder(id, at);
    await tester.pumpAndSettle();
    expect(find.text('Minum obat'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active), findsWidgets);
  });

  testWidgets('pause all reminders: schedule empties, resume restores it',
      (tester) async {
    final (_, repo, list) = await start(tester);
    final id = await repo.createCard(list, 'Siram tanaman');
    await repo.addReminder(
      id,
      DateTime.now().add(const Duration(minutes: 30)),
      intervalMinutes: 10,
      maxCount: 4, // all four fall within the next ~hour
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(gateway.scheduled.length, 4);

    await tester.tap(find.byKey(const Key('pause-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pause-1h')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('paused-banner')), findsOneWidget);
    expect(gateway.scheduled, isEmpty,
        reason: 'everything fires before the pause ends');

    await tester.tap(find.byKey(const Key('resume-banner')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('paused-banner')), findsNothing);
    expect(gateway.scheduled.length, 4);
  });

  testWidgets('pause survives restart via preferences', (tester) async {
    final until = DateTime.now().add(const Duration(hours: 2));
    await pumpNudge(
      tester,
      startOnBoards: false,
      prefsValues: {'paused_until_ms': until.millisecondsSinceEpoch},
    );
    expect(find.byKey(const Key('paused-banner')), findsOneWidget);
  });

  testWidgets('an expired pause is ignored on startup', (tester) async {
    await pumpNudge(
      tester,
      startOnBoards: false,
      prefsValues: {
        'paused_until_ms': DateTime.now()
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      },
    );
    expect(find.byKey(const Key('paused-banner')), findsNothing);
  });
  testWidgets('warns when notifications are blocked and can re-enable',
      (tester) async {
    gateway = InMemoryNotificationGateway()..allowed = false;
    await pumpNudge(tester, gateway: gateway, startOnBoards: false);
    expect(find.byKey(const Key('perm-banner')), findsOneWidget);

    gateway.allowed = true; // user grants it in the system dialog
    await tester.tap(find.byKey(const Key('perm-enable')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('perm-banner')), findsNothing);
  });
}
