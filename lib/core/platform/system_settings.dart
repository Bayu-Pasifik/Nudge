import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens OS settings screens the user must visit for reliable reminders.
/// Injected so tests do not leave the app.
abstract class SystemSettingsLauncher {
  /// The app's notification settings (channels, sound, importance).
  Future<void> openNotificationSettings();

  /// The battery optimization list, to exempt Nudge from background limits.
  Future<void> openBatteryOptimization();

  /// The app's own settings page (permissions, autostart on some brands).
  Future<void> openAppDetails();
}

class AndroidSettingsLauncher implements SystemSettingsLauncher {
  AndroidSettingsLauncher({this.packageName = 'com.bayu.nudge'});
  final String packageName;

  @override
  Future<void> openNotificationSettings() => AndroidIntent(
        action: 'android.settings.APP_NOTIFICATION_SETTINGS',
        arguments: {'android.provider.extra.APP_PACKAGE': packageName},
      ).launch();

  @override
  Future<void> openBatteryOptimization() => const AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      ).launch();

  @override
  Future<void> openAppDetails() => AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:$packageName',
      ).launch();
}

class RecordingSettingsLauncher implements SystemSettingsLauncher {
  final calls = <String>[];
  @override
  Future<void> openNotificationSettings() async => calls.add('notifications');
  @override
  Future<void> openBatteryOptimization() async => calls.add('battery');
  @override
  Future<void> openAppDetails() async => calls.add('details');
}

final systemSettingsProvider = Provider<SystemSettingsLauncher>(
  (ref) => AndroidSettingsLauncher(),
);
