import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../theme/tokens.dart' show StickyColors;
import 'notification_gateway.dart';

const _actionDone = 'done';
const _actionSnooze = 'snooze';

NagAction? nagActionFrom(NotificationResponse r) {
  switch (r.actionId) {
    case _actionDone:
      return NagAction.done;
    case _actionSnooze:
      return NagAction.snooze;
    case null:
    case '':
      return NagAction.open;
  }
  return null;
}

/// Android implementation backed by flutter_local_notifications: exact
/// alarms, three escalation channels, Selesai/Tunda action buttons.
class LocalNotificationsGateway implements NotificationGateway {
  LocalNotificationsGateway({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _channelIds = {
    1: 'nudge_nag_1',
    2: 'nudge_nag_2',
    3: 'nudge_nag_3',
  };

  /// Initialises the plugin and timezone database. Safe to call repeatedly.
  Future<void> init({
    DidReceiveNotificationResponseCallback? onResponse,
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse,
  }) async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('timezone lookup failed, using UTC: $e');
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'nudge_nag_1',
        'Pengingat',
        description: 'Pengingat tugas yang belum selesai',
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        'nudge_nag_2',
        'Pengingat mendesak',
        description: 'Pengingat berulang yang diabaikan: suara keras dan getar panjang',
        importance: Importance.max,
        vibrationPattern: Int64List.fromList([0, 800, 300, 800, 300, 800]),
      ),
    );
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        'nudge_nag_3',
        'Pengingat kritis',
        description: 'Peringatan layar penuh untuk tugas yang terus diabaikan',
        importance: Importance.max,
        vibrationPattern: Int64List.fromList([0, 1000, 400, 1000, 400, 1000]),
      ),
    );
    _ready = true;
  }

  /// The notification that launched the app (cold start tap), if any.
  Future<NotificationResponse?> launchResponse() async {
    final d = await _plugin.getNotificationAppLaunchDetails();
    if (d == null || !d.didNotificationLaunchApp) return null;
    return d.notificationResponse;
  }

  NotificationDetails _details(NagNotification n) {
    final level = n.level.clamp(1, 3);
    final channel = _channelIds[level]!;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        switch (level) {
          1 => 'Pengingat',
          2 => 'Pengingat mendesak',
          _ => 'Pengingat kritis',
        },
        importance: level == 1 ? Importance.high : Importance.max,
        priority: level == 1 ? Priority.high : Priority.max,
        category: AndroidNotificationCategory.reminder,
        vibrationPattern: level == 1
            ? null
            : Int64List.fromList([0, 800, 300, 800, 300, 800]),
        fullScreenIntent: level == 3,
        audioAttributesUsage:
            level == 3 ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
        // FLAG_INSISTENT (4): keep sounding until the user reacts (level 3).
        additionalFlags: level == 3 ? Int32List.fromList([4]) : null,
        timeoutAfter: null,
        autoCancel: true,
        actions: const [
          AndroidNotificationAction(_actionDone, 'Selesai'),
          AndroidNotificationAction(_actionSnooze, 'Tunda 10 mnt'),
        ],
      ),
    );
  }

  @override
  Future<void> replaceAllNags(List<NagNotification> notifications) async {
    await cancelAllNags();
    for (final n in notifications) {
      await _plugin.zonedSchedule(
        id: n.id,
        title: n.title,
        body: n.body,
        scheduledDate: tz.TZDateTime.from(n.at, tz.local),
        notificationDetails: _details(n),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: n.payload,
      );
    }
  }

  @override
  Future<void> cancelAllNags() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      final payload = NagPayload.parse(p.payload);
      if (payload != null && !payload.isSticky) {
        await _plugin.cancel(id: p.id);
      }
    }
  }

  @override
  Future<void> syncSticky(List<StickyNote> notes) async {
    final wanted = {for (final n in notes) n.id};
    final active = await _plugin.getActiveNotifications();
    for (final a in active) {
      final id = a.id;
      final payload = NagPayload.parse(a.payload);
      if (id != null && payload != null && payload.isSticky && !wanted.contains(id)) {
        await _plugin.cancel(id: id);
      }
    }
    for (final n in notes) {
      final accent = StickyColors.byName(n.colorName);
      await _plugin.show(
        id: n.id,
        title: n.title,
        body: n.body,
        payload: n.payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'nudge_sticky',
            'Sticky note',
            channelDescription: 'Tugas ter-pin yang selalu terlihat',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true, // cannot be swiped away
            autoCancel: false,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
            showWhen: false,
            category: AndroidNotificationCategory.status,
            color: accent.edge,
            actions: const [AndroidNotificationAction(_actionDone, 'Selesai')],
          ),
        ),
      );
    }
  }

  @override
  Future<List<NagNotification>> pendingNags() async {
    final pending = await _plugin.pendingNotificationRequests();
    final out = <NagNotification>[];
    for (final p in pending) {
      final payload = NagPayload.parse(p.payload);
      if (payload == null) continue;
      out.add(
        NagNotification(
          id: p.id,
          reminderId: payload.reminderId,
          cardId: payload.cardId,
          title: p.title ?? '',
          body: p.body ?? '',
          at: DateTime.fromMillisecondsSinceEpoch(0), // not exposed by plugin
          level: 1,
          index: 0,
        ),
      );
    }
    return out;
  }

  /// Titles of notifications currently showing in the shade (diagnostics).
  Future<List<String>> activeTitles() async {
    final active = await _plugin.getActiveNotifications();
    return [for (final n in active) n.title ?? ''];
  }

  @override
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final notif = await android?.requestNotificationsPermission() ?? true;
    await android?.requestExactAlarmsPermission();
    return notif;
  }

  @override
  Future<bool> notificationsAllowed() async {
    if (!Platform.isAndroid) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? true;
  }
}

/// No-op gateway for platforms without a notification backend yet.
class NoopNotificationGateway implements NotificationGateway {
  @override
  Future<void> cancelAllNags() async {}
  @override
  Future<void> syncSticky(List<StickyNote> notes) async {}
  @override
  Future<bool> notificationsAllowed() async => false;
  @override
  Future<List<NagNotification>> pendingNags() async => const [];
  @override
  Future<void> replaceAllNags(List<NagNotification> notifications) async {}
  @override
  Future<bool> requestPermissions() async => false;
}

/// In-memory gateway used by tests: records what would have been scheduled.
class InMemoryNotificationGateway implements NotificationGateway {
  List<NagNotification> scheduled = [];
  List<StickyNote> stickies = [];
  bool allowed = true;

  @override
  Future<void> syncSticky(List<StickyNote> notes) async =>
      stickies = List.of(notes);

  @override
  Future<void> replaceAllNags(List<NagNotification> notifications) async {
    scheduled = List.of(notifications);
  }

  @override
  Future<void> cancelAllNags() async => scheduled = [];

  @override
  Future<List<NagNotification>> pendingNags() async => List.of(scheduled);

  @override
  Future<bool> requestPermissions() async => allowed;

  @override
  Future<bool> notificationsAllowed() async => allowed;
}
