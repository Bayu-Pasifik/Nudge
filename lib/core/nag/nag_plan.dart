import 'dart:convert';

/// Escalate to [level] once [after] nags have fired without being handled.
/// Level 1 = normal notification, 2 = loud + long vibration, 3 = full screen.
class EscalationStep {
  const EscalationStep(this.after, this.level);
  final int after;
  final int level;

  Map<String, Object> toJson() => {'after': after, 'level': level};
}

const defaultEscalation = [EscalationStep(3, 2), EscalationStep(6, 3)];

List<EscalationStep> parseEscalation(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final list = jsonDecode(json) as List;
    return [
      for (final e in list)
        EscalationStep(
          (e as Map)['after'] as int,
          e['level'] as int,
        ),
    ];
  } catch (_) {
    return const [];
  }
}

String? encodeEscalation(List<EscalationStep> steps) =>
    steps.isEmpty ? null : jsonEncode([for (final s in steps) s.toJson()]);

/// Everything the planner needs from a reminder. Pure value object so the
/// planner stays free of DB and platform code.
class NagConfig {
  const NagConfig({
    required this.remindAt,
    this.nagEnabled = true,
    this.intervalMinutes = 10,
    this.maxCount,
    this.escalation = const [],
    this.quietStartMinute,
    this.quietEndMinute,
    this.snoozedUntil,
  });

  final DateTime remindAt;
  final bool nagEnabled;
  final int intervalMinutes;

  /// Total notifications including the first. Null = until done.
  final int? maxCount;
  final List<EscalationStep> escalation;

  /// Quiet hours, minutes from local midnight. Repeats inside the window are
  /// suppressed (the very first notification is not: the user set that time).
  final int? quietStartMinute;
  final int? quietEndMinute;

  /// When set, the sequence restarts from this moment.
  final DateTime? snoozedUntil;

  DateTime get base => snoozedUntil ?? remindAt;
}

class NagEvent {
  const NagEvent(this.at, this.index, this.level);
  final DateTime at;

  /// 0 for the first notification, then 1, 2, ...
  final int index;
  final int level;

  @override
  String toString() => 'NagEvent($at, #$index, L$level)';

  @override
  bool operator ==(Object other) =>
      other is NagEvent &&
      other.at == at &&
      other.index == index &&
      other.level == level;

  @override
  int get hashCode => Object.hash(at, index, level);
}

class NagPlan {
  const NagPlan._();

  static bool _inQuiet(NagConfig c, DateTime at) {
    final s = c.quietStartMinute;
    final e = c.quietEndMinute;
    if (s == null || e == null || s == e) return false;
    final m = at.hour * 60 + at.minute;
    return s < e ? (m >= s && m < e) : (m >= s || m < e);
  }

  static int levelFor(NagConfig c, int index) {
    var level = 1;
    for (final step in c.escalation) {
      if (index >= step.after && step.level > level) level = step.level;
    }
    return level;
  }

  /// Notifications strictly after [now], earliest first, at most [limit].
  static List<NagEvent> upcoming(
    NagConfig c, {
    required DateTime now,
    int limit = 20,
  }) {
    final out = <NagEvent>[];
    final base = c.base;
    final interval = Duration(minutes: c.intervalMinutes.clamp(1, 24 * 60));

    if (!c.nagEnabled) {
      if (base.isAfter(now)) out.add(NagEvent(base, 0, levelFor(c, 0)));
      return out.take(limit).toList();
    }

    var k = 0;
    if (!base.isAfter(now)) {
      k = now.difference(base).inMicroseconds ~/ interval.inMicroseconds + 1;
    }
    var guard = 0;
    while (out.length < limit && guard++ < 5000) {
      if (c.maxCount != null && k >= c.maxCount!) break;
      final at = base.add(interval * k);
      if (at.isAfter(now) && (k == 0 || !_inQuiet(c, at))) {
        out.add(NagEvent(at, k, levelFor(c, k)));
      }
      k++;
    }
    return out;
  }

  /// True when the reminder has run out of notifications and the card is
  /// still not done (shown as "Terlewat").
  static bool isMissed(NagConfig c, {required DateTime now}) {
    if (c.base.isAfter(now)) return false;
    if (!c.nagEnabled) return true;
    if (c.maxCount == null) return false;
    // Last slot of the sequence (quiet suppression ignored on purpose: the
    // sequence is over once its final slot is in the past).
    final last = c.base.add(
      Duration(minutes: c.intervalMinutes.clamp(1, 24 * 60)) * (c.maxCount! - 1),
    );
    return !last.isAfter(now);
  }

  /// 'scheduled' | 'nagging' | 'missed' for an unfinished reminder.
  static String stateAt(NagConfig c, {required DateTime now}) {
    if (c.base.isAfter(now)) return 'scheduled';
    return isMissed(c, now: now) ? 'missed' : 'nagging';
  }
}
