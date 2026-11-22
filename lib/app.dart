import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/auth/auth_providers.dart';
import 'core/nag/providers.dart';
import 'core/settings/theme_mode.dart';
import 'core/sync/sync_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/board/board_screen.dart';
import 'features/card/card_detail_screen.dart';
import 'features/home/home_shell.dart';
import 'features/settings/settings_screen.dart';

GoRouter buildRouter(ProviderContainer ref) => GoRouter(
      refreshListenable: ref.read(authRefreshProvider),
      redirect: (context, state) {
        final session = ref.read(authSessionProvider);
        final onAuth = state.matchedLocation == '/auth';
        // Supabase configured but nobody signed in: only the login screen.
        if (!session.canUseApp) return onAuth ? null : '/auth';
        if (session.signedIn && onAuth) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeShell()),
        GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(
          path: '/card/:id',
          builder: (_, state) =>
              CardDetailScreen(cardId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/board/:id',
          builder: (_, state) =>
              BoardScreen(boardId: state.pathParameters['id']!),
        ),
      ],
    );

class NudgeApp extends ConsumerStatefulWidget {
  const NudgeApp({super.key});

  @override
  ConsumerState<NudgeApp> createState() => _NudgeAppState();
}

class _NudgeAppState extends ConsumerState<NudgeApp> {
  // Owned by the state so each app instance (and each test) gets its own.
  late final GoRouter _router =
      buildRouter(ProviderScope.containerOf(context, listen: false));

  @override
  void initState() {
    super.initState();
    // Start keeping notifications in sync with the database.
    ref.read(nagCoordinatorProvider).start();
    // Sync with Supabase while signed in (no-op in local-only mode).
    ref.read(syncControllerProvider);
    // A notification tap that happened before the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPending());
  }

  void _openPending() {
    final id = ref.read(openCardProvider);
    if (id == null) return;
    ref.read(openCardProvider.notifier).clear();
    _router.push('/card/$id');
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(openCardProvider, (_, id) {
      if (id != null) _openPending();
    });
    return MaterialApp.router(
      title: 'Nudge',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router,
    );
  }
}
