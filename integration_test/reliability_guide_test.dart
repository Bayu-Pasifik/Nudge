import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nudge/core/nag/local_notifications_gateway.dart';
import 'package:nudge/core/platform/system_settings.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
  }

  testWidgets('guide buttons open the right system screens', (tester) async {
    final launcher = RecordingSettingsLauncher();
    await pumpNudge(tester, startOnBoards: false, settings: launcher);
    await openSettings(tester);

    expect(find.text('Agar pengingat selalu bunyi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-notification-settings')));
    await tester.tap(find.byKey(const Key('open-battery-settings')));
    await tester.ensureVisible(find.byKey(const Key('open-app-details')));
    await tester.tap(find.byKey(const Key('open-app-details')));
    expect(launcher.calls, ['notifications', 'battery', 'details']);
  }, skip: !Platform.isAndroid);

  testWidgets('blocked notifications are called out', (tester) async {
    final gateway = InMemoryNotificationGateway()..allowed = false;
    await pumpNudge(
      tester,
      startOnBoards: false,
      gateway: gateway,
      settings: RecordingSettingsLauncher(),
    );
    await openSettings(tester);
    expect(find.text('Dimatikan. Pengingat tidak akan berbunyi.'), findsOneWidget);
  }, skip: !Platform.isAndroid);

  testWidgets('the guide is hidden outside Android', (tester) async {
    await pumpNudge(tester, startOnBoards: false);
    await openSettings(tester);
    expect(find.text('Agar pengingat selalu bunyi'), findsNothing);
  }, skip: Platform.isAndroid);
}
