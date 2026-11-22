import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/db/repository.dart';
import 'package:nudge/core/nag/local_notifications_gateway.dart';
import 'package:nudge/core/nag/nag_actions.dart';
import 'package:nudge/core/nag/nag_scheduler.dart';
import 'package:nudge/core/nag/notification_gateway.dart';
import 'package:nudge/main.dart' show nudgeNotificationBackground;

/// Real Android: a pinned card becomes a persistent notification; pressing
/// "Selesai" on it completes the card and removes the notification.
/// Driver: tool/drive_notification_actions.ps1 -Steps Selesai
/// Only runs with --dart-define=NUDGE_E2E=true (needs a real device and, for
/// button presses, tool/drive_notification_actions.ps1).
const _e2e = bool.fromEnvironment('NUDGE_E2E');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real sticky notification: ongoing, Selesai completes the card',
      (tester) async {
    await tester.runAsync(() async {
      final gateway = LocalNotificationsGateway();
      final db = AppDatabase();
      final repo = Repository(db);
      final scheduler = NagScheduler(repo, gateway);

      await gateway.init(
        onResponse: (NotificationResponse r) async {
          final action = nagActionFrom(r);
          final payload = NagPayload.parse(r.payload);
          if (action == null || payload == null || action == NagAction.open) return;
          await handleNagAction(repo, scheduler, action, payload);
        },
        onBackgroundResponse: nudgeNotificationBackground,
      );
      for (var i = 0; i < 120 && !await gateway.notificationsAllowed(); i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(await gateway.notificationsAllowed(), isTrue);

      final board = await repo.createBoard('Sticky');
      final list = await repo.createList(board, 'Todo');
      final cardId = await repo.createCard(list, 'Nudge sticky');
      await repo.addChecklistItem(cardId, 'Satu');
      await repo.updateCard(cardId, pinned: true, stickyColor: 'mint');
      await scheduler.rescheduleAll();

      expect(await gateway.activeTitles(), contains('Nudge sticky'));
      // ignore: avoid_print
      print('E2E: sticky shown, waiting for Selesai press');

      final end = DateTime.now().add(const Duration(seconds: 120));
      TodoCard? done;
      while (DateTime.now().isBefore(end)) {
        final c = await (db.select(db.cards)..where((x) => x.id.equals(cardId)))
            .getSingle();
        if (c.completedAt != null) {
          done = c;
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(done, isNotNull, reason: 'Selesai press never arrived');
      expect(await gateway.activeTitles(), isNot(contains('Nudge sticky')),
          reason: 'sticky note disappears once the card is done');
      // ignore: avoid_print
      print('E2E: sticky Selesai OK');
      await db.close();
    });
  }, skip: !_e2e);
}
