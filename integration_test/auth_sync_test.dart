import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nudge/core/auth/auth_backend.dart';
import 'package:nudge/core/db/repository.dart';
import 'package:nudge/core/sync/fake_remote.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> type(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(Key(key)), text);
    await tester.pump();
  }

  group('login', () {
    testWidgets('configured but signed out: only the login screen',
        (tester) async {
      await pumpNudge(
        tester,
        auth: FakeAuthBackend(),
        remote: FakeRemote(),
        startOnBoards: false,
      );
      expect(find.byKey(const Key('auth-email')), findsOneWidget);
      expect(find.text('Hari ini'), findsNothing);
    });

    testWidgets('wrong password shows an error and stays on login',
        (tester) async {
      await pumpNudge(tester, auth: FakeAuthBackend(), remote: FakeRemote());
      await type(tester, 'auth-email', 'user@example.com');
      await type(tester, 'auth-password', 'salahbanget');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Email atau password salah.'), findsOneWidget);
      expect(find.byKey(const Key('auth-email')), findsOneWidget);
    });

    testWidgets('validation: bad email and short password', (tester) async {
      await pumpNudge(tester, auth: FakeAuthBackend(), remote: FakeRemote());
      await type(tester, 'auth-email', 'bukan-email');
      await type(tester, 'auth-password', 'secret123');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Masukkan alamat email yang valid.'), findsOneWidget);

      await type(tester, 'auth-email', 'a@b.co');
      await type(tester, 'auth-password', '123');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Password minimal 6 karakter.'), findsOneWidget);
    });

    testWidgets('correct credentials open the app', (tester) async {
      await pumpNudge(tester, auth: FakeAuthBackend(), remote: FakeRemote());
      await type(tester, 'auth-email', 'user@example.com');
      await type(tester, 'auth-password', 'secret123');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-email')), findsNothing);
      expect(find.text('Tidak ada yang mendesak hari ini.'), findsOneWidget);
    });

    testWidgets('sign up, confirmation required, magic link, reset',
        (tester) async {
      final auth = FakeAuthBackend(requireConfirmation: true);
      await pumpNudge(tester, auth: auth, remote: FakeRemote());

      await tester.tap(find.byKey(const Key('mode-signup')));
      await tester.pumpAndSettle();
      await type(tester, 'auth-email', 'baru@example.com');
      await type(tester, 'auth-password', 'password1');
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cek email kamu untuk konfirmasi'),
          findsOneWidget);
      expect(find.byKey(const Key('auth-email')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mode-login')));
      await tester.pumpAndSettle();
      // The logo makes the form taller than a phone screen: scroll to buttons.
      await tester.ensureVisible(find.byKey(const Key('auth-magic')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('auth-magic')));
      await tester.pumpAndSettle();
      expect(auth.magicLinks, ['baru@example.com']);
      expect(find.textContaining('Tautan masuk dikirim'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('auth-forgot')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('auth-forgot')));
      await tester.pumpAndSettle();
      expect(auth.resets, ['baru@example.com']);
    });
  });

  group('sync wiring', () {
    testWidgets('signed in: local edits reach the server automatically',
        (tester) async {
      final remote = FakeRemote();
      final db = await pumpNudge(
        tester,
        auth: FakeAuthBackend(userId: 'user-1'),
        remote: remote,
      );
      await Repository(db).createBoard('Dari HP');
      await tester.pump(const Duration(seconds: 3)); // debounce
      await tester.pumpAndSettle();
      expect(remote.tables['boards'], isNotNull);
      expect(remote.tables['boards']!.values.single['title'], 'Dari HP');
    });

    testWidgets('a change made on another device appears in the app',
        (tester) async {
      final remote = FakeRemote();
      await pumpNudge(
        tester,
        auth: FakeAuthBackend(userId: 'user-1'),
        remote: remote,
        startOnBoards: false,
      );
      final now = DateTime.now().toUtc().toIso8601String();
      remote.serverWrite('boards', {
        'id': '00000000-0000-4000-8000-000000000001',
        'user_id': 'user-1',
        'title': 'Dari desktop',
        'color': 4282400731,
        'position': 1024,
        'created_at': now,
        'updated_at': now,
      });
      await tester.pump(const Duration(seconds: 1)); // realtime debounce
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav-boards')));
      await tester.pumpAndSettle();
      expect(find.text('Dari desktop'), findsOneWidget);
    });

    testWidgets('settings shows sync status and signs out wiping local data',
        (tester) async {
      final remote = FakeRemote();
      final auth = FakeAuthBackend(userId: 'user-1');
      final db = await pumpNudge(tester, auth: auth, remote: remote);
      final repo = Repository(db);
      await repo.createBoard('Rahasia');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav-today')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sync-status')), findsOneWidget);
      expect(find.text('Tersinkron'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sign-out')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-dialog')));
      await tester.pumpAndSettle();

      // Back at login, local data wiped, server copy intact.
      expect(find.byKey(const Key('auth-email')), findsOneWidget);
      expect(await db.select(db.boards).get(), isEmpty);
      expect(remote.tables['boards']!.values.single['title'], 'Rahasia');
    });

    testWidgets('offline sync shows a calm message and keeps local data',
        (tester) async {
      final remote = FakeRemote()..offline = true;
      final db = await pumpNudge(
        tester,
        auth: FakeAuthBackend(userId: 'user-1'),
        remote: remote,
      );
      await Repository(db).createBoard('Offline dulu');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav-today')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
      expect(find.textContaining('akan dikirim saat online'), findsOneWidget);

      remote.offline = false;
      await tester.tap(find.byKey(const Key('sync-now')));
      await tester.pumpAndSettle();
      expect(find.text('Tersinkron'), findsOneWidget);
      expect(remote.tables['boards']!.values.single['title'], 'Offline dulu');
    });
  });

  group('local-only mode', () {
    testWidgets('without Supabase there is no login and settings says so',
        (tester) async {
      await pumpNudge(tester, startOnBoards: false);
      expect(find.byKey(const Key('auth-email')), findsNothing);
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('local-mode')), findsOneWidget);
      expect(find.byKey(const Key('sign-out')), findsNothing);
    });

    testWidgets('theme choice is saved', (tester) async {
      await pumpNudge(tester, startOnBoards: false);
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      // Settings is a lazy ListView: the theme control may not be built yet.
      await tester.scrollUntilVisible(
        find.byKey(const Key('theme-dark')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('theme-dark')));
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });
  });
}
