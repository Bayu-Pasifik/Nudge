/// A row as sent to / received from the server: snake_case keys, ISO-8601
/// timestamps, matching `supabase/migrations`.
typedef Row = Map<String, Object?>;

/// The server side of sync. The real implementation talks to Supabase; tests
/// use [FakeRemote]. Keeping this narrow keeps [SyncEngine] testable without a
/// backend.
abstract class RemoteApi {
  /// Id of the signed-in user. Rows are stamped with it on push.
  String get userId;

  /// Inserts or updates [rows] by `id`. The server ignores rows older (by
  /// `updated_at`) than what it already has.
  Future<void> upsert(String table, List<Row> rows);

  /// Rows of [table] whose `server_updated_at` is >= [cursor], oldest first.
  Future<List<Row>> fetchSince(String table, DateTime? cursor, {int limit = 500});

  /// Emits whenever another device changed something (Realtime).
  Stream<void> changes();
}

/// Server timestamps are UTC; the app works in local time (UI reads .hour).
DateTime parseTs(Object? v) => DateTime.parse(v! as String).toLocal();
DateTime? parseTsOrNull(Object? v) => v == null ? null : parseTs(v);
String? fmtTs(DateTime? d) => d?.toUtc().toIso8601String();
