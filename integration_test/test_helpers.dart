import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nudge/app.dart';
import 'package:nudge/core/auth/auth_backend.dart';
import 'package:nudge/core/auth/auth_providers.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/sync/fake_remote.dart';
import 'package:nudge/core/sync/sync_providers.dart';
import 'package:nudge/core/db/providers.dart';
import 'package:nudge/core/nag/local_notifications_gateway.dart';
import 'package:nudge/core/nag/providers.dart';
import 'package:nudge/core/settings/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the app with a fresh in-memory DB and an in-memory notification
/// gateway (so tests can assert what would have been scheduled).
Future<AppDatabase> pumpNudge(
  WidgetTester tester, {
  InMemoryNotificationGateway? gateway,
  Map<String, Object>? prefsValues,
  bool startOnBoards = true,
  FakeAuthBackend? auth,
  FakeRemote? remote,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  SharedPreferences.setMockInitialValues(prefsValues ?? {});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authBackendProvider.overrideWithValue(auth),
        remoteProvider.overrideWithValue(remote),
        appDatabaseProvider.overrideWithValue(db),
        notificationGatewayProvider
            .overrideWithValue(gateway ?? InMemoryNotificationGateway()),
      ],
      child: const NudgeApp(),
    ),
  );
  await tester.pumpAndSettle();
  if (startOnBoards && (auth == null || auth.userId != null)) {
    await tester.tap(find.byKey(const Key('nav-boards')));
    await tester.pumpAndSettle();
  }
  return db;
}
