import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Columns shared by every synced table. `dirty` marks rows with local
/// changes not yet pushed to Supabase; `deletedAt` is a tombstone so deletes
/// can be synced.
mixin SyncColumns on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class Boards extends Table with SyncColumns {
  TextColumn get title => text()();
  IntColumn get color => integer().withDefault(const Constant(0xFF3B5BDB))();
  RealColumn get position => real().withDefault(const Constant(0))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();
}

@DataClassName('BoardList')
class Lists extends Table with SyncColumns {
  TextColumn get boardId => text()();
  TextColumn get title => text()();
  RealColumn get position => real().withDefault(const Constant(0))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

@DataClassName('TodoCard')
class Cards extends Table with SyncColumns {
  TextColumn get listId => text()();
  TextColumn get boardId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  RealColumn get position => real().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  TextColumn get stickyColor => text().withDefault(const Constant('yellow'))();
  BoolColumn get autoCompleteOnChecklist =>
      boolean().withDefault(const Constant(false))();
}

class ChecklistItems extends Table with SyncColumns {
  TextColumn get cardId => text()();
  TextColumn get text_ => text().named('text')();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get doneAt => dateTime().nullable()();
  RealColumn get position => real().withDefault(const Constant(0))();
}

class Labels extends Table with SyncColumns {
  TextColumn get boardId => text()();
  TextColumn get name => text()();
  IntColumn get color => integer()();
}

class CardLabels extends Table with SyncColumns {
  TextColumn get cardId => text()();
  TextColumn get labelId => text()();
}

class Reminders extends Table with SyncColumns {
  TextColumn get cardId => text()();
  DateTimeColumn get remindAt => dateTime()();

  /// Repeat rule: null, 'daily', 'weekly', 'monthly'.
  TextColumn get repeatRule => text().nullable()();
  BoolColumn get nagEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get nagIntervalMinutes =>
      integer().withDefault(const Constant(10))();

  /// Null = nag until done.
  IntColumn get nagMaxCount => integer().nullable()();

  /// JSON list: [{"after":3,"level":2},{"after":6,"level":3}]
  TextColumn get escalation => text().nullable()();

  /// Quiet hours as minutes from midnight, local time. Null = none.
  IntColumn get quietStartMinute => integer().nullable()();
  IntColumn get quietEndMinute => integer().nullable()();
  DateTimeColumn get snoozedUntil => dateTime().nullable()();
  IntColumn get nagCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastNagAt => dateTime().nullable()();

  /// scheduled | nagging | done | missed
  TextColumn get state => text().withDefault(const Constant('scheduled'))();
}

@DriftDatabase(
  tables: [Boards, Lists, Cards, ChecklistItems, Labels, CardLabels, Reminders],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'nudge'));

  @override
  int get schemaVersion => 1;
}

