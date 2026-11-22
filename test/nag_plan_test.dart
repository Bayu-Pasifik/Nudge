import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/core/nag/nag_plan.dart';

void main() {
  final t0 = DateTime(2026, 11, 22, 10, 0);

  List<DateTime> times(List<NagEvent> e) => e.map((x) => x.at).toList();

  group('basic sequence', () {
    test('first event at remindAt, then every interval', () {
      final c = NagConfig(remindAt: t0, intervalMinutes: 10);
      final e = NagPlan.upcoming(c, now: t0.subtract(const Duration(minutes: 5)), limit: 3);
      expect(times(e), [
        t0,
        t0.add(const Duration(minutes: 10)),
        t0.add(const Duration(minutes: 20)),
      ]);
      expect(e.map((x) => x.index), [0, 1, 2]);
    });

    test('mid-sequence returns only future events with correct indexes', () {
      final c = NagConfig(remindAt: t0, intervalMinutes: 10);
      final now = t0.add(const Duration(minutes: 25)); // between #2 and #3
      final e = NagPlan.upcoming(c, now: now, limit: 2);
      expect(times(e), [
        t0.add(const Duration(minutes: 30)),
        t0.add(const Duration(minutes: 40)),
      ]);
      expect(e.first.index, 3);
    });

    test('event exactly at now is not upcoming', () {
      final c = NagConfig(remindAt: t0, intervalMinutes: 10);
      final e = NagPlan.upcoming(c, now: t0, limit: 1);
      expect(e.first.at, t0.add(const Duration(minutes: 10)));
    });

    test('nag disabled gives a single event', () {
      final c = NagConfig(remindAt: t0, nagEnabled: false);
      expect(NagPlan.upcoming(c, now: t0.subtract(const Duration(hours: 1))).length, 1);
      expect(NagPlan.upcoming(c, now: t0.add(const Duration(minutes: 1))), isEmpty);
    });

    test('maxCount caps the total including the first', () {
      final c = NagConfig(remindAt: t0, intervalMinutes: 5, maxCount: 3);
      final e = NagPlan.upcoming(c, now: t0.subtract(const Duration(minutes: 1)));
      expect(e.length, 3);
      final later = NagPlan.upcoming(c, now: t0.add(const Duration(minutes: 6)));
      expect(later.length, 1); // only #2 left
      expect(later.single.index, 2);
    });

    test('limit bounds an unbounded sequence', () {
      final c = NagConfig(remindAt: t0, intervalMinutes: 1);
      expect(NagPlan.upcoming(c, now: t0, limit: 7).length, 7);
    });
  });

  group('escalation', () {
    final c = NagConfig(
      remindAt: t0,
      intervalMinutes: 10,
      escalation: const [EscalationStep(3, 2), EscalationStep(6, 3)],
    );

    test('levels step up after N ignored nags', () {
      final e = NagPlan.upcoming(c, now: t0.subtract(const Duration(minutes: 1)), limit: 8);
      expect(e.map((x) => x.level), [1, 1, 1, 2, 2, 2, 3, 3]);
    });

    test('json round trip', () {
      final json = encodeEscalation(defaultEscalation);
      final back = parseEscalation(json);
      expect(back.length, 2);
      expect(back[1].level, 3);
      expect(parseEscalation(null), isEmpty);
      expect(parseEscalation('garbage'), isEmpty);
    });
  });

  group('quiet hours', () {
    test('repeats inside a same-day window are skipped', () {
      // Quiet 10:15-10:45; events 10:00, 10:10, 10:20, 10:30, 10:40, 10:50.
      final c = NagConfig(
        remindAt: t0,
        intervalMinutes: 10,
        quietStartMinute: 10 * 60 + 15,
        quietEndMinute: 10 * 60 + 45,
      );
      final e = NagPlan.upcoming(c, now: t0.subtract(const Duration(minutes: 1)), limit: 6);
      expect(times(e), [
        t0,
        t0.add(const Duration(minutes: 10)),
        t0.add(const Duration(minutes: 50)),
        t0.add(const Duration(minutes: 60)),
        t0.add(const Duration(minutes: 70)),
        t0.add(const Duration(minutes: 80)),
      ]);
      // Indexes keep counting through suppressed slots.
      expect(e[2].index, 5);
    });

    test('window across midnight (22:00-07:00)', () {
      final c = NagConfig(
        remindAt: DateTime(2026, 11, 22, 21, 0),
        intervalMinutes: 60,
        quietStartMinute: 22 * 60,
        quietEndMinute: 7 * 60,
      );
      final e = NagPlan.upcoming(c,
          now: DateTime(2026, 11, 22, 20, 0), limit: 4);
      expect(times(e), [
        DateTime(2026, 11, 22, 21, 0), // first event
        DateTime(2026, 11, 23, 7, 0), // 22:00..06:00 suppressed
        DateTime(2026, 11, 23, 8, 0),
        DateTime(2026, 11, 23, 9, 0),
      ]);
    });

    test('first notification fires even inside quiet hours', () {
      final c = NagConfig(
        remindAt: DateTime(2026, 11, 22, 23, 30),
        intervalMinutes: 30,
        quietStartMinute: 22 * 60,
        quietEndMinute: 7 * 60,
      );
      final e = NagPlan.upcoming(c,
          now: DateTime(2026, 11, 22, 20, 0), limit: 2);
      expect(e.first.at, DateTime(2026, 11, 22, 23, 30));
      expect(e.last.at, DateTime(2026, 11, 23, 7, 0));
    });

    test('start == end means no quiet hours', () {
      final c = NagConfig(
        remindAt: t0,
        intervalMinutes: 10,
        quietStartMinute: 600,
        quietEndMinute: 600,
      );
      expect(NagPlan.upcoming(c, now: t0, limit: 2).length, 2);
    });
  });

  group('snooze', () {
    test('sequence restarts from snoozedUntil', () {
      final snooze = t0.add(const Duration(hours: 1));
      final c = NagConfig(
        remindAt: t0,
        intervalMinutes: 10,
        snoozedUntil: snooze,
        escalation: const [EscalationStep(2, 2)],
      );
      final e = NagPlan.upcoming(c, now: t0.add(const Duration(minutes: 30)), limit: 3);
      expect(times(e), [
        snooze,
        snooze.add(const Duration(minutes: 10)),
        snooze.add(const Duration(minutes: 20)),
      ]);
      expect(e.map((x) => x.level), [1, 1, 2]);
    });
  });

  group('state', () {
    test('scheduled -> nagging -> missed', () {
      final c = NagConfig(remindAt: t0, intervalMinutes: 10, maxCount: 3);
      expect(NagPlan.stateAt(c, now: t0.subtract(const Duration(minutes: 1))), 'scheduled');
      expect(NagPlan.stateAt(c, now: t0), 'nagging');
      expect(NagPlan.stateAt(c, now: t0.add(const Duration(minutes: 19))), 'nagging');
      expect(NagPlan.stateAt(c, now: t0.add(const Duration(minutes: 20))), 'missed');
    });

    test('unbounded nag never becomes missed', () {
      final c = NagConfig(remindAt: t0, intervalMinutes: 10);
      expect(NagPlan.stateAt(c, now: t0.add(const Duration(days: 30))), 'nagging');
    });

    test('single-shot reminder is missed once it has fired', () {
      final c = NagConfig(remindAt: t0, nagEnabled: false);
      expect(NagPlan.stateAt(c, now: t0.add(const Duration(minutes: 1))), 'missed');
    });
  });
}
