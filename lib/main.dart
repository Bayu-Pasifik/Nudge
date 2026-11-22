import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/auth/auth_backend.dart';
import 'core/auth/auth_providers.dart';
import 'core/config.dart';
import 'core/db/database.dart';
import 'core/db/providers.dart';
import 'core/db/repository.dart';
import 'core/nag/local_notifications_gateway.dart';
import 'core/nag/nag_actions.dart';
import 'core/nag/nag_scheduler.dart';
import 'core/nag/notification_gateway.dart';
import 'core/nag/providers.dart';
import 'core/settings/prefs.dart';
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
      NagScheduler(repo, gateway, pausedUntil: () => readPausedUntil(prefs)),
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
  final prefs = await SharedPreferences.getInstance();
  SupabaseClient? supabase;
  if (AppConfig.hasSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseKey,
    );
    supabase = Supabase.instance.client;
  }
  final container = ProviderContainer(
    overrides: [
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

  runApp(UncontrolledProviderScope(container: container, child: const NudgeApp()));
}
