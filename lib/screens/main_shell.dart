import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/inventory_service.dart';
import '../services/local_order_socket_provider.dart';
import '../theme/app_theme.dart';
import '../core/responsive.dart';
import '../widgets/shared_widgets.dart';
import 'pos/pos_screen.dart';
import 'history/history_screen.dart';
import 'kitchen/kitchen_screen.dart';
import 'reports/reports_screen.dart';
import 'inventory/inventory_screen.dart';
import 'profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  List<_NavItem> _buildNavItems(bool isAdmin) {
    final items = <_NavItem>[
      _NavItem(
        icon: Icons.point_of_sale_outlined,
        activeIcon: Icons.point_of_sale,
        label: 'Cashier',
        screen: const PosScreen(),
      ),
      _NavItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long,
        label: 'History',
        screen: const HistoryScreen(),
      ),
      _NavItem(
        icon: Icons.restaurant_menu_outlined,
        activeIcon: Icons.restaurant_menu,
        label: 'Kitchen',
        screen: const KitchenScreen(),
      ),
      if (isAdmin)
        _NavItem(
          icon: Icons.inventory_2_outlined,
          activeIcon: Icons.inventory_2,
          label: 'Inventory',
          screen: const InventoryScreen(),
        ),
      if (isAdmin)
        _NavItem(
          icon: Icons.bar_chart_outlined,
          activeIcon: Icons.bar_chart,
          label: 'Reports',
          screen: const ReportsScreen(),
        ),
      _NavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Profile',
        screen: const ProfileScreen(),
      ),
    ];
    return items;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Seed inventory for admin only
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isAdmin = context.read<AuthProvider>().isAdmin;
      if (isAdmin) {
        await InventoryService().seedInventoryIfEmpty();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final socketProvider = context.read<LocalOrderSocketProvider>();
      socketProvider.resumeConnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final navItems = _buildNavItems(isAdmin);
    final socketProvider = context.watch<LocalOrderSocketProvider>();

    // Clamp index in case admin status changes
    final safeIndex = _currentIndex.clamp(0, navItems.length - 1);

    final responsive = ResponsiveLayout.of(context);
    final showReconnectBanner = socketProvider.shouldAutoReconnect && !socketProvider.isConnected;

    return Scaffold(
      body: Column(
        children: [
          if (showReconnectBanner)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: socketProvider.status == 'reconnecting'
                  ? const Color(0xFFFFF4E5)
                  : const Color(0xFFE8F5E9),
              child: Row(
                children: [
                  if (socketProvider.status == 'reconnecting')
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(Icons.link, size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      socketProvider.status == 'reconnecting'
                          ? 'Reconnecting to the socket server…'
                          : 'Auto-reconnect is enabled',
                      style: TextStyle(
                        fontSize: 12,
                        color: socketProvider.status == 'reconnecting'
                            ? Colors.orange.shade800
                            : Colors.green.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: safeIndex,
              children: navItems.map((n) => n.screen).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.espresso,
          border: Border(top: BorderSide(color: Color(0xFF3D2614), width: 0.5)),
        ),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: responsive.isTablet ? 74 : (responsive.isCompactPhone ? 56 : 60),
              maxHeight: responsive.isTablet ? 96 : (responsive.isCompactPhone ? 72 : 84),
            ),
            child: SizedBox(
              height: responsive.isTablet ? 74 : (responsive.isCompactPhone ? 56 : 60),
              child: Row(
                children: List.generate(navItems.length, (i) {
                  final item = navItems[i];
                  final active = safeIndex == i;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _currentIndex = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            active ? item.activeIcon : item.icon,
                            size: responsive.isTablet ? 24 : (responsive.isCompactPhone ? 20 : 22),
                            color: active
                                ? AppColors.goldLight
                                : AppColors.textMuted,
                          ),
                          const SizedBox(height: 3),
                          AppText(
                            item.label,
                            size: responsive.isTablet ? 10 : (responsive.isCompactPhone ? 8.5 : 9),
                            weight:
                                active ? FontWeight.w600 : FontWeight.normal,
                            color: active
                                ? AppColors.goldLight
                                : AppColors.textMuted,
                          ),
                          if (active)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 16,
                              height: 2,
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget screen;

  _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.screen,
  });
}
