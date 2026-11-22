/// Recurrence for repeating tasks: 'daily', 'weekly' or 'monthly'.
const repeatRules = ['daily', 'weekly', 'monthly'];

String repeatLabel(String? rule) => switch (rule) {
      'daily' => 'Harian',
      'weekly' => 'Mingguan',
      'monthly' => 'Bulanan',
      _ => 'Tidak berulang',
    };

DateTime _lastDayClamp(int year, int month, int day, int h, int m) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > last ? last : day, h, m);
}

/// One step forward from [from]. Monthly keeps the original day of month where
/// possible and clamps to the month's last day (31 Jan -> 28 Feb), using
/// [anchorDay] so a clamped date later returns to day 31.
DateTime stepOnce(DateTime from, String rule, {int? anchorDay}) {
  switch (rule) {
    case 'daily':
      return DateTime(from.year, from.month, from.day + 1, from.hour, from.minute);
    case 'weekly':
      return DateTime(from.year, from.month, from.day + 7, from.hour, from.minute);
    case 'monthly':
      return _lastDayClamp(
        from.year,
        from.month + 1,
        anchorDay ?? from.day,
        from.hour,
        from.minute,
      );
  }
  throw ArgumentError('unknown repeat rule: $rule');
}

/// The first occurrence strictly after [now], stepping from [from] by [rule].
/// If [from] is already after [now] it advances exactly one step (the task was
/// finished early, so the next cycle is the one after).
DateTime nextOccurrence(DateTime from, String rule, {required DateTime now}) {
  final anchor = from.day;
  var d = stepOnce(from, rule, anchorDay: anchor);
  var guard = 0;
  while (!d.isAfter(now) && guard++ < 5000) {
    d = stepOnce(d, rule, anchorDay: anchor);
  }
  return d;
}
