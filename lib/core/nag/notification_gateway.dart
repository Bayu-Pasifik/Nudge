import 'dart:convert';

/// One notification to be shown at [at]. [id] is stable so re-scheduling
/// replaces instead of duplicating.
class NagNotification {
  const NagNotification({
    required this.id,
    required this.reminderId,
    required this.cardId,
    required this.title,
    required this.body,
    required this.at,
    required this.level,
    required this.index,
  });

  final int id;
  final String reminderId;
  final String cardId;
  final String title;
  final String body;
  final DateTime at;

  /// Escalation level 1..3.
  final int level;

  /// 0 = first notification of the sequence.
  final int index;

  String get payload => jsonEncode({'t': 'nag', 'r': reminderId, 'c': cardId});
}

/// Payload carried by every Nudge notification. [isSticky] distinguishes the
/// always-on pinned-card notifications from scheduled nags.
class NagPayload {
  const NagPayload(this.reminderId, this.cardId, {this.isSticky = false});
  final String reminderId;
  final String cardId;
  final bool isSticky;

  static NagPayload? parse(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map;
      switch (m['t']) {
        case 'nag':
          return NagPayload(m['r'] as String, m['c'] as String);
        case 'sticky':
          return NagPayload('', m['c'] as String, isSticky: true);
      }
    } catch (_) {}
    return null;
  }
}

/// A pinned card shown as a persistent ("sticky note") notification.
class StickyNote {
  const StickyNote({
    required this.id,
    required this.cardId,
    required this.title,
    required this.body,
    required this.colorName,
  });

  final int id;
  final String cardId;
  final String title;
  final String body;
  final String colorName;

  String get payload => jsonEncode({'t': 'sticky', 'c': cardId});
}

/// Notification id for a sticky note. Offset keeps it clear of nag ids.
int stickyNotificationId(String cardId) {
  final h = cardId.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0xFFFFF);
  return 2000000000 + h;
}

/// What the user pressed on a notification.
enum NagAction { open, done, snooze }

/// Platform-independent surface for scheduling nags. The real implementation
/// wraps flutter_local_notifications; tests use an in-memory fake.
abstract class NotificationGateway {
  /// Replaces every pending nag with [notifications].
  Future<void> replaceAllNags(List<NagNotification> notifications);

  Future<void> cancelAllNags();

  /// Makes the set of persistent sticky-note notifications equal [notes]:
  /// shows/updates those, removes any others.
  Future<void> syncSticky(List<StickyNote> notes);

  /// Pending nags (for diagnostics and tests).
  Future<List<NagNotification>> pendingNags();

  /// Asks for notification + exact-alarm permissions. True if notifications
  /// are allowed.
  Future<bool> requestPermissions();

  Future<bool> notificationsAllowed();
}

/// Stable int id for a (reminder, sequence index) pair.
int notificationId(String reminderId, int index) {
  // 21 bits of hash * 100 slots keeps the id inside a signed 32-bit int.
  final h = reminderId.codeUnits.fold<int>(17, (a, c) => (a * 31 + c) & 0x1FFFFF);
  return h * 100 + (index % 100);
}
