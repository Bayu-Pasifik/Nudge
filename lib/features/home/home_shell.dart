import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

import '../boards/boards_screen.dart';
import '../search/search_screen.dart';
import '../today/today_screen.dart';

/// Top-level navigation: Hari ini / Board / Cari. Bottom bar on phones, side
/// rail on wide screens. Keyboard: Ctrl+1/2/3 switch tabs, Ctrl+K jumps to
/// search (Cmd instead of Ctrl on macOS).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _searchFocus = FocusNode(debugLabel: 'search');

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _go(int i) => setState(() => _index = i);

  void _search() {
    _go(2);
    // After the tab is shown, move the cursor into the search box.
    WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
        for (final meta in [false, true]) ...{
          SingleActivator(LogicalKeyboardKey.digit1, control: !meta, meta: meta): () => _go(0),
          SingleActivator(LogicalKeyboardKey.digit2, control: !meta, meta: meta): () => _go(1),
          SingleActivator(LogicalKeyboardKey.digit3, control: !meta, meta: meta): () => _go(2),
          SingleActivator(LogicalKeyboardKey.keyK, control: !meta, meta: meta): _search,
        },
      };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final body = IndexedStack(
      index: _index,
      children: [
        const TodayScreen(),
        const BoardsScreen(),
        SearchScreen(focusNode: _searchFocus),
      ],
    );

    final Widget shell;
    if (wide) {
      shell = Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: _go,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.today_outlined, key: Key('nav-today')),
                  selectedIcon: Icon(Icons.today),
                  label: Text('Hari ini'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined, key: Key('nav-boards')),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Board'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.search, key: Key('nav-search')),
                  selectedIcon: Icon(Icons.search),
                  label: Text('Cari'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    } else {
      shell = Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          destinations: const [
            NavigationDestination(
              key: Key('nav-today'),
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Hari ini',
            ),
            NavigationDestination(
              key: Key('nav-boards'),
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Board',
            ),
            NavigationDestination(
              key: Key('nav-search'),
              icon: Icon(Icons.search),
              label: 'Cari',
            ),
          ],
        ),
      );
    }

    // `autofocus` gives the shortcuts a focus target even when nothing else has
    // focus, so they work right after launch.
    return CallbackShortcuts(
      bindings: _shortcuts,
      child: Focus(autofocus: true, child: shell),
    );
  }
}
