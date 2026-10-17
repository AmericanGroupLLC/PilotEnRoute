import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'learn_screen.dart';
import 'logbook_screen.dart';
import 'plan_screen.dart';
import 'practice_screen.dart';

/// Five tabs: Home · Learn · Practice · Plan · Logbook. The Go Card and
/// Weather open from Plan (and the Go Card from Home); Settings sits behind
/// the gear on Home. One rounded navigation bar on every platform, with a
/// teal pill behind the selected destination.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.clock});

  final DateTime Function()? clock;

  static const tabLabels = ['Home', 'Learn', 'Practice', 'Plan', 'Logbook'];
  static const homeTab = 0, learnTab = 1, practiceTab = 2, planTab = 3,
      logbookTab = 4;

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _index = 0;

  int get index => _index;

  void select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(clock: widget.clock),
      const LearnScreen(),
      const PracticeScreen(),
      const PlanScreen(),
      LogbookScreen(clock: widget.clock),
    ];
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: select,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: 'Learn',
            ),
            NavigationDestination(
              icon: Icon(Icons.play_circle_outline),
              selectedIcon: Icon(Icons.play_circle_fill),
              label: 'Practice',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Plan',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Logbook',
            ),
          ],
        ),
      ),
    );
  }
}
