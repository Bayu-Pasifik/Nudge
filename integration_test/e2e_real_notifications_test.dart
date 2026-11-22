import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nudge/core/nag/local_notifications_gateway.dart';
import 'package:nudge/core/nag/notification_gateway.dart';

/// Uses the REAL Android notification plugin. Requires the notification
/// permission to be granted beforehand:
///   adb shell pm grant com.bayu.nudge android.permission.POST_NOTIFICATIONS
/// Only runs with --dart-define=NUDGE_E2E=true (needs a real device and, for
/// button presses, tool/drive_notification_actions.ps1).
const _e2e = bool.fromEnvironment('NUDGE_E2E');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scheduled nag is actually delivered by Android', (tester) async {
    final gateway = LocalNotificationsGateway();
    await tester.runAsync(() async {
      await gateway.init();
      expect(await gateway.notificationsAllowed(), isTrue,
          reason: 'grant POST_NOTIFICATIONS with adb first');

      final now = DateTime.now();
      NagNotification n(int i, int level) => NagNotification(
            id: notificationId('real-test-reminder', i),
            reminderId: 'real-test-reminder',
            cardId: 'card-1',
            title: 'Nudge uji #$i',
            body: 'Rumah › Todo',
            at: now.add(Duration(seconds: 4 + i * 3)),
            level: level,
            index: i,
          );

      await gateway.replaceAllNags([n(0, 1), n(1, 2), n(2, 3)]);
      var pending = await gateway.pendingNags();
      expect(pending.length, 3, reason: 'all three queued with AlarmManager');

      // First fires after ~4s.
      await Future<void>.delayed(const Duration(seconds: 8));
      var active = await gateway.activeTitles();
      expect(active, contains('Nudge uji #0'),
          reason: 'first nag should be showing in the shade');

      // Cancelling removes the not-yet-fired ones.
      await gateway.cancelAllNags();
      pending = await gateway.pendingNags();
      expect(pending, isEmpty);

      await Future<void>.delayed(const Duration(seconds: 8));
      active = await gateway.activeTitles();
      expect(active, isNot(contains('Nudge uji #2')),
          reason: 'cancelled nags must never fire');
    });
  }, skip: !_e2e);
}
