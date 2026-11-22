import 'dart:io' show exit;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../nag/notification_gateway.dart';
import '../settings/prefs.dart';
import 'sticky_mode.dart';

/// window_manager implementation of [WindowController].
class DesktopWindowController implements WindowController {
  Size? _savedSize;

  @override
  Future<void> enterSticky() async {
    _savedSize = await windowManager.getSize();
    await windowManager.setMinimumSize(const Size(260, 200));
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setSize(const Size(340, 520));
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
  }

  @override
  Future<void> exitSticky() async {
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setMinimumSize(const Size(420, 520));
    await windowManager.setSize(_savedSize ?? const Size(1100, 720));
    await windowManager.center();
  }

  @override
  Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Level-3 alerts: pop to the front for a moment even over other apps.
  @override
  Future<void> raiseTemporarily() async {
    await windowManager.show();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.focus();
    await Future<void>.delayed(const Duration(seconds: 8));
    if (!await _stickyOn()) await windowManager.setAlwaysOnTop(false);
  }

  bool Function() stickyOn = () => false;
  Future<bool> _stickyOn() async => stickyOn();
}

/// Window setup, close-to-tray and the tray menu. Call once at startup.
class DesktopHost with WindowListener, TrayListener {
  DesktopHost(this.container);
  final ProviderContainer container;
  final DesktopWindowController controller = DesktopWindowController();

  Future<void> init() async {
    await windowManager.ensureInitialized();
    const opts = WindowOptions(
      size: Size(1100, 720),
      minimumSize: Size(420, 520),
      center: true,
      title: 'Nudge',
    );
    await windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    // Closing the window hides it to the tray so reminders keep firing.
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    controller.stickyOn = () => container.read(stickyModeProvider);
    trayManager.addListener(this);
    await trayManager.setIcon('assets/tray.ico');
    await trayManager.setToolTip('Nudge');
    await _buildMenu();
  }

  Future<void> _buildMenu() => trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'open', label: 'Buka Nudge'),
            MenuItem(key: 'sticky', label: 'Mode sticky'),
            MenuItem.separator(),
            MenuItem(key: 'pause1h', label: 'Jeda pengingat 1 jam'),
            MenuItem(key: 'resume', label: 'Lanjutkan pengingat'),
            MenuItem.separator(),
            MenuItem(key: 'quit', label: 'Keluar'),
          ],
        ),
      );

  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }

  @override
  void onTrayIconMouseDown() => controller.show();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        controller.show();
      case 'sticky':
        container.read(stickyModeProvider.notifier).toggle();
      case 'pause1h':
        container
            .read(pausedUntilProvider.notifier)
            .pauseFor(const Duration(hours: 1));
      case 'resume':
        container.read(pausedUntilProvider.notifier).resume();
      case 'quit':
        windowManager.setPreventClose(false);
        windowManager.destroy();
        exit(0);
    }
  }
}

/// Turns a Windows toast press into our [NagAction].
NagAction? desktopActionFrom(NotificationResponse r) {
  switch (r.actionId) {
    case 'done':
      return NagAction.done;
    case 'snooze':
      return NagAction.snooze;
  }
  return NagAction.open;
}

bool get isDesktopPlatform =>
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.macOS;
