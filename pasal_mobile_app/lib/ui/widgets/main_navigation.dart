import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_colors.dart';
import 'settings_drawer.dart';
import 'expiry_warning_banner.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/archive_screen.dart';
import '../utils/responsive_layout.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  final Set<int> _visitedPages = {0};
  final List<Widget> _pages = const [
    HomeScreen(),
    LibraryScreen(),
    ArchiveScreen(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedIndex = index;
      _visitedPages.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < ResponsiveLayout.medium;
    final expanded = width >= ResponsiveLayout.expanded;

    return Scaffold(
      endDrawer: const SettingsDrawer(),
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: compact ? 0 : (expanded ? 216 : 88),
              child: compact
                  ? const SizedBox.shrink()
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: AppColors.border(isDark)),
                        ),
                      ),
                      child: NavigationRail(
                        extended: expanded,
                        minWidth: 88,
                        minExtendedWidth: 216,
                        backgroundColor: AppColors.scaffold(isDark),
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: _onItemTapped,
                        labelType: expanded
                            ? NavigationRailLabelType.none
                            : NavigationRailLabelType.all,
                        leading: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: expanded
                              ? const Text(
                                  'CariPasal',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : const Icon(Icons.balance_rounded, size: 30),
                        ),
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home_rounded),
                            label: Text('Beranda'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.auto_stories_outlined),
                            selectedIcon: Icon(Icons.auto_stories_rounded),
                            label: Text('Pustaka'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.bookmark_outline_rounded),
                            selectedIcon: Icon(Icons.bookmark_rounded),
                            label: Text('Tersimpan'),
                          ),
                        ],
                        trailing: Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Builder(
                            builder: (context) => IconButton(
                              tooltip: 'Pengaturan',
                              onPressed: () =>
                                  Scaffold.of(context).openEndDrawer(),
                              icon: const Icon(Icons.settings_outlined),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            // Keep this subtree in the same slot at every breakpoint.
            Expanded(
              child: Column(
                children: [
                  const ExpiryWarningBanner(),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        for (var i = 0; i < _pages.length; i++)
                          TickerMode(
                            enabled: i == _selectedIndex,
                            child: _visitedPages.contains(i)
                                ? _pages[i]
                                : const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: compact
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Beranda',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  selectedIcon: Icon(Icons.auto_stories_rounded),
                  label: 'Pustaka',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bookmark_outline_rounded),
                  selectedIcon: Icon(Icons.bookmark_rounded),
                  label: 'Tersimpan',
                ),
              ],
            )
          : null,
    );
  }
}
