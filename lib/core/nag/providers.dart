import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/providers.dart';
import '../settings/prefs.dart';
import 'local_notifications_gateway.dart';
import 'nag_scheduler.dart';
import 'notification_gateway.dart';

/// Overridden in `main()` with the real platform gateway.
final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => NoopNotificationGateway(),
);

final nagSchedulerProvider = Provider<NagScheduler>(
  (ref) => NagScheduler(
    ref.watch(repositoryProvider),
    ref.watch(notificationGatewayProvider),
    // Read lazily at schedule time; avoids a provider cycle with the pause
    // notifier (which itself triggers rescheduling).
    pausedUntil: () => ref.read(pausedUntilProvider),
  ),
);

/// Card id requested by a notification tap; the app shell navigates to it.
class OpenCardNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void open(String cardId) => state = cardId;
  void clear() => state = null;
}

final openCardProvider =
    NotifierProvider<OpenCardNotifier, String?>(OpenCardNotifier.new);

/// Keeps the notification schedule in sync with the database: rebuilds it
/// (debounced) whenever reminders or cards change, and when the app resumes.
class NagCoordinator with WidgetsBindingObserver {
  NagCoordinator(this._scheduler, this._updates);

  final NagScheduler _scheduler;
  final Stream<void> _updates;
  StreamSubscription<void>? _sub;
  Timer? _debounce;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _sub = _updates.listen((_) => _schedule());
    _schedule(immediate: true);
  }

  void _schedule({bool immediate = false}) {
    _debounce?.cancel();
    _debounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 300),
      () => _scheduler.rescheduleAll().catchError((Object e) {
        debugPrint('reschedule failed: $e');
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule(immediate: true);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _sub?.cancel();
  }
}

final nagCoordinatorProvider = Provider<NagCoordinator>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final updates = db
      .tableUpdates(TableUpdateQuery.onAllTables([db.reminders, db.cards]))
      .map((_) {});
  final c = NagCoordinator(ref.watch(nagSchedulerProvider), updates);
  ref.onDispose(c.dispose);
  return c;
});
