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
