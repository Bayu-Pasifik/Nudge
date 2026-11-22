import 'dart:async';

import 'remote.dart';

/// In-memory server used by tests. Mimics the real server's behaviour:
/// stale writes (older `updated_at`) are ignored and `server_updated_at` is
/// stamped by a monotonically increasing clock.
class FakeRemote implements RemoteApi {
  FakeRemote({this.userId = 'user-1', DateTime? start})
      : _clock = start ?? DateTime.utc(2026, 11, 22);

  @override
  final String userId;

  /// table -> id -> row
  final Map<String, Map<String, Row>> tables = {};
  final _changes = StreamController<void>.broadcast();
  DateTime _clock;

  /// When true every call throws, to simulate being offline.
  bool offline = false;

  /// Counts calls, so tests can assert nothing was sent.
  int upsertCalls = 0;

  DateTime _tick() => _clock = _clock.add(const Duration(milliseconds: 10));

  @override
  Future<void> upsert(String table, List<Row> rows) async {
    if (offline) throw StateError('offline');
    upsertCalls++;
    final t = tables.putIfAbsent(table, () => {});
    for (final r in rows) {
      final id = r['id']! as String;
      final old = t[id];
      if (old != null && parseTs(r['updated_at']).isBefore(parseTs(old['updated_at']))) {
        continue; // stale write ignored, like the server trigger
      }
      t[id] = {...r, 'server_updated_at': _tick().toIso8601String()};
    }
    _changes.add(null);
  }

  @override
  Future<List<Row>> fetchSince(String table, DateTime? cursor, {int limit = 500}) async {
    if (offline) throw StateError('offline');
    final rows = (tables[table]?.values ?? const <Row>[]).where((r) {
      if (cursor == null) return true;
      return !parseTs(r['server_updated_at']).isBefore(cursor);
    }).toList()
      ..sort((a, b) => parseTs(a['server_updated_at'])
          .compareTo(parseTs(b['server_updated_at'])));
    return rows.take(limit).toList();
  }

  @override
  Stream<void> changes() => _changes.stream;

  /// Simulates a write made by another device directly on the server.
  void serverWrite(String table, Row row) {
    final t = tables.putIfAbsent(table, () => {});
    t[row['id']! as String] = {...row, 'server_updated_at': _tick().toIso8601String()};
    _changes.add(null);
  }
}
