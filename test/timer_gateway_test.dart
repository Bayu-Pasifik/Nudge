import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/core/nag/desktop_gateway.dart';
import 'package:nudge/core/nag/notification_gateway.dart';

NagNotification nag(DateTime at, int index, {int level = 1}) => NagNotification(
      id: index,
      reminderId: 'r',
      cardId: 'c',
      title: 'Judul',
      body: 'Isi',
      at: at,
      level: level,
      index: index,
    );

void main() {
  final t0 = DateTime(2026, 11, 22, 10);

  test('fires each notification at its time, in order', () {
    fakeAsync((async) {
      var now = t0;
      async.elapse(Duration.zero);
      final shown = <int>[];
      final g = TimerNotificationGateway(
        show: (n) async => shown.add(n.index),
        clock: () => t0.add(async.elapsed),
      );
      g.replaceAllNags([
        nag(t0.add(const Duration(minutes: 20)), 2),
        nag(t0.add(const Duration(minutes: 10)), 1),
        nag(t0.add(const Duration(minutes: 30)), 3),
      ]);

      async.elapse(const Duration(minutes: 9));
      expect(shown, isEmpty);
      async.elapse(const Duration(minutes: 1, seconds: 1));
      expect(shown, [1]);
      async.elapse(const Duration(minutes: 10));
      expect(shown, [1, 2]);
      async.elapse(const Duration(hours: 1));
      expect(shown, [1, 2, 3]);
      g.dispose();
      expect(now, t0);
    });
  });

  test('replacing the schedule drops what was queued', () {
    fakeAsync((async) {
      final shown = <int>[];
      final g = TimerNotificationGateway(
        show: (n) async => shown.add(n.index),
        clock: () => t0.add(async.elapsed),
      );
      g.replaceAllNags([nag(t0.add(const Duration(minutes: 5)), 1)]);
      g.replaceAllNags([nag(t0.add(const Duration(minutes: 8)), 2)]);
      async.elapse(const Duration(minutes: 6));
      expect(shown, isEmpty, reason: 'the 5-minute one was replaced');
      async.elapse(const Duration(minutes: 3));
      expect(shown, [2]);
      g.dispose();
    });
  });

  test('cancelAllNags stops everything', () {
    fakeAsync((async) {
      final shown = <int>[];
      final g = TimerNotificationGateway(
        show: (n) async => shown.add(n.index),
        clock: () => t0.add(async.elapsed),
      );
      g.replaceAllNags([nag(t0.add(const Duration(minutes: 1)), 1)]);
      g.cancelAllNags();
      async.elapse(const Duration(hours: 1));
      expect(shown, isEmpty);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('level 3 raises the escalation hook', () {
    fakeAsync((async) {
      final escalated = <int>[];
      final g = TimerNotificationGateway(
        show: (n) async {},
        onEscalate: (n) => escalated.add(n.index),
        clock: () => t0.add(async.elapsed),
      );
      g.replaceAllNags([
        nag(t0.add(const Duration(minutes: 1)), 1, level: 2),
        nag(t0.add(const Duration(minutes: 2)), 2, level: 3),
      ]);
      async.elapse(const Duration(minutes: 3));
      expect(escalated, [2]);
      g.dispose();
    });
  });

  test('an already-due notification fires immediately', () {
    fakeAsync((async) {
      final shown = <int>[];
      final g = TimerNotificationGateway(
        show: (n) async => shown.add(n.index),
        clock: () => t0.add(async.elapsed),
      );
      g.replaceAllNags([nag(t0.subtract(const Duration(seconds: 5)), 1)]);
      async.flushTimers();
      expect(shown, [1]);
      g.dispose();
    });
  });
}
