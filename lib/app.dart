import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';

class NudgeApp extends StatelessWidget {
  const NudgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nudge',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Nudge')),
      body: Center(
        child: Text(
          'Belum ada board.',
          style: TextStyle(color: t.textSecondary),
        ),
      ),
    );
  }
}
