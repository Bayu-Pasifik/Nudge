import 'package:material_ui/material_ui.dart';

import '../boards/boards_screen.dart';
import '../today/today_screen.dart';

/// Top-level navigation: Hari ini / Board. Bottom bar on phones, side rail on
/// wide screens.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [TodayScreen(), BoardsScreen()];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final body = IndexedStack(index: _index, children: _pages);
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => setState(() => _index = i),
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
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
        ],
      ),
    );
  }
}
