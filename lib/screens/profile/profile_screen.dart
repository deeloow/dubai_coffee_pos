import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/auth_provider.dart';
import '../menu/menu_screen.dart';
import '../local_socket/cashier_socket_screen.dart';
import '../local_socket/kitchen_socket_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar card
          SectionCard(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.espresso,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      user?.name.isNotEmpty == true
                          ? user!.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 24,
                        color: AppColors.goldLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(user?.name ?? '—',
                          size: 16, weight: FontWeight.w600),
                      const SizedBox(height: 2),
                      AppText(user?.email ?? '—',
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: user?.role == UserRole.admin
                              ? AppColors.goldDark
                                  .withAlpha((0.15 * 255).round())
                              : AppColors.bgLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: AppText(
                          user?.role == UserRole.admin ? 'Admin' : 'Barista',
                          size: 10,
                          weight: FontWeight.w600,
                          color: user?.role == UserRole.admin
                              ? AppColors.goldDark
                              : AppColors.brown2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Permissions
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText('Permissions', size: 13, weight: FontWeight.w600),
                const SizedBox(height: 12),
                const _PermRow(
                  icon: Icons.shopping_cart_outlined,
                  label: 'Process Orders',
                  allowed: true,
                ),
                const _PermRow(
                  icon: Icons.history,
                  label: 'View Order History',
                  allowed: true,
                ),
                const _PermRow(
                  icon: Icons.kitchen_outlined,
                  label: 'Kitchen Display',
                  allowed: true,
                ),
                _PermRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Inventory Management',
                  allowed: user?.role == UserRole.admin,
                ),
                _PermRow(
                  icon: Icons.bar_chart,
                  label: 'Sales Reports',
                  allowed: user?.role == UserRole.admin,
                ),
                _PermRow(
                  icon: Icons.people_outline,
                  label: 'User Management',
                  allowed: user?.role == UserRole.admin,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (user?.role == UserRole.admin)
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppText('Admin Actions',
                      size: 13, weight: FontWeight.w600),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MenuScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Manage Menu'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CashierSocketScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('Open Cashier Hotspot Server'),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Local socket for kitchen (available to all roles)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppText('Local Socket',
                    size: 13, weight: FontWeight.w600),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const KitchenSocketScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.router),
                  label: const Text('Open Kitchen Receiver'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          const SizedBox(height: 16),

          // App info
          const SectionCard(
            child: Column(
              children: [
                _InfoRow(label: 'App Version', value: '1.0.0'),
                _InfoRow(label: 'Build', value: 'Dubai Coffee POS'),
                _InfoRow(label: 'Session', value: 'Active'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Sign out
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFCEBEB),
                foregroundColor: AppColors.red,
                side: const BorderSide(color: Color(0xFFF09595), width: 0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Sign Out?'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign Out',
                            style: TextStyle(color: AppColors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await context.read<AuthProvider>().signOut();
                }
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool allowed;

  const _PermRow({
    required this.icon,
    required this.label,
    required this.allowed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: allowed ? AppColors.espresso : AppColors.borderColor),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(label,
                size: 13,
                color: allowed ? AppColors.espresso : AppColors.textMuted),
          ),
          Icon(
            allowed ? Icons.check_circle : Icons.cancel_outlined,
            size: 16,
            color: allowed ? AppColors.green : AppColors.borderColor,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppText(label, size: 12, color: AppColors.textMuted),
          AppText(value, size: 12, weight: FontWeight.w500),
        ],
      ),
    );
  }
}
