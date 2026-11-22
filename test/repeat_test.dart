import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/core/util/repeat.dart';

void main() {
  final now = DateTime(2026, 11, 22, 10);

  test('daily: next day at the same time, skipping missed days', () {
    expect(
      nextOccurrence(DateTime(2026, 11, 22, 8), 'daily', now: now),
      DateTime(2026, 11, 23, 8),
    );
    // Missed for a week: lands on the first future occurrence, not next day.
    expect(
      nextOccurrence(DateTime(2026, 11, 15, 8), 'daily', now: now),
      DateTime(2026, 11, 23, 8),
    );
  });

  test('finishing early advances exactly one step', () {
    expect(
      nextOccurrence(DateTime(2026, 11, 25, 9), 'daily', now: now),
      DateTime(2026, 11, 26, 9),
    );
  });

  test('weekly keeps the weekday', () {
    final next = nextOccurrence(DateTime(2026, 11, 2, 7, 30), 'weekly', now: now);
    expect(next, DateTime(2026, 11, 23, 7, 30));
    expect(next.weekday, DateTime(2026, 11, 2).weekday);
  });

  test('monthly clamps to the last day and returns to the anchor day', () {
    expect(
      nextOccurrence(DateTime(2026, 1, 31, 9), 'monthly', now: DateTime(2026, 1, 31, 10)),
      DateTime(2026, 2, 28, 9),
    );
    // Starting 31 Jan, a long gap: March has 31 days again.
    expect(
      nextOccurrence(DateTime(2026, 1, 31, 9), 'monthly', now: DateTime(2026, 2, 28, 10)),
      DateTime(2026, 3, 31, 9),
    );
    expect(
      nextOccurrence(DateTime(2026, 11, 15, 9), 'monthly', now: now),
      DateTime(2026, 12, 15, 9),
    );
  });

  test('monthly crosses the year boundary', () {
    expect(
      nextOccurrence(DateTime(2026, 12, 10, 9), 'monthly', now: DateTime(2026, 12, 11)),
      DateTime(2027, 1, 10, 9),
    );
  });

  test('leap years', () {
    expect(
      nextOccurrence(DateTime(2028, 1, 31, 9), 'monthly', now: DateTime(2028, 1, 31, 10)),
      DateTime(2028, 2, 29, 9),
    );
  });

  test('labels and validation', () {
    expect(repeatLabel(null), 'Tidak berulang');
    expect(repeatLabel('weekly'), 'Mingguan');
    expect(() => stepOnce(now, 'yearly'), throwsArgumentError);
  });
}
