import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/core/util/format.dart';

void main() {
  final now = DateTime(2026, 11, 22, 10, 0); // Sunday

  test('formatDue relative labels', () {
    expect(formatDue(DateTime(2026, 11, 22, 14, 0), now: now), 'Hari ini 14:00');
    expect(formatDue(DateTime(2026, 11, 23), now: now), 'Besok');
    expect(formatDue(DateTime(2026, 11, 21, 9, 5), now: now), 'Kemarin 09:05');
    expect(formatDue(DateTime(2026, 11, 25), now: now), 'Rab, 25 Nov');
    expect(formatDue(DateTime(2027, 1, 4), now: now), 'Sen, 4 Jan 2027');
  });

  test('dueStatus', () {
    expect(dueStatus(null, completed: false, now: now), DueStatus.none);
    expect(dueStatus(DateTime(2026, 11, 20), completed: true, now: now),
        DueStatus.done);
    expect(dueStatus(DateTime(2026, 11, 21, 8), completed: false, now: now),
        DueStatus.overdue);
    expect(dueStatus(DateTime(2026, 11, 22, 9), completed: false, now: now),
        DueStatus.overdue);
    expect(dueStatus(DateTime(2026, 11, 22, 18), completed: false, now: now),
        DueStatus.today);
    expect(dueStatus(DateTime(2026, 11, 22), completed: false, now: now),
        DueStatus.today);
    expect(dueStatus(DateTime(2026, 12, 1), completed: false, now: now),
        DueStatus.later);
  });
}
