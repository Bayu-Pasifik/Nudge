import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/db/repository.dart';
import '../../core/util/format.dart';

final openCardsProvider = StreamProvider.autoDispose<List<OpenCard>>(
  (ref) => ref.watch(repositoryProvider).watchOpenCards(),
);

final activeRemindersProvider =
    StreamProvider.autoDispose<List<ActiveReminder>>(
  (ref) => ref.watch(repositoryProvider).watchActiveReminders(),
);

enum TodayGroup { overdue, nagging, today, pinned }

class TodayItem {
  const TodayItem({
    required this.open,
    required this.group,
    this.nextReminder,
  });
  final OpenCard open;
  final TodayGroup group;

  /// The reminder that put this card in its group, if any.
  final Reminder? nextReminder;

  TodoCard get card => open.card;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Pure grouping logic for the Today screen. First matching group wins:
/// overdue > nagging > today > pinned. Cards with none of these are omitted.
List<TodayItem> buildToday(
  List<OpenCard> cards,
  List<Reminder> reminders, {
  required DateTime now,
}) {
  final byCard = <String, List<Reminder>>{};
  for (final r in reminders) {
    (byCard[r.cardId] ??= []).add(r);
  }

  final out = <TodayItem>[];
  for (final o in cards) {
    final rs = byCard[o.card.id] ?? const <Reminder>[];
    final status = dueStatus(o.card.dueAt, completed: false, now: now);
    Reminder? pick(bool Function(Reminder) test) {
      for (final r in rs) {
        if (test(r)) return r;
      }
      return null;
    }

    final missed = pick((r) => r.state == 'missed');
    final nagging = pick((r) => r.state == 'nagging');
    final todayR = pick((r) => _sameDay(r.remindAt, now));

    if (status == DueStatus.overdue || missed != null) {
      out.add(TodayItem(open: o, group: TodayGroup.overdue, nextReminder: missed));
    } else if (nagging != null) {
      out.add(TodayItem(open: o, group: TodayGroup.nagging, nextReminder: nagging));
    } else if (status == DueStatus.today || todayR != null) {
      out.add(TodayItem(open: o, group: TodayGroup.today, nextReminder: todayR));
    } else if (o.card.pinned) {
      out.add(TodayItem(open: o, group: TodayGroup.pinned));
    }
  }

  DateTime key(TodayItem i) =>
      i.nextReminder?.remindAt ??
      i.card.dueAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
  out.sort((a, b) {
    final g = a.group.index.compareTo(b.group.index);
    return g != 0 ? g : key(a).compareTo(key(b));
  });
  return out;
}
