import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'kit_screen.dart';
import 'logbook_screen.dart';
import 'today_screen.dart';
import 'weather_screen.dart';

/// Four tabs: Today (the Go Card) · Logbook · Weather · Kit. Settings sits
/// behind the gear on Today. iOS gets a Cupertino tab bar and glyphs; Android
/// gets a Material navigation bar.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.clock});

  final DateTime Function()? clock;

  static const tabLabels = ['Today', 'Logbook', 'Weather', 'Kit'];

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _index = 0;

  int get index => _index;

  void select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;
    final pages = [
      TodayScreen(clock: widget.clock),
      LogbookScreen(clock: widget.clock),
      const WeatherScreen(),
      const KitScreen(),
    ];
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: ios
          ? CupertinoTabBar(
              currentIndex: _index,
              onTap: select,
              activeColor: scheme.primary,
              inactiveColor: scheme.onSurfaceVariant,
              backgroundColor: scheme.surfaceContainerLow,
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.checkmark_seal), label: 'Today'),
                BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.book), label: 'Logbook'),
                BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.cloud_sun), label: 'Weather'),
                BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.wrench), label: 'Kit'),
              ],
            )
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: select,
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.fact_check_outlined),
                    selectedIcon: Icon(Icons.fact_check),
                    label: 'Today'),
                NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: 'Logbook'),
                NavigationDestination(
                    icon: Icon(Icons.cloud_outlined),
                    selectedIcon: Icon(Icons.cloud),
                    label: 'Weather'),
                NavigationDestination(
                    icon: Icon(Icons.handyman_outlined),
                    selectedIcon: Icon(Icons.handyman),
                    label: 'Kit'),
              ],
            ),
    );
  }
}
