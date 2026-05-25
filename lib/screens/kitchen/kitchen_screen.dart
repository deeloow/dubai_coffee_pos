import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/order_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
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
        List.generate(itemCount, (i) => m[i] == true)
            .every((v) => v);
  }

  void _toggle(String orderId, int idx) {
    setState(() {
      _doneState[orderId] ??= {};
      _doneState[orderId]![idx] =
          !(_doneState[orderId]![idx] ?? false);
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 0),
                child: Center(
                  child: AppText(
                      DateFormat('hh:mm:ss a').format(t),
                      size: 12,
                      color: AppColors.textMuted),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Order>>(
        stream: _orderSvc.ordersStream(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.gold)),
            );
          }

          // Show only paid orders (not voided)
          final orders = snap.data!
              .where((o) => o.status == OrderStatus.paid)
              .take(12)
              .toList();

          // Filter: only show orders not fully bumped
          final activeOrders = orders
              .where((o) => !_allDone(o.id, o.items.length) ||
                  (_doneState[o.id] == null))
              .toList();

          if (activeOrders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('👨‍🍳',
                      style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  AppText('No active orders',
                      size: 14, color: AppColors.textMuted),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:
                  MediaQuery.of(context).size.width > 600 ? 3 : 1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio:
                  MediaQuery.of(context).size.width > 600
                      ? 0.85
                      : 1.8,
            ),
            itemCount: activeOrders.length,
            itemBuilder: (_, i) => _KdsCard(
              order: activeOrders[i],
              doneMap: _doneState[activeOrders[i].id] ?? {},
              onToggle: (idx) =>
                  _toggle(activeOrders[i].id, idx),
              allDone: _allDone(
                  activeOrders[i].id, activeOrders[i].items.length),
              onBump: () {
                setState(() {
                  // Mark all done then remove
                  final m = <int, bool>{};
                  for (int j = 0;
                      j < activeOrders[i].items.length;
                      j++) {
                    m[j] = true;
                  }
                  _doneState[activeOrders[i].id] = m;
                });
                Future.delayed(const Duration(milliseconds: 400),
                    () {
                  setState(() {
                    _doneState.remove(activeOrders[i].id);
                  });
                });
              },
            ),
          );
        },
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C1A0E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: allDone
                ? AppColors.green
                : const Color(0xFF5C3317),
            width: allDone ? 1.5 : 1),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF3D2614),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                AppText(
                    'Order #${order.orderNumber.toString().padLeft(3, '0')}',
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.goldLight),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.espresso,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      AppText(order.customerName,
                          size: 10,
                          color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AppText(
                    DateFormat('h:mm a').format(order.createdAt),
                    size: 11,
                    color: AppColors.textMuted),
              ],
            ),
          ),

          // Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: order.items.length,
              itemBuilder: (_, i) {
                final done = doneMap[i] ?? false;
                return GestureDetector(
                  onTap: () => onToggle(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: i < order.items.length - 1
                              ? const Color(0xFF3D2614)
                              : Colors.transparent,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        AppText('${order.items[i].qty}×',
                            size: 14,
                            weight: FontWeight.w700,
                            color: AppColors.goldLight),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.items[i].name,
                            style: TextStyle(
                              fontSize: 12,
                              color: done
                                  ? const Color(0xFF5C3317)
                                  : const Color(0xFFD4B88A),
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: done
                                ? AppColors.green
                                : Colors.transparent,
                            border: Border.all(
                              color: done
                                  ? AppColors.green
                                  : const Color(0xFF5C3317),
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: done
                              ? const Icon(Icons.check,
                                  size: 13,
                                  color: Color(0xFFD0F0B0))
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bump button
          GestureDetector(
            onTap: onBump,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: allDone
                    ? AppColors.green
                    : const Color(0xFF5C3317),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(9)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    allDone
                        ? Icons.check_circle_outline
                        : Icons.done_all,
                    size: 15,
                    color: allDone
                        ? const Color(0xFFD0F0B0)
                        : AppColors.goldLight,
                  ),
                  const SizedBox(width: 6),
                  AppText(
                      allDone
                          ? '✓ Ready — Bump'
                          : 'Mark all done & bump',
                      size: 12,
                      weight: FontWeight.w600,
                      color: allDone
                          ? const Color(0xFFD0F0B0)
                          : AppColors.goldLight),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
