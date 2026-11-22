import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../util/position.dart';
import 'database.dart';

const _uuid = Uuid();

/// Local-first data access. UI reads streams from the local DB; every write
/// marks the row `dirty` so the sync layer can push it to Supabase later.
class Repository {
  Repository(this.db, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _now;

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
  Future<void> setCardCompleted(String id, bool completed) async {
    final now = _now();
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
