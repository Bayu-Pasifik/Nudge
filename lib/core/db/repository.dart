import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../util/position.dart';
import '../util/repeat.dart';
import 'database.dart';

const _uuid = Uuid();

/// A pinned card with its checklist progress.
class StickyInfo {
  const StickyInfo({required this.open, required this.items});
  final OpenCard open;
  final List<ChecklistItem> items;

  int get total => items.length;
  int get done => items.where((i) => i.done).length;
}

/// An unfinished card plus where it lives.
class OpenCard {
  const OpenCard({
    required this.card,
    required this.listTitle,
    required this.boardTitle,
  });
  final TodoCard card;
  final String listTitle;
  final String boardTitle;
}

/// A reminder together with the card and where it lives, for notifications
/// and the Today screen.
class ActiveReminder {
  const ActiveReminder({
    required this.reminder,
    required this.card,
    required this.listTitle,
    required this.boardTitle,
  });
  final Reminder reminder;
  final TodoCard card;
  final String listTitle;
  final String boardTitle;
}

/// Local-first data access. UI reads streams from the local DB; every write
/// marks the row `dirty` so the sync layer can push it to Supabase later.
class Repository {
  Repository(this.db, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _now;

  /// Removes every row of every table (used when signing out, so the next
  /// account never sees this one's data).
  Future<void> clearAllData() async {
    await db.transaction(() async {
      for (final t in db.allTables) {
        await db.delete(t).go();
      }
    });
  }

  // ---------------------------------------------------------------- boards

  Stream<List<Board>> watchBoards() {
    final q = db.select(db.boards)
      ..where((b) => b.deletedAt.isNull() & b.archivedAt.isNull())
      ..orderBy([
        (b) => OrderingTerm.desc(b.lastOpenedAt),
        (b) => OrderingTerm.asc(b.position),
        (b) => OrderingTerm.asc(b.createdAt),
      ]);
    return q.watch();
  }

  Stream<Board?> watchBoard(String id) {
    final q = db.select(db.boards)..where((b) => b.id.equals(id));
    return q.watchSingleOrNull();
  }

  Future<String> createBoard(String title, {int? color}) async {
    final id = _uuid.v4();
    final now = _now();
    final last = await (db.select(db.boards)
          ..where((b) => b.deletedAt.isNull())
          ..orderBy([(b) => OrderingTerm.desc(b.position)])
          ..limit(1))
        .getSingleOrNull();
    await db.into(db.boards).insert(
          BoardsCompanion.insert(
            id: id,
            title: title.trim(),
            createdAt: now,
            updatedAt: now,
            color: color == null ? const Value.absent() : Value(color),
            position: Value(positionBetween(last?.position, null)),
          ),
        );
    return id;
  }

  Future<void> updateBoard(String id, {String? title, int? color}) {
    return (db.update(db.boards)..where((b) => b.id.equals(id))).write(
      BoardsCompanion(
        title: title == null ? const Value.absent() : Value(title.trim()),
        color: color == null ? const Value.absent() : Value(color),
        updatedAt: Value(_now()),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> touchBoard(String id) {
    return (db.update(db.boards)..where((b) => b.id.equals(id))).write(
      BoardsCompanion(lastOpenedAt: Value(_now())),
    );
  }

  Future<void> archiveBoard(String id) {
    final now = _now();
    return (db.update(db.boards)..where((b) => b.id.equals(id))).write(
      BoardsCompanion(
        archivedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  // ----------------------------------------------------------------- lists

  Stream<List<BoardList>> watchLists(String boardId) {
    final q = db.select(db.lists)
      ..where((l) =>
          l.boardId.equals(boardId) & l.deletedAt.isNull() & l.archivedAt.isNull())
      ..orderBy([(l) => OrderingTerm.asc(l.position)]);
    return q.watch();
  }

  Future<String> createList(String boardId, String title) async {
    final id = _uuid.v4();
    final now = _now();
    final last = await (db.select(db.lists)
          ..where((l) => l.boardId.equals(boardId) & l.deletedAt.isNull())
          ..orderBy([(l) => OrderingTerm.desc(l.position)])
          ..limit(1))
        .getSingleOrNull();
    await db.into(db.lists).insert(
          ListsCompanion.insert(
            id: id,
            boardId: boardId,
            title: title.trim(),
            createdAt: now,
            updatedAt: now,
            position: Value(positionBetween(last?.position, null)),
          ),
        );
    return id;
  }

  Future<void> renameList(String id, String title) {
    return (db.update(db.lists)..where((l) => l.id.equals(id))).write(
      ListsCompanion(
        title: Value(title.trim()),
        updatedAt: Value(_now()),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> archiveList(String id) {
    final now = _now();
    return (db.update(db.lists)..where((l) => l.id.equals(id))).write(
      ListsCompanion(
        archivedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  /// Moves a list so it ends up at [toIndex] among the board's visible lists.
  Future<void> moveList(String listId, int toIndex) async {
    await db.transaction(() async {
      final moving = await (db.select(db.lists)..where((l) => l.id.equals(listId)))
          .getSingle();
      var siblings = await _visibleLists(moving.boardId, exclude: listId);
      if (_needsSpacing(siblings.map((l) => l.position).toList(), toIndex)) {
        await _respaceLists(siblings);
        siblings = await _visibleLists(moving.boardId, exclude: listId);
      }
      final idx = toIndex.clamp(0, siblings.length);
      final pos = positionBetween(
        idx > 0 ? siblings[idx - 1].position : null,
        idx < siblings.length ? siblings[idx].position : null,
      );
      await (db.update(db.lists)..where((l) => l.id.equals(listId))).write(
        ListsCompanion(
          position: Value(pos),
          updatedAt: Value(_now()),
          dirty: const Value(true),
        ),
      );
    });
  }

  Future<List<BoardList>> _visibleLists(String boardId, {String? exclude}) {
    final q = db.select(db.lists)
      ..where((l) =>
          l.boardId.equals(boardId) &
          l.deletedAt.isNull() &
          l.archivedAt.isNull() &
          (exclude == null ? const Constant(true) : l.id.equals(exclude).not()))
      ..orderBy([(l) => OrderingTerm.asc(l.position)]);
    return q.get();
  }

  Future<void> _respaceLists(List<BoardList> lists) async {
    final fresh = rebalance(lists.length);
    for (var i = 0; i < lists.length; i++) {
      await (db.update(db.lists)..where((l) => l.id.equals(lists[i].id))).write(
        ListsCompanion(position: Value(fresh[i]), dirty: const Value(true)),
      );
    }
  }

  /// True when inserting at [index] between neighbours would run out of
  /// floating point precision.
  bool _needsSpacing(List<double> positions, int index) {
    final i = index.clamp(0, positions.length);
    if (i == 0 || i >= positions.length) return false;
    return needsRebalance(positions[i - 1], positions[i]);
  }

  // ------------------------------------------------------------------ cards

  Stream<List<TodoCard>> watchCards(String boardId) {
    final q = db.select(db.cards)
      ..where((c) =>
          c.boardId.equals(boardId) & c.deletedAt.isNull() & c.archivedAt.isNull())
      ..orderBy([(c) => OrderingTerm.asc(c.position)]);
    return q.watch();
  }

  Stream<TodoCard?> watchCard(String id) {
    final q = db.select(db.cards)..where((c) => c.id.equals(id));
    return q.watchSingleOrNull();
  }

  Future<String> createCard(String listId, String title) async {
    final list = await (db.select(db.lists)..where((l) => l.id.equals(listId)))
        .getSingle();
    final id = _uuid.v4();
    final now = _now();
    final last = await (db.select(db.cards)
          ..where((c) =>
              c.listId.equals(listId) & c.deletedAt.isNull() & c.archivedAt.isNull())
          ..orderBy([(c) => OrderingTerm.desc(c.position)])
          ..limit(1))
        .getSingleOrNull();
    await db.into(db.cards).insert(
          CardsCompanion.insert(
            id: id,
            listId: listId,
            boardId: list.boardId,
            title: title.trim(),
            createdAt: now,
            updatedAt: now,
            position: Value(positionBetween(last?.position, null)),
          ),
        );
    return id;
  }

  Future<void> updateCard(
    String id, {
    String? title,
    String? description,
    Value<DateTime?> dueAt = const Value.absent(),
    bool? pinned,
    String? stickyColor,
    bool? autoCompleteOnChecklist,
  }) {
    return (db.update(db.cards)..where((c) => c.id.equals(id))).write(
      CardsCompanion(
        title: title == null ? const Value.absent() : Value(title.trim()),
        description:
            description == null ? const Value.absent() : Value(description),
        dueAt: dueAt,
        pinned: pinned == null ? const Value.absent() : Value(pinned),
        stickyColor:
            stickyColor == null ? const Value.absent() : Value(stickyColor),
        autoCompleteOnChecklist: autoCompleteOnChecklist == null
            ? const Value.absent()
            : Value(autoCompleteOnChecklist),
        updatedAt: Value(_now()),
        dirty: const Value(true),
      ),
    );
  }

  /// Completing a card also settles its reminders so nagging stops.
  ///
  /// A card with a *repeating* reminder is never left completed: finishing it
  /// means "done for this cycle", so it reopens with its reminder and due date
  /// moved to the next occurrence and its checklist cleared.
  Future<void> setCardCompleted(String id, bool completed) async {
    final now = _now();
    if (completed && await _advanceRepeating(id, now)) return;
    await db.transaction(() async {
      await (db.update(db.cards)..where((c) => c.id.equals(id))).write(
        CardsCompanion(
          completedAt: Value(completed ? now : null),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
      await (db.update(db.reminders)..where((r) => r.cardId.equals(id))).write(
        RemindersCompanion(
          state: Value(completed ? 'done' : 'scheduled'),
          nagCount: completed ? const Value.absent() : const Value(0),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
    });
  }

  /// Moves a repeating card to its next cycle. Returns false if the card has
  /// no repeating reminder (the caller then completes it normally).
  Future<bool> _advanceRepeating(String cardId, DateTime now) async {
    final repeating = await (db.select(db.reminders)
          ..where((r) =>
              r.cardId.equals(cardId) &
              r.deletedAt.isNull() &
              r.repeatRule.isNotNull()))
        .get();
    if (repeating.isEmpty) return false;

    await db.transaction(() async {
      for (final r in repeating) {
        await (db.update(db.reminders)..where((x) => x.id.equals(r.id))).write(
          RemindersCompanion(
            remindAt: Value(nextOccurrence(r.remindAt, r.repeatRule!, now: now)),
            snoozedUntil: const Value(null),
            nagCount: const Value(0),
            lastNagAt: const Value(null),
            state: const Value('scheduled'),
            updatedAt: Value(now),
            dirty: const Value(true),
          ),
        );
      }
      final card =
          await (db.select(db.cards)..where((c) => c.id.equals(cardId))).getSingle();
      await (db.update(db.cards)..where((c) => c.id.equals(cardId))).write(
        CardsCompanion(
          dueAt: card.dueAt == null
              ? const Value.absent()
              : Value(nextOccurrence(card.dueAt!, repeating.first.repeatRule!, now: now)),
          completedAt: const Value(null),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
      // A new cycle starts with a clean checklist.
      await (db.update(db.checklistItems)
            ..where((i) => i.cardId.equals(cardId) & i.deletedAt.isNull()))
          .write(
        ChecklistItemsCompanion(
          done: const Value(false),
          doneAt: const Value(null),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
    });
    return true;
  }

  Future<void> archiveCard(String id) {
    final now = _now();
    return (db.update(db.cards)..where((c) => c.id.equals(id))).write(
      CardsCompanion(
        archivedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> deleteCard(String id) async {
    final now = _now();
    await db.transaction(() async {
      await (db.update(db.cards)..where((c) => c.id.equals(id))).write(
        CardsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
      await (db.update(db.reminders)..where((r) => r.cardId.equals(id))).write(
        RemindersCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
    });
  }

  /// Moves [cardId] into [toListId] at [toIndex] (index among that list's
  /// visible cards, ignoring the moving card itself).
  Future<void> moveCard(String cardId, String toListId, int toIndex) async {
    await db.transaction(() async {
      var siblings = await _visibleCards(toListId, exclude: cardId);
      if (_needsSpacing(siblings.map((c) => c.position).toList(), toIndex)) {
        final fresh = rebalance(siblings.length);
        for (var i = 0; i < siblings.length; i++) {
          await (db.update(db.cards)..where((c) => c.id.equals(siblings[i].id)))
              .write(CardsCompanion(
            position: Value(fresh[i]),
            dirty: const Value(true),
          ));
        }
        siblings = await _visibleCards(toListId, exclude: cardId);
      }
      final idx = toIndex.clamp(0, siblings.length);
      final pos = positionBetween(
        idx > 0 ? siblings[idx - 1].position : null,
        idx < siblings.length ? siblings[idx].position : null,
      );
      final list = await (db.select(db.lists)..where((l) => l.id.equals(toListId)))
          .getSingle();
      await (db.update(db.cards)..where((c) => c.id.equals(cardId))).write(
        CardsCompanion(
          listId: Value(toListId),
          boardId: Value(list.boardId),
          position: Value(pos),
          updatedAt: Value(_now()),
          dirty: const Value(true),
        ),
      );
    });
  }

  Future<List<TodoCard>> _visibleCards(String listId, {String? exclude}) {
    final q = db.select(db.cards)
      ..where((c) =>
          c.listId.equals(listId) &
          c.deletedAt.isNull() &
          c.archivedAt.isNull() &
          (exclude == null ? const Constant(true) : c.id.equals(exclude).not()))
      ..orderBy([(c) => OrderingTerm.asc(c.position)]);
    return q.get();
  }

  /// Every unfinished, live card across all boards (for the Today screen).
  Stream<List<OpenCard>> watchOpenCards() {
    final q = db.select(db.cards).join([
      innerJoin(db.lists, db.lists.id.equalsExp(db.cards.listId)),
      innerJoin(db.boards, db.boards.id.equalsExp(db.cards.boardId)),
    ])
      ..where(db.cards.deletedAt.isNull() &
          db.cards.archivedAt.isNull() &
          db.cards.completedAt.isNull() &
          db.boards.deletedAt.isNull() &
          db.boards.archivedAt.isNull() &
          db.lists.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(db.cards.dueAt)]);
    return q.watch().map(
          (rows) => [
            for (final r in rows)
              OpenCard(
                card: r.readTable(db.cards),
                listTitle: r.readTable(db.lists).title,
                boardTitle: r.readTable(db.boards).title,
              ),
          ],
        );
  }

  /// Pinned, unfinished cards with checklist progress (sticky notes).
  Future<List<StickyInfo>> pinnedStickies() async {
    final q = db.select(db.cards).join([
      innerJoin(db.lists, db.lists.id.equalsExp(db.cards.listId)),
      innerJoin(db.boards, db.boards.id.equalsExp(db.cards.boardId)),
    ])
      ..where(db.cards.pinned.equals(true) &
          db.cards.deletedAt.isNull() &
          db.cards.archivedAt.isNull() &
          db.cards.completedAt.isNull() &
          db.boards.deletedAt.isNull() &
          db.boards.archivedAt.isNull() &
          db.lists.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(db.cards.updatedAt)]);
    final rows = await q.get();
    final out = <StickyInfo>[];
    for (final r in rows) {
      final card = r.readTable(db.cards);
      final items = await (db.select(db.checklistItems)
            ..where((i) => i.cardId.equals(card.id) & i.deletedAt.isNull())
            ..orderBy([(i) => OrderingTerm.asc(i.position)]))
          .get();
      out.add(
        StickyInfo(
          open: OpenCard(
            card: card,
            listTitle: r.readTable(db.lists).title,
            boardTitle: r.readTable(db.boards).title,
          ),
          items: items,
        ),
      );
    }
    return out;
  }

  /// Live version of [pinnedStickies] for the desktop sticky window.
  Stream<List<StickyInfo>> watchPinnedStickies() async* {
    yield await pinnedStickies();
    yield* db
        .tableUpdates(
          TableUpdateQuery.onAllTables(
            [db.cards, db.checklistItems, db.lists, db.boards],
          ),
        )
        .asyncMap((_) => pinnedStickies());
  }

  // ----------------------------------------------------------------- labels

  Stream<List<Label>> watchLabels(String boardId) {
    final q = db.select(db.labels)
      ..where((l) => l.boardId.equals(boardId) & l.deletedAt.isNull())
      ..orderBy([(l) => OrderingTerm.asc(l.createdAt)]);
    return q.watch();
  }

  Stream<List<Label>> watchAllLabels() {
    final q = db.select(db.labels)..where((l) => l.deletedAt.isNull());
    return q.watch();
  }

  Future<String> createLabel(String boardId, String name, int color) async {
    final id = _uuid.v4();
    final now = _now();
    await db.into(db.labels).insert(
          LabelsCompanion.insert(
            id: id,
            boardId: boardId,
            name: name.trim(),
            color: color,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> updateLabel(String id, {String? name, int? color}) {
    return (db.update(db.labels)..where((l) => l.id.equals(id))).write(
      LabelsCompanion(
        name: name == null ? const Value.absent() : Value(name.trim()),
        color: color == null ? const Value.absent() : Value(color),
        updatedAt: Value(_now()),
        dirty: const Value(true),
      ),
    );
  }

  /// Deleting a label also detaches it from every card.
  Future<void> deleteLabel(String id) async {
    final now = _now();
    await db.transaction(() async {
      await (db.update(db.labels)..where((l) => l.id.equals(id))).write(
        LabelsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
      await (db.update(db.cardLabels)..where((c) => c.labelId.equals(id))).write(
        CardLabelsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
    });
  }

  /// Every live card <-> label link (for tiles and search).
  Stream<List<CardLabel>> watchAllCardLabels() {
    final q = db.select(db.cardLabels)..where((c) => c.deletedAt.isNull());
    return q.watch();
  }

  /// Attaches or detaches [labelId] on [cardId]. A previously removed link is
  /// revived instead of duplicated.
  Future<void> setCardLabel(String cardId, String labelId, bool on) async {
    final now = _now();
    await db.transaction(() async {
      final existing = await (db.select(db.cardLabels)
            ..where((c) => c.cardId.equals(cardId) & c.labelId.equals(labelId)))
          .getSingleOrNull();
      if (existing == null) {
        if (!on) return;
        await db.into(db.cardLabels).insert(
              CardLabelsCompanion.insert(
                id: _uuid.v4(),
                cardId: cardId,
                labelId: labelId,
                createdAt: now,
                updatedAt: now,
              ),
            );
        return;
      }
      await (db.update(db.cardLabels)..where((c) => c.id.equals(existing.id))).write(
        CardLabelsCompanion(
          deletedAt: Value(on ? null : now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
    });
  }

  /// Every live card (finished ones included) with where it lives; for search.
  Stream<List<OpenCard>> watchAllCards() {
    final q = db.select(db.cards).join([
      innerJoin(db.lists, db.lists.id.equalsExp(db.cards.listId)),
      innerJoin(db.boards, db.boards.id.equalsExp(db.cards.boardId)),
    ])
      ..where(db.cards.deletedAt.isNull() &
          db.cards.archivedAt.isNull() &
          db.boards.deletedAt.isNull() &
          db.boards.archivedAt.isNull() &
          db.lists.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(db.cards.updatedAt)]);
    return q.watch().map(
          (rows) => [
            for (final r in rows)
              OpenCard(
                card: r.readTable(db.cards),
                listTitle: r.readTable(db.lists).title,
                boardTitle: r.readTable(db.boards).title,
              ),
          ],
        );
  }

  // -------------------------------------------------------------- reminders

  Stream<List<Reminder>> watchReminders(String cardId) {
    final q = db.select(db.reminders)
      ..where((r) => r.cardId.equals(cardId) & r.deletedAt.isNull())
      ..orderBy([(r) => OrderingTerm.asc(r.remindAt)]);
    return q.watch();
  }

  Future<String> addReminder(
    String cardId,
    DateTime remindAt, {
    bool nagEnabled = true,
    int intervalMinutes = 10,
    int? maxCount,
    String? escalationJson,
    int? quietStartMinute,
    int? quietEndMinute,
    String? repeatRule,
  }) async {
    final id = _uuid.v4();
    final now = _now();
    await db.into(db.reminders).insert(
          RemindersCompanion.insert(
            id: id,
            cardId: cardId,
            remindAt: remindAt,
            createdAt: now,
            updatedAt: now,
            nagEnabled: Value(nagEnabled),
            nagIntervalMinutes: Value(intervalMinutes),
            nagMaxCount: Value(maxCount),
            escalation: Value(escalationJson),
            quietStartMinute: Value(quietStartMinute),
            quietEndMinute: Value(quietEndMinute),
            repeatRule: Value(repeatRule),
          ),
        );
    return id;
  }

  Future<void> updateReminder(
    String id, {
    DateTime? remindAt,
    bool? nagEnabled,
    int? intervalMinutes,
    Value<int?> maxCount = const Value.absent(),
    Value<String?> escalationJson = const Value.absent(),
    Value<int?> quietStartMinute = const Value.absent(),
    Value<int?> quietEndMinute = const Value.absent(),
    Value<String?> repeatRule = const Value.absent(),
  }) {
    return (db.update(db.reminders)..where((r) => r.id.equals(id))).write(
      RemindersCompanion(
        remindAt: remindAt == null ? const Value.absent() : Value(remindAt),
        nagEnabled: nagEnabled == null ? const Value.absent() : Value(nagEnabled),
        nagIntervalMinutes:
            intervalMinutes == null ? const Value.absent() : Value(intervalMinutes),
        nagMaxCount: maxCount,
        escalation: escalationJson,
        quietStartMinute: quietStartMinute,
        quietEndMinute: quietEndMinute,
        repeatRule: repeatRule,
        // Editing re-arms the reminder.
        snoozedUntil: const Value(null),
        state: const Value('scheduled'),
        updatedAt: Value(_now()),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> deleteReminder(String id) {
    final now = _now();
    return (db.update(db.reminders)..where((r) => r.id.equals(id))).write(
      RemindersCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  /// Restart the nag sequence from [until] (user pressed "Tunda").
  Future<void> snoozeCardReminders(String cardId, DateTime until) {
    return (db.update(db.reminders)
          ..where((r) =>
              r.cardId.equals(cardId) &
              r.deletedAt.isNull() &
              r.state.equals('done').not()))
        .write(
      RemindersCompanion(
        snoozedUntil: Value(until),
        state: const Value('scheduled'),
        updatedAt: Value(_now()),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> setReminderState(String id, String state) {
    return (db.update(db.reminders)..where((r) => r.id.equals(id))).write(
      RemindersCompanion(
        state: Value(state),
        updatedAt: Value(_now()),
        dirty: const Value(true),
      ),
    );
  }

  /// Reminders that still need attention: not done, on a live, unfinished card.
  Future<List<ActiveReminder>> activeReminders() => _activeRemindersQuery().get();

  Stream<List<ActiveReminder>> watchActiveReminders() =>
      _activeRemindersQuery().watch();

  Selectable<ActiveReminder> _activeRemindersQuery() {
    final q = db.select(db.reminders).join([
      innerJoin(db.cards, db.cards.id.equalsExp(db.reminders.cardId)),
      innerJoin(db.lists, db.lists.id.equalsExp(db.cards.listId)),
      innerJoin(db.boards, db.boards.id.equalsExp(db.cards.boardId)),
    ])
      ..where(db.reminders.deletedAt.isNull() &
          db.reminders.state.equals('done').not() &
          db.cards.deletedAt.isNull() &
          db.cards.archivedAt.isNull() &
          db.cards.completedAt.isNull())
      ..orderBy([OrderingTerm.asc(db.reminders.remindAt)]);
    return q.map(
      (row) => ActiveReminder(
        reminder: row.readTable(db.reminders),
        card: row.readTable(db.cards),
        listTitle: row.readTable(db.lists).title,
        boardTitle: row.readTable(db.boards).title,
      ),
    );
  }

  // -------------------------------------------------------------- checklist

  Stream<List<ChecklistItem>> watchChecklist(String cardId) {
    final q = db.select(db.checklistItems)
      ..where((i) => i.cardId.equals(cardId) & i.deletedAt.isNull())
      ..orderBy([(i) => OrderingTerm.asc(i.position)]);
    return q.watch();
  }

  /// All checklist items of a board, for progress badges on card tiles.
  Stream<List<ChecklistItem>> watchBoardChecklist(String boardId) {
    final q = db.select(db.checklistItems).join([
      innerJoin(db.cards, db.cards.id.equalsExp(db.checklistItems.cardId)),
    ])
      ..where(db.cards.boardId.equals(boardId) &
          db.checklistItems.deletedAt.isNull());
    return q.watch().map(
          (rows) => rows.map((r) => r.readTable(db.checklistItems)).toList(),
        );
  }

  Future<String> addChecklistItem(String cardId, String text) async {
    final id = _uuid.v4();
    final now = _now();
    final last = await (db.select(db.checklistItems)
          ..where((i) => i.cardId.equals(cardId) & i.deletedAt.isNull())
          ..orderBy([(i) => OrderingTerm.desc(i.position)])
          ..limit(1))
        .getSingleOrNull();
    await db.into(db.checklistItems).insert(
          ChecklistItemsCompanion.insert(
            id: id,
            cardId: cardId,
            text_: text.trim(),
            createdAt: now,
            updatedAt: now,
            position: Value(positionBetween(last?.position, null)),
          ),
        );
    return id;
  }

  Future<void> editChecklistItem(String id, String text) {
    return (db.update(db.checklistItems)..where((i) => i.id.equals(id))).write(
      ChecklistItemsCompanion(
        text_: Value(text.trim()),
        updatedAt: Value(_now()),
        dirty: const Value(true),
      ),
    );
  }

  /// Toggles an item. If the card has auto-complete on and every item is now
  /// done, the card is completed too.
  Future<void> setChecklistItemDone(String id, bool done) async {
    final now = _now();
    await db.transaction(() async {
      await (db.update(db.checklistItems)..where((i) => i.id.equals(id))).write(
        ChecklistItemsCompanion(
          done: Value(done),
          doneAt: Value(done ? now : null),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
      final item = await (db.select(db.checklistItems)
            ..where((i) => i.id.equals(id)))
          .getSingle();
      final card = await (db.select(db.cards)
            ..where((c) => c.id.equals(item.cardId)))
          .getSingle();
      if (!done || !card.autoCompleteOnChecklist || card.completedAt != null) {
        return;
      }
      final items = await (db.select(db.checklistItems)
            ..where((i) => i.cardId.equals(card.id) & i.deletedAt.isNull()))
          .get();
      if (items.isNotEmpty && items.every((i) => i.done)) {
        await setCardCompleted(card.id, true);
      }
    });
  }

  Future<void> deleteChecklistItem(String id) {
    final now = _now();
    return (db.update(db.checklistItems)..where((i) => i.id.equals(id))).write(
      ChecklistItemsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  /// Soft delete with cascade: board, its lists and its cards get tombstones.
  Future<void> deleteBoard(String id) async {
    final now = _now();
    await db.transaction(() async {
      await (db.update(db.boards)..where((t) => t.id.equals(id))).write(
        BoardsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
      await (db.update(db.lists)..where((t) => t.boardId.equals(id))).write(
        ListsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
      await (db.update(db.cards)..where((t) => t.boardId.equals(id))).write(
        CardsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
    });
  }
}
