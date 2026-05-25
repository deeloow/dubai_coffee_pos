import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/remote_assignment_service.dart';
import '../../services/sync_service.dart';
import '../local_socket/cashier_socket_screen.dart';
import '../local_socket/kitchen_socket_screen.dart';
import '../menu/menu_screen.dart';
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
                              ? AppColors.goldDark.withAlpha((0.15 * 255).round())
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

          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppText('Local Network Order Sync',
                    size: 13, weight: FontWeight.w600),
                const SizedBox(height: 12),
                const AppText(
                  'Use Wi-Fi hotspot or local network socket communication to send orders from cashier to kitchen.',
                  size: 12,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CashierSocketScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.router_outlined),
                  label: const Text('Open Cashier Server'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const KitchenSocketScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.kitchen_outlined),
                  label: const Text('Open Kitchen Client'),
                ),
                if (user?.role == UserRole.admin) ...[
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
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (user?.role == UserRole.barista)
            FutureBuilder<Assignment?>(
              future: AssignmentService().getTodayLoginAssignmentForUser(user!.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox();
                }
                final assignment = snapshot.data;
                if (assignment == null) {
                  return const SectionCard(
                    child: AppText(
                      'No login record found for today. Open the app and sign in to sync your status.',
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                  );
                }
                return SectionCard(
                  child: Row(
                    children: [
                      Icon(
                        assignment.synced ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                        color: assignment.synced ? AppColors.green : AppColors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppText(
                          assignment.synced
                              ? 'Your login has synced to the admin view.'
                              : 'Your login is pending upload. Open the app online to sync.',
                          size: 13,
                          color: assignment.synced ? AppColors.espresso : AppColors.red,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 16),

          if (user?.role == UserRole.admin)
            AssignmentPanel(user: user!),

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
                side: const BorderSide(
                    color: Color(0xFFF09595), width: 0.5),
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

class AssignmentPanel extends StatefulWidget {
  final AppUser user;

  const AssignmentPanel({super.key, required this.user});

  @override
  State<AssignmentPanel> createState() => _AssignmentPanelState();
}

class _AssignmentPanelState extends State<AssignmentPanel> {
  final AssignmentService _assignmentService = AssignmentService();
  final AuthService _authService = AuthService();
  final RemoteAssignmentService _remoteAssignmentService = RemoteAssignmentService();
  final SyncService _syncService = SyncService();
  final TextEditingController _syncController = TextEditingController();
  String _syncStatus = '';
  late Future<List<AppUser>> _baristasFuture;
  late Stream<List<Assignment>> _assignmentsStream;

  @override
  void initState() {
    super.initState();
    _baristasFuture = _authService.getUsersByRole(UserRole.barista);
    _assignmentsStream = _assignmentService.assignmentsStream();
  }

  @override
  void dispose() {
    _syncController.dispose();
    super.dispose();
  }

  Future<void> _syncOnline() async {
    try {
      final today = DateTime.now();
      final remoteAssignments = await _remoteAssignmentService.fetchAssignmentsForDate(today);
      final updated = await _assignmentService.mergeRemoteAssignments(remoteAssignments);

      final localAssignments = await _assignmentService.getAssignmentsForDate(today);
      for (final assignment in localAssignments) {
        await _assignmentService.syncAssignmentRemotely(assignment);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Online sync completed. $updated remote record(s) merged locally.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Online sync failed: ${error.toString()}')),
      );
    }
  }

  Future<void> _showSyncDialog() async {
    _syncController.clear();
    _syncStatus = '';

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Sync Assignments'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'You can export today\'s assignments as JSON and paste them on another device.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _syncController,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: 'Paste assignment JSON here',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_syncStatus.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_syncStatus,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 13)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                final exportJson = _syncService.exportAssignmentsForDate(DateTime.now());
                await Clipboard.setData(ClipboardData(text: exportJson));
                setState(() {
                  _syncStatus = 'Today\'s assignments copied to clipboard.';
                });
              },
              child: const Text('Export Today'),
            ),
            ElevatedButton(
              onPressed: () async {
                final payload = _syncController.text.trim();
                if (payload.isEmpty) {
                  setState(() {
                    _syncStatus = 'Paste valid assignment JSON before importing.';
                  });
                  return;
                }

                try {
                  final count = await _syncService.importAssignments(payload);
                  setState(() {
                    _syncStatus = 'Imported $count assignment(s) successfully.';
                  });
                } catch (error) {
                  setState(() {
                    _syncStatus = 'Import failed: ${error.toString()}';
                  });
                }
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssignDialog() async {
    final baristas = await _baristasFuture;
    if (!mounted || baristas.isEmpty) return;

    String selectedBaristaId = baristas.first.id;
    String shift = 'Morning';

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assign Barista'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedBaristaId,
                items: baristas
                    .map((barista) => DropdownMenuItem(
                          value: barista.id,
                          child: Text(barista.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => selectedBaristaId = value);
                },
                decoration: const InputDecoration(labelText: 'Barista'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: shift,
                items: const [
                  DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                  DropdownMenuItem(value: 'Afternoon', child: Text('Afternoon')),
                  DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => shift = value);
                },
                decoration: const InputDecoration(labelText: 'Shift'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final selected = baristas.firstWhere((b) => b.id == selectedBaristaId);
              await _assignmentService.addAssignment(
                baristaId: selected.id,
                baristaName: selected.name,
                assignedBy: widget.user.name,
                shift: shift,
              );
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppText('Today’s Assignments', size: 13, weight: FontWeight.w600),
              Row(
                children: [
                  TextButton(
                    onPressed: _syncOnline,
                    child: const Text('Online Sync'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _showSyncDialog,
                    child: const Text('Manual Sync'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _showAssignDialog,
                    child: const Text('Add Assignment'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Assignment>>(
            stream: _assignmentsStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final assignments = snapshot.data!
                .where((assignment) => assignment.date.day == DateTime.now().day && assignment.date.month == DateTime.now().month && assignment.date.year == DateTime.now().year)
                .toList();
              if (assignments.isEmpty) {
                return const AppText('No assignments recorded for today.', size: 12, color: AppColors.textMuted);
              }
              return Column(
                children: assignments.map((assignment) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(assignment.baristaName, size: 13, weight: FontWeight.w600),
                        const SizedBox(height: 4),
                        AppText(
                          assignment.type == 'login'
                              ? 'Signed in today'
                              : 'Shift: ${assignment.shift}',
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 4),
                        AppText(
                          assignment.type == 'login'
                              ? 'Recorded from barista login'
                              : 'Assigned by: ${assignment.assignedBy}',
                          size: 11,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              assignment.synced ? Icons.cloud_done : Icons.cloud_off,
                              size: 14,
                              color: assignment.synced ? AppColors.green : AppColors.red,
                            ),
                            const SizedBox(width: 6),
                            AppText(
                              assignment.synced ? 'Synced' : 'Pending sync',
                              size: 11,
                              color: assignment.synced ? AppColors.green : AppColors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
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
