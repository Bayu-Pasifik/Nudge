const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Relative due-date label: "Hari ini 14:00", "Besok 09:00", "Kemarin",
/// "Sen, 24 Nov".
String formatDue(DateTime due, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final diff = _dateOnly(due).difference(today).inDays;
  final hasTime = due.hour != 0 || due.minute != 0;
  final time = hasTime ? ' ${_hm(due)}' : '';
  if (diff == 0) return 'Hari ini$time';
  if (diff == 1) return 'Besok$time';
  if (diff == -1) return 'Kemarin$time';
  final base =
      '${_days[due.weekday - 1]}, ${due.day} ${_months[due.month - 1]}';
  final sameYear = due.year == today.year;
  return '${sameYear ? base : '$base ${due.year}'}$time';
}

enum DueStatus { none, later, today, overdue, done }

DueStatus dueStatus(DateTime? due, {required bool completed, DateTime? now}) {
  if (completed) return DueStatus.done;
  if (due == null) return DueStatus.none;
  final n = now ?? DateTime.now();
  final hasTime = due.hour != 0 || due.minute != 0;
  if (hasTime ? due.isBefore(n) : _dateOnly(due).isBefore(_dateOnly(n))) {
    return DueStatus.overdue;
  }
  if (_dateOnly(due) == _dateOnly(n)) return DueStatus.today;
  return DueStatus.later;
}
