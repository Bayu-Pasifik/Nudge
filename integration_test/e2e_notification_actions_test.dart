import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/db/repository.dart';
import 'package:nudge/core/nag/local_notifications_gateway.dart';
import 'package:nudge/core/nag/nag_scheduler.dart';
import 'package:nudge/main.dart' show nudgeNotificationBackground;
import 'package:nudge/core/nag/nag_actions.dart';
import 'package:nudge/core/nag/notification_gateway.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Needs an external driver (tool/drive_notification_actions.ps1) that presses
/// "Tunda 10 mnt" then "Selesai" on the real notifications via adb.
/// Only runs with --dart-define=NUDGE_E2E=true (needs a real device and, for
/// button presses, tool/drive_notification_actions.ps1).
const _e2e = bool.fromEnvironment('NUDGE_E2E');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real notification buttons: Tunda then Selesai', (tester) async {
    await tester.runAsync(() async {
      final gateway = LocalNotificationsGateway();
      final db = AppDatabase();
      final repo = Repository(db);
      final scheduler = NagScheduler(repo, gateway);

      Future<void> onResponse(NotificationResponse r) async {
        final action = nagActionFrom(r);
        final payload = NagPayload.parse(r.payload);
        if (action == null || payload == null || action == NagAction.open) return;
        await handleNagAction(repo, scheduler, action, payload);
      }

      await gateway.init(
        onResponse: onResponse,
        onBackgroundResponse: nudgeNotificationBackground,
      );
      // The driver script grants the permission once the APK is installed.
      for (var i = 0; i < 120 && !await gateway.notificationsAllowed(); i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(await gateway.notificationsAllowed(), isTrue);

      final board = await repo.createBoard('E2E');
      final list = await repo.createList(board, 'Todo');
      final card = await repo.createCard(list, 'Nudge e2e');
      final reminderId = await repo.addReminder(
        card,
        DateTime.now().add(const Duration(seconds: 4)),
        intervalMinutes: 30,
      );
      await scheduler.rescheduleAll();
      // ignore: avoid_print
      print('E2E: scheduled, waiting for Tunda press');

      Future<T> waitFor<T extends Object>(Future<T?> Function() probe, String what,
          {int seconds = 120}) async {
        final end = DateTime.now().add(Duration(seconds: seconds));
        while (DateTime.now().isBefore(end)) {
          final v = await probe();
          if (v != null) return v;
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        throw TestFailure('timed out waiting for $what');
      }

      // 1) User presses Tunda -> snoozedUntil is set ~10 min ahead.
      final snoozed = await waitFor<Reminder>(() async {
        final r = await (db.select(db.reminders)
              ..where((x) => x.id.equals(reminderId)))
            .getSingle();
        return r.snoozedUntil == null ? null : r;
      }, 'Tunda press');
      expect(
        snoozed.snoozedUntil!.difference(DateTime.now()).inMinutes,
        inInclusiveRange(8, 10),
      );
      // ignore: avoid_print
      print('E2E: Tunda OK');

      // 2) Bring the reminder forward again, wait for Selesai press.
      await repo.updateReminder(
        reminderId,
        remindAt: DateTime.now().add(const Duration(seconds: 4)),
      );
      await scheduler.rescheduleAll();
      // ignore: avoid_print
      print('E2E: waiting for Selesai press');

      final doneCard = await waitFor<TodoCard>(() async {
        final c = await (db.select(db.cards)..where((x) => x.id.equals(card)))
            .getSingle();
        return c.completedAt == null ? null : c;
      }, 'Selesai press');
      expect(doneCard.completedAt, isNotNull);
      final r = await (db.select(db.reminders)
            ..where((x) => x.id.equals(reminderId)))
          .getSingle();
      expect(r.state, 'done');
      expect(await gateway.pendingNags(), isEmpty,
          reason: 'no further nags after Selesai');
      // ignore: avoid_print
      print('E2E: Selesai OK');
      await db.close();
    });
  }, skip: !_e2e);
}
