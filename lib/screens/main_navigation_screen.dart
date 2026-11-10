import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import 'home_screen.dart';
import 'explore_map_screen.dart';
import 'spot_ai_screen.dart';
import 'saved_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  bool _hasParentProviderScope(BuildContext context) {
    try {
      ProviderScope.containerOf(context, listen: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(onNavigateTab: _onTabSelected),
      ExploreMapScreen(onNavigateTab: _onTabSelected),
      const SpotAIScreen(),
      SavedScreen(onNavigateTab: _onTabSelected),
      const ProfileScreen(),
    ];

    final scaffold = Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: AppColors.cardBorder.withOpacity(0.6),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: _buildNavItem(
                    0,
                    Icons.home_rounded,
                    Icons.home_outlined,
                    'Beranda',
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    1,
                    Icons.explore_rounded,
                    Icons.explore_outlined,
                    'Jelajah',
                  ),
                ),
                Expanded(child: _buildCenterAiNavItem(2)),
                Expanded(
                  child: _buildNavItem(
                    3,
                    Icons.bookmark_rounded,
                    Icons.bookmark_border_rounded,
                    'Tersimpan',
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    4,
                    Icons.person_rounded,
                    Icons.person_outline_rounded,
                    'Profil',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (_hasParentProviderScope(context)) {
      return scaffold;
    }
    return ProviderScope(child: scaffold);
  }

  // Standard Nav Item
  Widget _buildNavItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? AppColors.primaryTeal : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.primaryTeal : AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Elevated Highlighted Center AI Nav Item
  Widget _buildCenterAiNavItem(int index) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSelected
                    ? [AppColors.terracottaBrown, AppColors.terracottaDark]
                    : [AppColors.primaryTeal, AppColors.primaryTealDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      (isSelected
                              ? AppColors.terracottaBrown
                              : AppColors.primaryTeal)
                          .withOpacity(0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'SpotAI',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isSelected
                  ? AppColors.terracottaBrown
                  : AppColors.primaryTeal,
            ),
          ),
        ],
      ),
    );
  }
}
