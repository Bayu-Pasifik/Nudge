import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/auth/auth_backend.dart';
import 'core/auth/auth_providers.dart';
import 'core/config.dart';
import 'core/desktop/desktop_host.dart';
import 'core/desktop/sticky_mode.dart';
import 'core/nag/desktop_gateway.dart';
import 'core/db/database.dart';
import 'core/db/providers.dart';
import 'core/db/repository.dart';
import 'core/nag/local_notifications_gateway.dart';
import 'core/nag/nag_actions.dart';
import 'core/nag/nag_scheduler.dart';
import 'core/nag/notification_gateway.dart';
import 'core/nag/providers.dart';
import 'core/settings/prefs.dart';
import 'core/widget/home_widget_sync.dart';
import 'package:home_widget/home_widget.dart';
import 'core/sync/supabase_remote.dart';
import 'core/sync/sync_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs in a background isolate when the user presses Selesai/Tunda on a
/// notification while the app is closed.
@pragma('vm:entry-point')
Future<void> nudgeNotificationBackground(NotificationResponse r) async {
  DartPluginRegistrant.ensureInitialized();
  final action = nagActionFrom(r);
  final payload = NagPayload.parse(r.payload);
  if (action == null || payload == null || action == NagAction.open) return;

  final gateway = LocalNotificationsGateway();
  await gateway.init();
  final db = AppDatabase();
  final repo = Repository(db);
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload(); // pick up a pause set by the main isolate
  try {
    await handleNagAction(
      repo,
      NagScheduler(
        repo,
        gateway,
        pausedUntil: () => readPausedUntil(prefs),
        onPinned: updateHomeWidget,
      ),
      action,
      payload,
    );
  } finally {
    await db.close();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final LocalNotificationsGateway? local =
      Platform.isAndroid ? LocalNotificationsGateway() : null;

  // Windows: in-process timers + toast notifications; the app lives in the tray.
  late final ProviderContainer container;
  final DesktopWindowController? desktopWindow =
      Platform.isWindows ? DesktopWindowController() : null;
  // Assigned once the container exists (toasts can only fire after startup).
  late final Future<void> Function(NagAction, NagPayload) onDesktopAction;
  final TimerNotificationGateway? desktopGateway = Platform.isWindows
      ? TimerNotificationGateway(
          show: (n) async {
            final toast = LocalNotification(
              identifier: '${n.id}',
              title: n.title,
              body: n.body,
              actions: [
                LocalNotificationAction(text: 'Selesai'),
                LocalNotificationAction(text: 'Tunda 10 mnt'),
              ],
            );
            final payload = NagPayload(n.reminderId, n.cardId);
            toast.onClick = () => onDesktopAction(NagAction.open, payload);
            toast.onClickAction = (i) => onDesktopAction(
                  i == 0 ? NagAction.done : NagAction.snooze,
                  payload,
                );
            await toast.show();
          },
          onEscalate: (_) => desktopWindow!.raiseTemporarily(),
        )
      : null;

  final prefs = await SharedPreferences.getInstance();
  SupabaseClient? supabase;
  if (AppConfig.hasSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseKey,
    );
    supabase = Supabase.instance.client;
  }
  container = ProviderContainer(
    overrides: [
      if (desktopGateway != null) ...[
        notificationGatewayProvider.overrideWithValue(desktopGateway),
        windowControllerProvider.overrideWithValue(desktopWindow!),
      ],
      sharedPrefsProvider.overrideWithValue(prefs),
      authBackendProvider.overrideWithValue(
        supabase == null ? null : SupabaseAuthBackend(supabase),
      ),
      remoteProvider.overrideWithValue(
        supabase == null ? null : SupabaseRemote(supabase),
      ),
      if (local != null) notificationGatewayProvider.overrideWithValue(local),
    ],
  );

  onDesktopAction = (NagAction action, NagPayload payload) async {
    if (action == NagAction.open) {
      container.read(openCardProvider.notifier).open(payload.cardId);
      await desktopWindow?.show();
      return;
    }
    await handleNagAction(
      container.read(repositoryProvider),
      container.read(nagSchedulerProvider),
      action,
      payload,
    );
  };

  Future<void> onResponse(NotificationResponse r) async {
    final action = nagActionFrom(r);
    final payload = NagPayload.parse(r.payload);
    if (action == null || payload == null) return;
    if (action == NagAction.open) {
      container.read(openCardProvider.notifier).open(payload.cardId);
      return;
    }
    await handleNagAction(
      container.read(repositoryProvider),
      container.read(nagSchedulerProvider),
      action,
      payload,
    );
  }

  if (local != null) {
    await local.init(
      onResponse: onResponse,
      onBackgroundResponse: nudgeNotificationBackground,
    );
    final launch = await local.launchResponse();
    final payload = NagPayload.parse(launch?.payload);
    if (launch != null &&
        payload != null &&
        nagActionFrom(launch) == NagAction.open) {
      container.read(openCardProvider.notifier).open(payload.cardId);
    }
  }

  if (Platform.isAndroid) {
    // Home screen widget: the tick button runs in the background, a title tap
    // opens the card.
    await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
    HomeWidget.widgetClicked.listen((uri) {
      final id = cardIdFromWidgetUri(uri);
      if (id != null) container.read(openCardProvider.notifier).open(id);
    });
    final launched =
        cardIdFromWidgetUri(await HomeWidget.initiallyLaunchedFromHomeWidget());
    if (launched != null) {
      container.read(openCardProvider.notifier).open(launched);
    }
  }

  if (Platform.isWindows) {
    await localNotifier.setup(
      appName: 'Nudge',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );
    await DesktopHost(container).init();
  }

  runApp(UncontrolledProviderScope(container: container, child: const NudgeApp()));
}
