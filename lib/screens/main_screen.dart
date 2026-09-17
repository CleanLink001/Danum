import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../widgets/loading_screen.dart';
import 'dashboard_screen.dart';
import 'monitoring_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isNavigating = false;
  String _navMessage = 'Loading Section...';

  final List<Widget> _pages = [
    const DashboardScreen(),
    const MonitoringScreen(),
    const ReportsScreen(),
    const ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    final tabNames = ['Dashboard', 'Real-Time Monitor', 'Reports & Audit Logs', 'User Profile'];
    setState(() {
      _isNavigating = true;
      _navMessage = 'Loading ${tabNames[index]}...';
      _currentIndex = index;
    });

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          if (_isNavigating)
            AnimatedOpacity(
              opacity: _isNavigating ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: DanumLoadingScreen(
                message: _navMessage,
                fullScreen: true,
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildModernNavbar(context, settings),
    );
  }

  Widget _buildModernNavbar(BuildContext context, SettingsService settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBgColor = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95);
    final activeColor = const Color(0xFF818CF8);
    final inactiveColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      height: 68,
      decoration: BoxDecoration(
        color: navBgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.dashboard_rounded, settings.translate('nav_dashboard'), activeColor, inactiveColor),
            _buildNavItem(1, Icons.analytics_rounded, settings.translate('nav_monitor'), activeColor, inactiveColor),
            _buildNavItem(2, Icons.bar_chart_rounded, settings.translate('nav_reports'), activeColor, inactiveColor),
            _buildNavItem(3, Icons.person_rounded, settings.translate('nav_profile'), activeColor, inactiveColor),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, Color activeColor, Color inactiveColor) {
    bool isActive = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: isActive ? activeColor : inactiveColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: isActive ? activeColor : inactiveColor,
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
