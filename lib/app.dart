import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'features/board/board_screen.dart';
import 'features/card/card_detail_screen.dart';
import 'features/boards/boards_screen.dart';

GoRouter buildRouter() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const BoardsScreen()),
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

class NudgeApp extends StatefulWidget {
  const NudgeApp({super.key});

  @override
  State<NudgeApp> createState() => _NudgeAppState();
}

class _NudgeAppState extends State<NudgeApp> {
  // Owned by the state so each app instance (and each test) gets its own.
  late final GoRouter _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Nudge',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
