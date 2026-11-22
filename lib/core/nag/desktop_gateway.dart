import 'dart:async';

import 'notification_gateway.dart';

/// Desktop has no OS-level scheduled notifications for unpackaged apps, so
/// nags are fired by an in-process timer. This works because the desktop app
/// stays alive in the system tray (close = hide).
///
/// Everything platform-specific (showing a toast, raising the window for
/// level-3 alerts) is injected so the timing logic is testable.
class TimerNotificationGateway implements NotificationGateway {
  TimerNotificationGateway({
    required this.show,
    this.onEscalate,
    DateTime Function()? clock,
    this.allowed = true,
  }) : _now = clock ?? DateTime.now;

  /// Shows one toast.
  final Future<void> Function(NagNotification n) show;

  /// Called for level-3 nags so the app can bring its window to the front.
  final void Function(NagNotification n)? onEscalate;

  final DateTime Function() _now;
  bool allowed;

  List<NagNotification> _pending = [];
  List<StickyNote> _stickies = [];
  Timer? _timer;

  /// Sticky notes for the current state (the desktop sticky window reads the
  /// DB directly; this is kept for diagnostics).
  List<StickyNote> get stickies => List.unmodifiable(_stickies);

  @override
  Future<void> replaceAllNags(List<NagNotification> notifications) async {
    _pending = [...notifications]..sort((a, b) => a.at.compareTo(b.at));
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty) return;
    final wait = _pending.first.at.difference(_now());
    _timer = Timer(wait.isNegative ? Duration.zero : wait, _fire);
  }

  Future<void> _fire() async {
    final now = _now();
    while (_pending.isNotEmpty && !_pending.first.at.isAfter(now)) {
      final n = _pending.removeAt(0);
      await show(n);
      if (n.level >= 3) onEscalate?.call(n);
    }
    _arm();
  }

  @override
  Future<void> cancelAllNags() async {
    _pending = [];
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<List<NagNotification>> pendingNags() async => List.of(_pending);

  @override
  Future<void> syncSticky(List<StickyNote> notes) async => _stickies = notes;

  @override
  Future<bool> notificationsAllowed() async => allowed;

  @override
  Future<bool> requestPermissions() async => allowed;

  void dispose() => _timer?.cancel();
}
