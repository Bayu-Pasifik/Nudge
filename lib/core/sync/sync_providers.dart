import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../db/providers.dart';
import '../nag/providers.dart';
import '../settings/prefs.dart';
import 'remote.dart';
import 'sync_engine.dart';

/// Null in local-only mode. Overridden in `main()` (Supabase) and in tests.
final remoteProvider = Provider<RemoteApi?>((ref) => null);

class SyncStatus {
  const SyncStatus(this.state, {this.enabled = true, this.lastSync, this.error});
  final SyncState state;

  /// False in local-only mode or while signed out.
  final bool enabled;
  final DateTime? lastSync;
  final String? error;
}

/// Runs [SyncEngine] while a user is signed in: at start, shortly after local
/// edits, when the server reports changes from another device, on resume and
/// every few minutes as a safety net.
class SyncController extends Notifier<SyncStatus> with WidgetsBindingObserver {
  SyncEngine? _engine;
  Timer? _debounce;
  Timer? _periodic;
  StreamSubscription<void>? _dbSub;
  StreamSubscription<void>? _remoteSub;

  @override
  SyncStatus build() {
    final session = ref.watch(authSessionProvider);
    final remote = ref.watch(remoteProvider);
    ref.onDispose(_stop);
    _stop();
    if (!session.signedIn || remote == null) {
      return const SyncStatus(SyncState.idle, enabled: false);
    }
    _start(remote);
    return const SyncStatus(SyncState.syncing);
  }

  void _start(RemoteApi remote) {
    final db = ref.read(appDatabaseProvider);
    _engine = SyncEngine(db, remote, ref.read(sharedPrefsProvider));
    WidgetsBinding.instance.addObserver(this);

    _dbSub = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            db.boards,
            db.lists,
            db.cards,
            db.checklistItems,
            db.labels,
            db.cardLabels,
            db.reminders,
          ]),
        )
        .listen((_) => _schedule(const Duration(seconds: 2)));
    _remoteSub = remote.changes().listen(
          (_) => _schedule(const Duration(milliseconds: 500)),
        );
    _periodic = Timer.periodic(const Duration(minutes: 5), (_) => syncNow());
    Future.microtask(syncNow);
  }

  void _stop() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _periodic?.cancel();
    _dbSub?.cancel();
    _remoteSub?.cancel();
    _engine = null;
  }

  void _schedule(Duration after) {
    _debounce?.cancel();
    _debounce = Timer(after, syncNow);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) syncNow();
  }

  /// Sync once now. Never throws; failures show up in [state].
  Future<void> syncNow() async {
    final engine = _engine;
    if (engine == null) return;
    if (state.state != SyncState.syncing) {
      state = SyncStatus(SyncState.syncing, lastSync: state.lastSync);
    }
    try {
      await engine.sync();
      if (_engine == engine) state = SyncStatus(SyncState.idle, lastSync: DateTime.now());
    } catch (e) {
      if (_engine != engine) return;
      state = SyncStatus(
        SyncState.offline,
        lastSync: state.lastSync,
        error: e.toString(),
      );
    }
  }

  /// Pushes pending changes (best effort), signs out and wipes local data so
  /// the next account never sees this one's data.
  Future<void> signOutAndWipe() async {
    final backend = ref.read(authBackendProvider);
    if (backend == null) return;
    await syncNow();
    _stop();
    await backend.signOut();
    await ref.read(repositoryProvider).clearAllData();
    final prefs = ref.read(sharedPrefsProvider);
    for (final k in prefs.getKeys().where((k) => k.startsWith('sync_cursor_')).toList()) {
      await prefs.remove(k);
    }
    await ref.read(nagSchedulerProvider).rescheduleAll();
  }
}

final syncControllerProvider =
    NotifierProvider<SyncController, SyncStatus>(SyncController.new);
