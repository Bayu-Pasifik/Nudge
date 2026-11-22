import 'dart:async';

import '../db/database.dart';
import '../db/repository.dart';
import 'nag_plan.dart';
import 'notification_gateway.dart';

/// Turns active reminders into concrete scheduled notifications.
///
/// Source of truth is the local DB; the schedule is rebuilt from scratch on
/// every call so it can never drift (app start, data change, resume, ...).
class NagScheduler {
  NagScheduler(
    this.repo,
    this.gateway, {
    DateTime Function()? clock,
    this.perReminderLimit = 48,
    this.maxTotal = 200,
    this.pausedUntil,
    this.onPinned,
  }) : _now = clock ?? DateTime.now;

  final Repository repo;
  final NotificationGateway gateway;
  final DateTime Function() _now;

  /// Upcoming notifications scheduled per reminder.
  final int perReminderLimit;

  /// Global cap (iOS allows 64 pending local notifications).
  final int maxTotal;

  /// "Jeda semua pengingat": nothing fires before this time.
  final DateTime? Function()? pausedUntil;

  /// Called with the pinned cards after every rebuild (feeds the home widget).
  final Future<void> Function(List<StickyInfo> pinned)? onPinned;

  Future<void> _chain = Future.value();

  /// Rebuilds the whole schedule. Calls are serialized.
  Future<void> rescheduleAll() {
    final run = _chain.then((_) => _run());
    _chain = run.catchError((_) {});
    return run;
  }

  Future<void> _run() async {
    final now = _now();
    final active = await repo.activeReminders();
    final pause = pausedUntil?.call();
    final all = <NagNotification>[];

    for (final a in active) {
      final r = a.reminder;
      final config = configOf(r);

      // Keep the stored state in sync with the clock.
      final state = NagPlan.stateAt(config, now: now);
      if (state != r.state) await repo.setReminderState(r.id, state);

      var events = NagPlan.upcoming(config, now: now, limit: perReminderLimit);
      if (pause != null && pause.isAfter(now)) {
        events = events.where((e) => !e.at.isBefore(pause)).toList();
      }
      for (final e in events) {
        all.add(
          NagNotification(
            id: notificationId(r.id, e.index),
            reminderId: r.id,
            cardId: a.card.id,
            title: a.card.title,
            body: _body(a, e),
            at: e.at,
            level: e.level,
            index: e.index,
          ),
        );
      }
    }

    all.sort((x, y) => x.at.compareTo(y.at));
    await gateway.replaceAllNags(all.take(maxTotal).toList());
    await _syncSticky();
  }

  /// At most this many sticky notes are shown (the shade gets crowded).
  static const maxSticky = 6;

  Future<void> _syncSticky() async {
    final pinned = await repo.pinnedStickies();
    await onPinned?.call(pinned);
    await gateway.syncSticky([
      for (final s in pinned.take(maxSticky))
        StickyNote(
          id: stickyNotificationId(s.open.card.id),
          cardId: s.open.card.id,
          title: s.open.card.title,
          body: [
            if (s.total > 0) '${s.done}/${s.total} selesai',
            '${s.open.boardTitle} › ${s.open.listTitle}',
          ].join(' · '),
          colorName: s.open.card.stickyColor,
        ),
    ]);
  }

  String _body(ActiveReminder a, NagEvent e) {
    final where = '${a.boardTitle} › ${a.listTitle}';
    if (e.index == 0) return where;
    return 'Belum selesai · pengingat ke-${e.index} · $where';
  }
}

/// Maps a DB reminder row to the pure planner input.
NagConfig configOf(Reminder r) => NagConfig(
      remindAt: r.remindAt,
      nagEnabled: r.nagEnabled,
      intervalMinutes: r.nagIntervalMinutes,
      maxCount: r.nagMaxCount,
      escalation: parseEscalation(r.escalation),
      quietStartMinute: r.quietStartMinute,
      quietEndMinute: r.quietEndMinute,
      snoozedUntil: r.snoozedUntil,
    );
