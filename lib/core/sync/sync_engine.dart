import 'package:shared_preferences/shared_preferences.dart';

import '../db/database.dart';
import 'remote.dart';
import 'sync_tables.dart';

enum SyncState { idle, syncing, offline, error }

class SyncResult {
  const SyncResult({this.pushed = 0, this.pulled = 0, this.applied = 0});
  final int pushed;
  final int pulled;

  /// Remote rows that actually changed local data.
  final int applied;
}

/// Local-first sync.
///
/// 1. **Pull**: fetch server rows changed since the stored cursor and apply
///    each one unless the local copy is dirty *and* newer (last-write-wins on
///    `updated_at`).
/// 2. **Push**: send every dirty row, parents before children, then mark the
///    rows clean (only if they were not edited again meanwhile).
///
/// The server also ignores stale writes, so two devices racing is safe.
class SyncEngine {
  SyncEngine(this.db, this.remote, this.prefs, {this.namespace = ''});

  final AppDatabase db;
  final RemoteApi remote;
  final SharedPreferences prefs;

  /// Distinguishes cursors when several engines share one prefs store (tests).
  final String namespace;

  Future<void> _chain = Future.value();

  /// Serialized: overlapping calls run one after another.
  Future<SyncResult> sync() {
    final run = _chain.then((_) => _sync());
    _chain = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  String _cursorKey(String table) => 'sync_cursor_${namespace}_${remote.userId}_$table';

  DateTime? _cursor(String table) {
    final ms = prefs.getString(_cursorKey(table));
    return ms == null ? null : DateTime.parse(ms);
  }

  Future<SyncResult> _sync() async {
    var pulled = 0;
    var applied = 0;
    var pushed = 0;

    for (final t in syncTables) {
      var cursor = _cursor(t.name);
      while (true) {
        final before = cursor;
        final rows = await remote.fetchSince(t.name, cursor);
        for (final r in rows) {
          pulled++;
          if (await _apply(t, r)) applied++;
          final ts = parseTs(r['server_updated_at']);
          if (cursor == null || ts.isAfter(cursor)) cursor = ts;
        }
        if (rows.isNotEmpty) {
          await prefs.setString(_cursorKey(t.name), cursor!.toIso8601String());
        }
        // `>= cursor` re-returns the last row, so a short page means done;
        // also stop if the cursor did not move (avoids spinning forever).
        if (rows.length < 500 || cursor == before) break;
      }
    }

    for (final t in syncTables) {
      final dirty = await t.dirty(db, remote.userId);
      if (dirty.isEmpty) continue;
      await remote.upsert(t.name, [for (final d in dirty) d.row]);
      for (final d in dirty) {
        await t.markClean(db, d.id, d.updatedAt);
      }
      pushed += dirty.length;
    }

    return SyncResult(pushed: pushed, pulled: pulled, applied: applied);
  }

  /// Returns true if the row changed local data.
  Future<bool> _apply(SyncTable t, Row r) async {
    final id = r['id']! as String;
    final remoteAt = parseTs(r['updated_at']);
    final local = await t.local(db, id);
    if (local != null) {
      final localAt = local.updatedAt.toUtc();
      if (local.dirty && !remoteAt.isAfter(localAt)) return false; // ours wins
      if (!local.dirty && remoteAt.isAtSameMomentAs(localAt)) return false; // no-op
    }
    await t.applyRemote(db, r);
    return true;
  }
}
