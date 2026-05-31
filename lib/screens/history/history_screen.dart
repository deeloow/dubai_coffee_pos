import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/order_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const int _historyPageSize = 250;

  final OrderService _orderSvc = OrderService();
  final _searchCtrl = TextEditingController();
  String _filter = 'all';
  String _search = '';
  bool _showAllOrders = false;
  int _historyLimit = _historyPageSize;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Order> _filterOrders(List<Order> orders) {
    return orders.where((o) {
      final matchSearch = _search.isEmpty ||
          o.customerName.toLowerCase().contains(_search) ||
          o.orderNumber.toString().contains(_search) ||
          o.items.any((i) => i.name.toLowerCase().contains(_search));
      final matchFilter = _filter == 'all' ||
          (_filter == 'paid' && o.status == OrderStatus.paid) ||
          (_filter == 'void' && o.status == OrderStatus.voided) ||
          o.paymentMethodLabel.toLowerCase() == _filter;
      return matchSearch && matchFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Order History'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() {
              _filter = v;
              _showAllOrders = true;
              _historyLimit = _historyPageSize;
            }),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('All orders')),
              const PopupMenuItem(value: 'paid', child: Text('Paid only')),
              const PopupMenuItem(value: 'void', child: Text('Voided only')),
              const PopupMenuItem(value: 'Cash', child: Text('Cash')),
              const PopupMenuItem(value: 'GCash', child: Text('GCash')),
              const PopupMenuItem(value: 'Card', child: Text('Card')),
              const PopupMenuItem(value: 'PayMaya', child: Text('PayMaya')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Order>>(
        stream: _orderSvc.ordersStream(
            limit: (_search.isEmpty && _filter == 'all' && !_showAllOrders)
                ? _historyLimit
                : null),
        initialData: const [],
        builder: (ctx, snap) {
          if (snap.hasError) {
            return const Center(
              child: Text('Unable to load order history.'),
            );
          }

          final allOrders = snap.data!;
          final paid =
              allOrders.where((o) => o.status == OrderStatus.paid).toList();
          final filtered = _filterOrders(allOrders);
          final loadedOrders = allOrders.length;
          final visibleOrders = filtered.length;

          final totalSales = paid.fold(0.0, (s, o) => s + o.total);
          final avgOrder = paid.isEmpty ? 0.0 : totalSales / paid.length;
          final voided =
              allOrders.where((o) => o.status == OrderStatus.voided).length;

          return Column(
            children: [
              // Search
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.all(10),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() {
                    _search = v.toLowerCase();
                    _showAllOrders = true;
                    _historyLimit = _historyPageSize;
                  }),
                  decoration: const InputDecoration(
                    hintText: 'Search orders, customers…',
                    prefixIcon: Icon(Icons.search,
                        size: 18, color: AppColors.textMuted),
                  ),
                ),
              ),

              // Stats
              Padding(
                padding: const EdgeInsets.all(10),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.5,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    StatCard(
                        label: 'Total Sales',
                        value: formatPHP(totalSales),
                        gold: true),
                    StatCard(label: 'Orders', value: '${paid.length}'),
                    StatCard(label: 'Avg Order', value: formatPHP(avgOrder)),
                    StatCard(label: 'Voided', value: '$voided', deltaUp: false),
                  ],
                ),
              ),

              // Filter chip
              if (_filter != 'all')
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withAlpha((0.15 * 255).toInt()),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            AppText('Filter: $_filter',
                                size: 12, color: AppColors.goldDark),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => setState(() {
                                _filter = 'all';
                                _historyLimit = _historyPageSize;
                                _showAllOrders = false;
                              }),
                              child: const Icon(Icons.close,
                                  size: 14, color: AppColors.goldDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Orders list
              if (!_showAllOrders && allOrders.length >= _historyLimit)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppText(
                          'Showing $visibleOrders of $loadedOrders loaded orders. Load more to see older orders.',
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _historyLimit += _historyPageSize;
                          if (_historyLimit >= allOrders.length) {
                            _showAllOrders = true;
                          }
                        }),
                        child: const Text('Load more'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        message: 'No orders found',
                        icon: Icons.receipt_long_outlined)
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _OrderTile(
                          order: filtered[i],
                          onVoid: () async {
                            await _orderSvc.voidOrder(filtered[i].id);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  final VoidCallback onVoid;

  const _OrderTile({required this.order, required this.onVoid});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.bgLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: AppText('#${order.orderNumber.toString().padLeft(3, '0')}',
              size: 11, weight: FontWeight.w600),
        ),
        title: Row(
          children: [
            const Icon(Icons.person_outline,
                size: 13, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Expanded(
              child: AppText(order.customerName,
                  size: 13, weight: FontWeight.w500),
            ),
          ],
        ),
        subtitle: AppText(DateFormat('MMM d • h:mm a').format(order.createdAt),
            size: 11, color: AppColors.textMuted),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(formatPHP(order.total),
                size: 13, weight: FontWeight.w600, color: AppColors.goldDark),
            const SizedBox(width: 8),
            StatusBadge(
                label: order.statusLabel,
                isPaid: order.status == OrderStatus.paid),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 12, color: AppColors.borderColor),

                // Items
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Text(item.icon, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Expanded(
                            child:
                                AppText('${item.name} × ${item.qty}', size: 12),
                          ),
                          AppText(formatPHP(item.price * item.qty), size: 12),
                        ],
                      ),
                    )),

                const Divider(height: 12, color: AppColors.borderColor),

                // Totals summary
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText('Payment: ${order.paymentMethodLabel}',
                              size: 11, color: AppColors.textMuted),
                          AppText('Cashier: ${order.cashierName}',
                              size: 11, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                    if (order.status == OrderStatus.paid)
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Void Order?'),
                              content: Text(
                                  'Void order #${order.orderNumber.toString().padLeft(3, '0')} for ${order.customerName}?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    onVoid();
                                  },
                                  child: const Text('Void',
                                      style: TextStyle(color: AppColors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCEBEB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const AppText('Void',
                              size: 12,
                              weight: FontWeight.w500,
                              color: AppColors.red),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
