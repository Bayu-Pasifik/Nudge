import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../nag/providers.dart';

/// Overridden in `main()` / tests with a loaded instance.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

/// Reads the pause deadline straight from prefs (used by the background
/// isolate, which has no Riverpod container). Null when not paused.
DateTime? readPausedUntil(SharedPreferences prefs) {
  final ms = prefs.getInt(PausedUntilNotifier.key);
  if (ms == null) return null;
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return d.isAfter(DateTime.now()) ? d : null;
}

/// "Jeda semua pengingat": nothing fires before this time.
class PausedUntilNotifier extends Notifier<DateTime?> {
  static const key = 'paused_until_ms';

  @override
  DateTime? build() => readPausedUntil(ref.read(sharedPrefsProvider));

  Future<void> pauseFor(Duration d) => _set(DateTime.now().add(d));
  Future<void> pauseUntil(DateTime t) => _set(t);
  Future<void> resume() => _set(null);

  Future<void> _set(DateTime? t) async {
    state = t;
    final prefs = ref.read(sharedPrefsProvider);
    if (t == null) {
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, t.millisecondsSinceEpoch);
    }
    // Pausing/resuming changes what should be scheduled.
    await ref.read(nagSchedulerProvider).rescheduleAll();
  }
}

final pausedUntilProvider =
    NotifierProvider<PausedUntilNotifier, DateTime?>(PausedUntilNotifier.new);
