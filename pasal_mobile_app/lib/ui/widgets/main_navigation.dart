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
  bool _sidebarExpanded = true;
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

  Widget _sidebar(bool isDark, bool expanded, bool canToggle) {
    const destinations = [
      (Icons.home_outlined, Icons.home_rounded, 'Beranda'),
      (Icons.auto_stories_outlined, Icons.auto_stories_rounded, 'Pustaka'),
      (Icons.bookmark_outline_rounded, Icons.bookmark_rounded, 'Tersimpan'),
    ];
    return Container(
      width: expanded ? 264 : 80,
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        border: Border(
          right: BorderSide(color: AppColors.border(isDark), width: 1.5),
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? 16 : 12,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (expanded)
                    Row(
                      children: [
                        const Icon(
                          Icons.balance_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'CariPasal',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tutup sidebar',
                          onPressed: () =>
                              setState(() => _sidebarExpanded = false),
                          icon: const Icon(Icons.chevron_left),
                        ),
                      ],
                    )
                  else ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Icon(
                        Icons.balance_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    if (canToggle)
                      IconButton(
                        tooltip: 'Buka sidebar',
                        onPressed: () =>
                            setState(() => _sidebarExpanded = true),
                        icon: const Icon(Icons.chevron_right),
                      ),
                  ],
                  const SizedBox(height: 28),
                  for (var i = 0; i < destinations.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Tooltip(
                        message: expanded ? '' : destinations[i].$3,
                        child: Material(
                          color: i == _selectedIndex
                              ? AppColors.primary.withValues(alpha: .10)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _onItemTapped(i),
                            child: Semantics(
                              button: true,
                              selected: i == _selectedIndex,
                              label: destinations[i].$3,
                              excludeSemantics: true,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  mainAxisAlignment: expanded
                                      ? MainAxisAlignment.start
                                      : MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      i == _selectedIndex
                                          ? destinations[i].$2
                                          : destinations[i].$1,
                                      size: 22,
                                      color: i == _selectedIndex
                                          ? AppColors.primary
                                          : AppColors.icon(isDark),
                                    ),
                                    if (expanded) ...[
                                      const SizedBox(width: 14),
                                      Text(
                                        destinations[i].$3,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: i == _selectedIndex
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  const SizedBox(height: 32),
                  Material(
                    type: MaterialType.transparency,
                    child: SettingsControls(sidebar: true, collapsed: !expanded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < ResponsiveLayout.medium;
    final expanded = width >= ResponsiveLayout.expanded;

    return NavigationSettingsScope(
      child: Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              SizedBox(
                width: compact ? 0 : (expanded && _sidebarExpanded ? 264 : 80),
                child: compact
                    ? const SizedBox.shrink()
                    : _sidebar(isDark, expanded && _sidebarExpanded, expanded),
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
      ),
    );
  }
}
