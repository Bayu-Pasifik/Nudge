import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/db/repository.dart';
import 'package:nudge/features/today/today_data.dart';

void main() {
  final now = DateTime(2026, 11, 22, 10, 0);
  final stamp = DateTime(2026, 1, 1);

  OpenCard card(
    String id, {
    DateTime? due,
    bool pinned = false,
  }) =>
      OpenCard(
        card: TodoCard(
          id: id,
          createdAt: stamp,
          updatedAt: stamp,
          dirty: false,
          listId: 'l',
          boardId: 'b',
          title: id,
          description: '',
          dueAt: due,
          position: 0,
          pinned: pinned,
          stickyColor: 'yellow',
          autoCompleteOnChecklist: false,
        ),
        listTitle: 'Todo',
        boardTitle: 'Rumah',
      );

  Reminder reminder(String cardId, DateTime at, {String state = 'scheduled'}) =>
      Reminder(
        id: 'r-$cardId',
        createdAt: stamp,
        updatedAt: stamp,
        dirty: false,
        cardId: cardId,
        remindAt: at,
        nagEnabled: true,
        nagIntervalMinutes: 10,
        nagCount: 0,
        state: state,
      );

  Map<String, TodayGroup> groups(List<TodayItem> items) =>
      {for (final i in items) i.card.id: i.group};

  test('groups by urgency and drops unrelated cards', () {
    final items = buildToday(
      [
        card('overdue', due: DateTime(2026, 11, 20)),
        card('missed'),
        card('nagging'),
        card('dueToday', due: DateTime(2026, 11, 22, 18)),
        card('remindToday'),
        card('pinned', pinned: true),
        card('later', due: DateTime(2026, 12, 5)),
        card('plain'),
      ],
      [
        reminder('missed', DateTime(2026, 11, 21, 9), state: 'missed'),
        reminder('nagging', DateTime(2026, 11, 22, 9), state: 'nagging'),
        reminder('remindToday', DateTime(2026, 11, 22, 20)),
      ],
      now: now,
    );
    expect(groups(items), {
      'overdue': TodayGroup.overdue,
      'missed': TodayGroup.overdue,
      'nagging': TodayGroup.nagging,
      'dueToday': TodayGroup.today,
      'remindToday': TodayGroup.today,
      'pinned': TodayGroup.pinned,
    });
  });

  test('a pinned overdue card shows once, as overdue', () {
    final items = buildToday(
      [card('x', due: DateTime(2026, 11, 1), pinned: true)],
      [],
      now: now,
    );
    expect(items.length, 1);
    expect(items.single.group, TodayGroup.overdue);
  });

  test('ordered by group, then by time', () {
    final items = buildToday(
      [
        card('b', due: DateTime(2026, 11, 22, 20)),
        card('a', due: DateTime(2026, 11, 22, 18)),
        card('late', due: DateTime(2026, 11, 21)),
      ],
      [],
      now: now,
    );
    expect(items.map((i) => i.card.id), ['late', 'a', 'b']);
  });
}
