import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/auth_provider.dart';
import '../../services/order_service.dart';
import '../../services/local_order_socket_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../../core/responsive.dart';
import 'package:intl/intl.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  final OrderService _orderSvc = OrderService();

  // Local done-state per order item (orderId -> itemIndex -> done)
  final Map<String, Map<int, bool>> _doneState = {};

  bool _allDone(String orderId, int itemCount) {
    final m = _doneState[orderId] ?? {};
    return itemCount > 0 &&
        List.generate(itemCount, (i) => m[i] == true).every((v) => v);
  }

  void _toggle(String orderId, int idx) {
    setState(() {
      _doneState[orderId] ??= {};
      _doneState[orderId]![idx] = !(_doneState[orderId]![idx] ?? false);
    });
  }

  Future<void> _completeOrder(BuildContext context, Order order) async {
    if (!_allDone(order.id, order.items.length)) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final currentBarista = (auth.user?.name ?? '').trim();
    final alreadyAssigned = order.preparedBy.trim().isNotEmpty;
    if (alreadyAssigned && order.preparedBy != currentBarista) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order already prepared by ${order.preparedBy}.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
      return;
    }

    final socketProvider =
        Provider.of<LocalOrderSocketProvider>(context, listen: false);
    final preparedBy = currentBarista.isNotEmpty
        ? currentBarista
        : (order.preparedBy.isNotEmpty ? order.preparedBy : 'Unknown');
    final updatedOrder = order.copyWith(
      kitchenCompleted: true,
      status: OrderStatus.completed,
      preparedBy: preparedBy,
    );

    try {
      // ALWAYS save to local OrderService first (for UI update on this device)
      await _orderSvc.saveOrder(updatedOrder, deductInventory: false);
      
      // If connected to Admin, send the completed order so Admin can:
      // 1. Deduct inventory with correct cup size from OrderItem
      // 2. Broadcast order to ALL connected Baristas for queue sync
      if (socketProvider.isConnected) {
        await socketProvider.sendOrder(updatedOrder);
      }
    } catch (_) {
      // Ignore save failures here; order remains in kitchen view.
    }

    setState(() {
      _doneState.remove(order.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1008),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1008),
        title: const Row(
          children: [
            Text('🍳 ', style: TextStyle(fontSize: 18)),
            Text('Kitchen Display'),
          ],
        ),
        actions: [
          StreamBuilder<DateTime>(
            stream: Stream.periodic(
                const Duration(seconds: 1), (_) => DateTime.now()),
            builder: (_, snap) {
              final t = snap.data ?? DateTime.now();
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                child: Center(
                  child: AppText(DateFormat('hh:mm:ss a').format(t),
                      size: 12, color: AppColors.textMuted),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<LocalOrderSocketProvider>(
        builder: (context, socketProvider, child) {
          final resetAt = socketProvider.pendingReportResetAt;
          return Column(
            children: [
              if (resetAt != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Material(
                    color: AppColors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.warning_amber_rounded, color: AppColors.red),
                      title: Text(
                        'Daily report was reset remotely at ${DateFormat('h:mm a').format(resetAt)}.',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      subtitle: const Text('Orders for the new reporting day are now active.'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted),
                        onPressed: socketProvider.acknowledgeReportReset,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: StreamBuilder<List<Order>>(
                  stream: _orderSvc.ordersStream(includeArchived: false),
                  initialData: const [],
                  builder: (ctx, snap) {
                    if (snap.hasError) {
                      return const Center(
                        child: Text('Unable to load kitchen orders.'),
                      );
                    }

                    // Show only paid orders (not voided)
                    final orders = snap.data!
                        .where((o) => o.status == OrderStatus.paid)
                        .take(12)
                        .toList();

                    // Filter: show orders until they are explicitly bumped / completed in kitchen
                    final activeOrders =
                        orders.where((o) => !o.kitchenCompleted).toList();

                    if (activeOrders.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('👨‍🍳', style: TextStyle(fontSize: 48)),
                            SizedBox(height: 12),
                            AppText('No active orders',
                                size: 14, color: AppColors.textMuted),
                          ],
                        ),
                      );
                    }

                    final responsive = ResponsiveLayout.of(context);
                    final landscape = responsive.isLandscape;
                    final columns = responsive.isTablet
                        ? (landscape ? 4 : 2)
                        : (landscape ? 2 : 1);
                    final spacing = landscape ? 8.0 : 10.0;
                    final padding = landscape ? 8.0 : 12.0;

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final contentWidth = constraints.maxWidth - (padding * 2);
                        final cardWidth = landscape
                            ? (contentWidth - (spacing * (columns - 1))) / columns
                            : contentWidth;

                        return SingleChildScrollView(
                          padding: EdgeInsets.all(padding),
                          child: Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: List.generate(activeOrders.length, (i) {
                              final order = activeOrders[i];
                              return SizedBox(
                                width: cardWidth,
                                child: _KdsCard(
                                  order: order,
                                  doneMap: _doneState[order.id] ?? {},
                                  onToggle: (idx) => _toggle(order.id, idx),
                                  allDone: _allDone(order.id, order.items.length),
                                  onBump: () => _completeOrder(context, order),
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class KitchenOrderNotesBlock extends StatelessWidget {
  final String orderNotes;
  final bool compact;

  const KitchenOrderNotesBlock({super.key, required this.orderNotes, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final trimmedNotes = orderNotes.trim();
    if (trimmedNotes.isEmpty) {
      return const SizedBox.shrink();
    }

    final notes = trimmedNotes
        .split(RegExp(r'\r?\n'))
        .map((note) => note.trim())
        .where((note) => note.isNotEmpty)
        .toList();

    if (notes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 8, vertical: compact ? 3 : 6),
      decoration: BoxDecoration(
        color: const Color(0xFF4A2A13),
        borderRadius: BorderRadius.circular(compact ? 7 : 8),
        border: Border.all(color: const Color(0xFF6F4420)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            'Additional Notes',
            size: compact ? 9 : 10,
            weight: FontWeight.w700,
            color: const Color(0xFFF3D6A7),
          ),
          SizedBox(height: compact ? 1 : 3),
          ...notes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                note,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 9 : 10.5,
                  color: const Color(0xFFF8E8CB),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KdsCard extends StatelessWidget {
  final Order order;
  final Map<int, bool> doneMap;
  final void Function(int) onToggle;
  final bool allDone;
  final VoidCallback onBump;

  const _KdsCard({
    required this.order,
    required this.doneMap,
    required this.onToggle,
    required this.allDone,
    required this.onBump,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final compactLandscape = responsive.isLandscape;
    final maxListHeight = compactLandscape ? 150.0 : 220.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C1A0E),
        borderRadius: BorderRadius.circular(compactLandscape ? 8 : 10),
        border: Border.all(
            color: allDone ? AppColors.green : const Color(0xFF5C3317),
            width: allDone ? 1.5 : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: compactLandscape ? 5 : 10, vertical: compactLandscape ? 3 : 8),
            decoration: const BoxDecoration(
              color: Color(0xFF3D2614),
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: compactLandscape
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              'Order #${order.orderNumber.toString().padLeft(3, '0')}',
                              size: 10,
                              weight: FontWeight.w700,
                              color: AppColors.goldLight,
                            ),
                            if (order.orderNotes.trim().isNotEmpty) ...[
                              const SizedBox(height: 1),
                              KitchenOrderNotesBlock(
                                orderNotes: order.orderNotes,
                                compact: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.espresso,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline, size: 10, color: AppColors.textMuted),
                                const SizedBox(width: 3),
                                AppText(order.customerName, size: 9, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          AppText(DateFormat('h:mm a').format(order.createdAt), size: 9, color: AppColors.textMuted),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            'Order #${order.orderNumber.toString().padLeft(3, '0')}',
                            size: 13,
                            weight: FontWeight.w700,
                            color: AppColors.goldLight,
                          ),
                          SizedBox(width: compactLandscape ? 6 : 8),
                          if (order.orderNotes.trim().isNotEmpty)
                            Expanded(
                              child: KitchenOrderNotesBlock(
                                orderNotes: order.orderNotes,
                                compact: compactLandscape,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: compactLandscape ? 2 : 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: compactLandscape ? 6 : 7, vertical: compactLandscape ? 2 : 3),
                            decoration: BoxDecoration(
                              color: AppColors.espresso,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.person_outline, size: compactLandscape ? 10 : 11, color: AppColors.textMuted),
                                SizedBox(width: compactLandscape ? 3 : 4),
                                AppText(order.customerName, size: compactLandscape ? 9 : 10, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                          SizedBox(width: compactLandscape ? 6 : 8),
                          AppText(DateFormat('h:mm a').format(order.createdAt), size: compactLandscape ? 10 : 11, color: AppColors.textMuted),
                        ],
                      ),
                    ],
                  ),
          ),

          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(compactLandscape ? 5 : 10, compactLandscape ? 3 : 6, compactLandscape ? 5 : 10, compactLandscape ? 3 : 6),
              child: Column(
                children: List.generate(order.items.length, (i) {
                  final done = doneMap[i] ?? false;
                  return GestureDetector(
                    onTap: () => onToggle(i),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: compactLandscape ? 2 : 5, horizontal: compactLandscape ? 2 : 4),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: i < order.items.length - 1 ? const Color(0xFF3D2614) : Colors.transparent,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          AppText('${order.items[i].qty}×', size: compactLandscape ? 12 : 14, weight: FontWeight.w700, color: AppColors.goldLight),
                          SizedBox(width: compactLandscape ? 6 : 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${order.items[i].name} (${order.items[i].cupSize})',
                                  style: TextStyle(
                                    fontSize: compactLandscape ? 11.5 : 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: done ? const Color(0xFF5C3314) : const Color(0xFFD4B88A),
                                    decoration: done ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                SizedBox(height: compactLandscape ? 0 : 1),
                                Text(
                                  order.items[i].cupSize.toLowerCase().contains('regular') || order.items[i].cupSize.toLowerCase().contains('medium')
                                      ? '${order.orderTypeLabel} • Qty ${order.items[i].qty}'
                                      : '${order.orderTypeLabel} • Qty ${order.items[i].qty} • ${order.items[i].sugarLevel}',
                                  style: TextStyle(fontSize: compactLandscape ? 10 : 11, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: compactLandscape ? 18 : 22,
                            height: compactLandscape ? 18 : 22,
                            decoration: BoxDecoration(
                              color: done ? AppColors.green : Colors.transparent,
                              border: Border.all(color: done ? AppColors.green : const Color(0xFF5C3317)),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: done ? Icon(Icons.check, size: compactLandscape ? 11 : 13, color: const Color(0xFFD0F0B0)) : null,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          GestureDetector(
            onTap: onBump,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: compactLandscape ? 4 : 8, horizontal: compactLandscape ? 5 : 10),
              decoration: BoxDecoration(
                color: allDone ? AppColors.green : const Color(0xFF5C3317),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    allDone ? Icons.check_circle_outline : Icons.done_all,
                    size: compactLandscape ? 13 : 15,
                    color: allDone ? const Color(0xFFD0F0B0) : AppColors.goldLight,
                  ),
                  SizedBox(width: compactLandscape ? 1 : 4),
                  AppText(
                    allDone ? '✓ Ready' : 'Done',
                    size: compactLandscape ? 10 : 12,
                    weight: FontWeight.w600,
                    color: allDone ? const Color(0xFFD0F0B0) : AppColors.goldLight,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
