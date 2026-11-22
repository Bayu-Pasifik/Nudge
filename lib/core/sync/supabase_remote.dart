import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'remote.dart';
import 'sync_tables.dart';

/// [RemoteApi] backed by Supabase (PostgREST + Realtime).
class SupabaseRemote implements RemoteApi {
  SupabaseRemote(this.client);
  final sb.SupabaseClient client;

  sb.RealtimeChannel? _channel;
  final _changes = StreamController<void>.broadcast();

  @override
  String get userId => client.auth.currentUser!.id;

  @override
  Future<void> upsert(String table, List<Row> rows) async {
    if (rows.isEmpty) return;
    // Chunked so a big first sync stays under request size limits.
    for (var i = 0; i < rows.length; i += 200) {
      await client
          .from(table)
          .upsert(rows.sublist(i, i + 200 > rows.length ? rows.length : i + 200),
              onConflict: 'id');
    }
  }

  @override
  Future<List<Row>> fetchSince(
    String table,
    DateTime? cursor, {
    int limit = 500,
  }) async {
    var q = client.from(table).select();
    if (cursor != null) {
      q = q.gte('server_updated_at', cursor.toUtc().toIso8601String());
    }
    final res = await q.order('server_updated_at', ascending: true).limit(limit);
    return [for (final r in res) Map<String, Object?>.from(r)];
  }

  @override
  Stream<void> changes() {
    _channel ??= _subscribe();
    return _changes.stream;
  }

  sb.RealtimeChannel _subscribe() {
    var ch = client.channel('nudge-sync');
    for (final t in syncTables) {
      ch = ch.onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: t.name,
        callback: (_) => _changes.add(null),
      );
    }
    return ch..subscribe();
  }

  Future<void> dispose() async {
    final ch = _channel;
    if (ch != null) await client.removeChannel(ch);
    await _changes.close();
  }
}
