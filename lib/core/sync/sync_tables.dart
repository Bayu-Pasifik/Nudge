import 'package:drift/drift.dart';

import '../db/database.dart';
import 'remote.dart';

/// A local row waiting to be pushed.
class DirtyRow {
  const DirtyRow(this.id, this.updatedAt, this.row);
  final String id;

  /// Local `updated_at` at snapshot time; used to avoid marking a row clean if
  /// it was edited again while the push was in flight.
  final DateTime updatedAt;
  final Row row;
}

class LocalInfo {
  const LocalInfo(this.updatedAt, this.dirty);
  final DateTime updatedAt;
  final bool dirty;
}

/// One synced table: how to read dirty rows, mark them clean, look up a local
/// row's state, and apply a row coming from the server.
abstract class SyncTable {
  String get name;
  Future<List<DirtyRow>> dirty(AppDatabase db, String userId);

  /// Every local row (dirty or not), encoded like a push. Used for exports.
  Future<List<Row>> all(AppDatabase db, String userId);
  Future<void> markClean(AppDatabase db, String id, DateTime updatedAt);
  Future<LocalInfo?> local(AppDatabase db, String id);
  Future<void> applyRemote(AppDatabase db, Row row);
}

class _Table<T extends SyncColumns, D> implements SyncTable {
  _Table({
    required this.name,
    required this.table,
    required this.idOf,
    required this.updatedAtOf,
    required this.dirtyOf,
    required this.encode,
    required this.decode,
  });

  @override
  final String name;
  final TableInfo<T, D> Function(AppDatabase) table;
  final String Function(D) idOf;
  final DateTime Function(D) updatedAtOf;
  final bool Function(D) dirtyOf;
  final Row Function(D, String userId) encode;
  final Insertable<D> Function(Row) decode;

  @override
  Future<List<DirtyRow>> dirty(AppDatabase db, String userId) async {
    final t = table(db);
    final rows = await (db.select(t)..where((r) => (r as SyncColumns).dirty.equals(true))).get();
    return [for (final r in rows) DirtyRow(idOf(r), updatedAtOf(r), encode(r, userId))];
  }

  @override
  Future<List<Row>> all(AppDatabase db, String userId) async {
    final rows = await db.select(table(db)).get();
    return [for (final r in rows) encode(r, userId)];
  }

  @override
  Future<void> markClean(AppDatabase db, String id, DateTime updatedAt) async {
    final t = table(db);
    await (db.update(t)
          ..where((r) {
            final c = r as SyncColumns;
            return c.id.equals(id) & c.updatedAt.equals(updatedAt);
          }))
        .write(const _CleanFlag());
  }

  @override
  Future<LocalInfo?> local(AppDatabase db, String id) async {
    final t = table(db);
    final r = await (db.select(t)..where((x) => (x as SyncColumns).id.equals(id)))
        .getSingleOrNull();
    return r == null ? null : LocalInfo(updatedAtOf(r), dirtyOf(r));
  }

  @override
  Future<void> applyRemote(AppDatabase db, Row row) =>
      db.into(table(db)).insertOnConflictUpdate(decode(row));
}

/// Writes only `dirty = false`.
class _CleanFlag implements Insertable<Never> {
  const _CleanFlag();
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) =>
      {'dirty': const Constant(false)};
}

Row _base(String id, String userId, DateTime created, DateTime updated, DateTime? deleted) => {
      'id': id,
      'user_id': userId,
      'created_at': fmtTs(created),
      'updated_at': fmtTs(updated),
      'deleted_at': fmtTs(deleted),
    };

int _int(Object? v) => (v! as num).toInt();
double _dbl(Object? v) => (v! as num).toDouble();

/// Parents before children so foreign keys hold on the server.
final List<SyncTable> syncTables = [
  _Table<Boards, Board>(
    name: 'boards',
    table: (db) => db.boards,
    idOf: (d) => d.id,
    updatedAtOf: (d) => d.updatedAt,
    dirtyOf: (d) => d.dirty,
    encode: (d, u) => {
      ..._base(d.id, u, d.createdAt, d.updatedAt, d.deletedAt),
      'title': d.title,
      'color': d.color,
      'position': d.position,
      'archived_at': fmtTs(d.archivedAt),
      'last_opened_at': fmtTs(d.lastOpenedAt),
    },
    decode: (r) => BoardsCompanion(
      id: Value(r['id']! as String),
      title: Value(r['title']! as String),
      color: Value(_int(r['color'])),
      position: Value(_dbl(r['position'])),
      archivedAt: Value(parseTsOrNull(r['archived_at'])),
      lastOpenedAt: Value(parseTsOrNull(r['last_opened_at'])),
      createdAt: Value(parseTs(r['created_at'])),
      updatedAt: Value(parseTs(r['updated_at'])),
      deletedAt: Value(parseTsOrNull(r['deleted_at'])),
      dirty: const Value(false),
    ),
  ),
  _Table<Lists, BoardList>(
    name: 'lists',
    table: (db) => db.lists,
    idOf: (d) => d.id,
    updatedAtOf: (d) => d.updatedAt,
    dirtyOf: (d) => d.dirty,
    encode: (d, u) => {
      ..._base(d.id, u, d.createdAt, d.updatedAt, d.deletedAt),
      'board_id': d.boardId,
      'title': d.title,
      'position': d.position,
      'archived_at': fmtTs(d.archivedAt),
    },
    decode: (r) => ListsCompanion(
      id: Value(r['id']! as String),
      boardId: Value(r['board_id']! as String),
      title: Value(r['title']! as String),
      position: Value(_dbl(r['position'])),
      archivedAt: Value(parseTsOrNull(r['archived_at'])),
      createdAt: Value(parseTs(r['created_at'])),
      updatedAt: Value(parseTs(r['updated_at'])),
      deletedAt: Value(parseTsOrNull(r['deleted_at'])),
      dirty: const Value(false),
    ),
  ),
  _Table<Cards, TodoCard>(
    name: 'cards',
    table: (db) => db.cards,
    idOf: (d) => d.id,
    updatedAtOf: (d) => d.updatedAt,
    dirtyOf: (d) => d.dirty,
    encode: (d, u) => {
      ..._base(d.id, u, d.createdAt, d.updatedAt, d.deletedAt),
      'list_id': d.listId,
      'board_id': d.boardId,
      'title': d.title,
      'description': d.description,
      'due_at': fmtTs(d.dueAt),
      'position': d.position,
      'completed_at': fmtTs(d.completedAt),
      'archived_at': fmtTs(d.archivedAt),
      'pinned': d.pinned,
      'sticky_color': d.stickyColor,
      'auto_complete_on_checklist': d.autoCompleteOnChecklist,
    },
    decode: (r) => CardsCompanion(
      id: Value(r['id']! as String),
      listId: Value(r['list_id']! as String),
      boardId: Value(r['board_id']! as String),
      title: Value(r['title']! as String),
      description: Value((r['description'] as String?) ?? ''),
      dueAt: Value(parseTsOrNull(r['due_at'])),
      position: Value(_dbl(r['position'])),
      completedAt: Value(parseTsOrNull(r['completed_at'])),
      archivedAt: Value(parseTsOrNull(r['archived_at'])),
      pinned: Value((r['pinned'] as bool?) ?? false),
      stickyColor: Value((r['sticky_color'] as String?) ?? 'yellow'),
      autoCompleteOnChecklist:
          Value((r['auto_complete_on_checklist'] as bool?) ?? false),
      createdAt: Value(parseTs(r['created_at'])),
      updatedAt: Value(parseTs(r['updated_at'])),
      deletedAt: Value(parseTsOrNull(r['deleted_at'])),
      dirty: const Value(false),
    ),
  ),
  _Table<Labels, Label>(
    name: 'labels',
    table: (db) => db.labels,
    idOf: (d) => d.id,
    updatedAtOf: (d) => d.updatedAt,
    dirtyOf: (d) => d.dirty,
    encode: (d, u) => {
      ..._base(d.id, u, d.createdAt, d.updatedAt, d.deletedAt),
      'board_id': d.boardId,
      'name': d.name,
      'color': d.color,
    },
    decode: (r) => LabelsCompanion(
      id: Value(r['id']! as String),
      boardId: Value(r['board_id']! as String),
      name: Value(r['name']! as String),
      color: Value(_int(r['color'])),
      createdAt: Value(parseTs(r['created_at'])),
      updatedAt: Value(parseTs(r['updated_at'])),
      deletedAt: Value(parseTsOrNull(r['deleted_at'])),
      dirty: const Value(false),
    ),
  ),
  _Table<CardLabels, CardLabel>(
    name: 'card_labels',
    table: (db) => db.cardLabels,
    idOf: (d) => d.id,
    updatedAtOf: (d) => d.updatedAt,
    dirtyOf: (d) => d.dirty,
    encode: (d, u) => {
      ..._base(d.id, u, d.createdAt, d.updatedAt, d.deletedAt),
      'card_id': d.cardId,
      'label_id': d.labelId,
    },
    decode: (r) => CardLabelsCompanion(
      id: Value(r['id']! as String),
      cardId: Value(r['card_id']! as String),
      labelId: Value(r['label_id']! as String),
      createdAt: Value(parseTs(r['created_at'])),
      updatedAt: Value(parseTs(r['updated_at'])),
      deletedAt: Value(parseTsOrNull(r['deleted_at'])),
      dirty: const Value(false),
    ),
  ),
  _Table<ChecklistItems, ChecklistItem>(
    name: 'checklist_items',
    table: (db) => db.checklistItems,
    idOf: (d) => d.id,
    updatedAtOf: (d) => d.updatedAt,
    dirtyOf: (d) => d.dirty,
    encode: (d, u) => {
      ..._base(d.id, u, d.createdAt, d.updatedAt, d.deletedAt),
      'card_id': d.cardId,
      'text': d.text_,
      'done': d.done,
      'done_at': fmtTs(d.doneAt),
      'position': d.position,
    },
    decode: (r) => ChecklistItemsCompanion(
      id: Value(r['id']! as String),
      cardId: Value(r['card_id']! as String),
      text_: Value(r['text']! as String),
      done: Value((r['done'] as bool?) ?? false),
      doneAt: Value(parseTsOrNull(r['done_at'])),
      position: Value(_dbl(r['position'])),
      createdAt: Value(parseTs(r['created_at'])),
      updatedAt: Value(parseTs(r['updated_at'])),
      deletedAt: Value(parseTsOrNull(r['deleted_at'])),
      dirty: const Value(false),
    ),
  ),
  _Table<Reminders, Reminder>(
    name: 'reminders',
    table: (db) => db.reminders,
    idOf: (d) => d.id,
    updatedAtOf: (d) => d.updatedAt,
    dirtyOf: (d) => d.dirty,
    encode: (d, u) => {
      ..._base(d.id, u, d.createdAt, d.updatedAt, d.deletedAt),
      'card_id': d.cardId,
      'remind_at': fmtTs(d.remindAt),
      'repeat_rule': d.repeatRule,
      'nag_enabled': d.nagEnabled,
      'nag_interval_minutes': d.nagIntervalMinutes,
      'nag_max_count': d.nagMaxCount,
      'escalation': d.escalation,
      'quiet_start_minute': d.quietStartMinute,
      'quiet_end_minute': d.quietEndMinute,
      'snoozed_until': fmtTs(d.snoozedUntil),
      'nag_count': d.nagCount,
      'last_nag_at': fmtTs(d.lastNagAt),
      'state': d.state,
    },
    decode: (r) => RemindersCompanion(
      id: Value(r['id']! as String),
      cardId: Value(r['card_id']! as String),
      remindAt: Value(parseTs(r['remind_at'])),
      repeatRule: Value(r['repeat_rule'] as String?),
      nagEnabled: Value((r['nag_enabled'] as bool?) ?? true),
      nagIntervalMinutes: Value(_int(r['nag_interval_minutes'] ?? 10)),
      nagMaxCount: Value(r['nag_max_count'] == null ? null : _int(r['nag_max_count'])),
      escalation: Value(r['escalation'] as String?),
      quietStartMinute: Value(
          r['quiet_start_minute'] == null ? null : _int(r['quiet_start_minute'])),
      quietEndMinute:
          Value(r['quiet_end_minute'] == null ? null : _int(r['quiet_end_minute'])),
      snoozedUntil: Value(parseTsOrNull(r['snoozed_until'])),
      nagCount: Value(_int(r['nag_count'] ?? 0)),
      lastNagAt: Value(parseTsOrNull(r['last_nag_at'])),
      state: Value((r['state'] as String?) ?? 'scheduled'),
      createdAt: Value(parseTs(r['created_at'])),
      updatedAt: Value(parseTs(r['updated_at'])),
      deletedAt: Value(parseTsOrNull(r['deleted_at'])),
      dirty: const Value(false),
    ),
  ),
];
