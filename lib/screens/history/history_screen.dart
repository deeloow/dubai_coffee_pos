import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/auth_provider.dart';
import '../../services/local_order_socket_provider.dart';
import '../../services/order_service.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

bool matchesHistoryFilter(Order order, String rawFilter) {
  final normalizedFilter = rawFilter.trim().toLowerCase();
  final paymentLabel = order.paymentMethodLabel.toLowerCase();

  return normalizedFilter == 'all' ||
      (normalizedFilter == 'paid' &&
          (order.status == OrderStatus.paid || order.status == OrderStatus.completed)) ||
      (normalizedFilter == 'void' && order.status == OrderStatus.voided) ||
      paymentLabel == normalizedFilter;
}

class HistoryScrollableBody extends StatelessWidget {
  final Widget? searchSection;
  final Widget? statsSection;
  final Widget? filterChip;
  final Widget? loadMoreSection;
  final Widget? emptyState;
  final List<Widget> orderTiles;

  const HistoryScrollableBody({
    super.key,
    this.searchSection,
    this.statsSection,
    this.filterChip,
    this.loadMoreSection,
    this.emptyState,
    this.orderTiles = const [],
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (searchSection != null)
          SliverToBoxAdapter(child: searchSection!),
        if (statsSection != null)
          SliverToBoxAdapter(child: statsSection!),
        if (filterChip != null)
          SliverToBoxAdapter(child: filterChip!),
        if (loadMoreSection != null)
          SliverToBoxAdapter(child: loadMoreSection!),
        if (orderTiles.isEmpty)
          if (emptyState != null)
            SliverToBoxAdapter(child: emptyState!)
          else
            const SliverToBoxAdapter(child: SizedBox.shrink())
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + bottomInset),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, index) => orderTiles[index],
                childCount: orderTiles.length,
              ),
            ),
          ),
      ],
    );
  }
}

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

  StreamSubscription<DateTime>? _reportDateSub;
  DateTime _reportDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _reportDateSub = ReportService().reportDateStream().listen((d) {
      setState(() {
        _reportDate = d;
      });
    });
  }

  @override
  void dispose() {
    _reportDateSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Order> _filterOrders(List<Order> orders) {
    return orders.where((o) {
      final matchSearch = _search.isEmpty ||
          o.customerName.toLowerCase().contains(_search) ||
          o.orderNumber.toString().contains(_search) ||
          o.items.any((i) => i.name.toLowerCase().contains(_search));
      return matchSearch && matchesHistoryFilter(o, _filter);
    }).toList();
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final isLandscape = responsive.isLandscape;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Order History'),
        actions: isLandscape
            ? null
            : [
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
                  ],
                ),
              ],
      ),
      body: StreamBuilder<List<Order>>(
        stream: _orderSvc.ordersStream(
            limit: (_search.isEmpty && _filter == 'all' && !_showAllOrders)
                ? _historyLimit
                : null,
            includeArchived: false),
        initialData: const [],
        builder: (ctx, snap) {
          if (snap.hasError) {
            return const Center(
              child: Text('Unable to load order history.'),
            );
          }

          final auth = context.watch<AuthProvider>();
          final allOrders = snap.data!;
          final paid = allOrders
              .where((o) => (o.status == OrderStatus.paid || o.status == OrderStatus.completed) && _isSameDate(o.createdAt, _reportDate))
              .toList();
          final filtered = _filterOrders(allOrders);
          final loadedOrders = allOrders.length;
          final visibleOrders = filtered.length;

          final dineIn = paid.where((o) => o.orderType == OrderType.dineIn).toList();
          final takeOut = paid.where((o) => o.orderType == OrderType.takeOut).toList();
          final totalSales = paid.fold(0.0, (s, o) => s + o.total);
          final avgOrder = paid.isEmpty ? 0.0 : totalSales / paid.length;
          final voided = allOrders.where((o) => o.status == OrderStatus.voided && _isSameDate(o.createdAt, _reportDate)).length;

          final statsChildren = [
            StatCard(label: 'Total Sales', value: formatPHP(totalSales), gold: true),
            StatCard(label: 'Orders', value: '${paid.length}'),
            StatCard(label: 'Dine-In', value: '${dineIn.length}'),
            StatCard(label: 'Take-Out', value: '${takeOut.length}'),
            StatCard(label: 'Avg Order', value: formatPHP(avgOrder)),
            StatCard(label: 'Voided', value: '$voided', deltaUp: false),
          ];

          return HistoryScrollableBody(
            searchSection: Container(
              color: AppColors.white,
              padding: EdgeInsets.all(isLandscape ? 8 : 10),
              child: isLandscape
                  ? Row(
                      children: [
                        Expanded(
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
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppColors.bgLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: PopupMenuButton<String>(
                            tooltip: 'Filter orders',
                            icon: const Icon(Icons.filter_list, size: 18, color: AppColors.espresso),
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
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.bgLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: AppText(
                            DateFormat('MMM d').format(_reportDate),
                            size: 12,
                            weight: FontWeight.w600,
                            color: AppColors.espresso,
                          ),
                        ),
                      ],
                    )
                  : TextField(
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
            statsSection: Padding(
              padding: EdgeInsets.all(isLandscape ? 8 : 10),
              child: isLandscape
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: statsChildren
                          .map((card) => SizedBox(width: 140, child: card))
                          .toList(),
                    )
                  : GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 2.5,
                      physics: const NeverScrollableScrollPhysics(),
                      children: statsChildren,
                    ),
            ),
            filterChip: _filter != 'all'
                ? Padding(
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
                  )
                : null,
            loadMoreSection: !_showAllOrders && allOrders.length >= _historyLimit
                ? Padding(
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
                  )
                : null,
            emptyState: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 24, bottom: 24),
                    child: EmptyState(
                      message: 'No orders found',
                      icon: Icons.receipt_long_outlined,
                    ),
                  )
                : null,
            orderTiles: filtered
                .map((order) => _OrderTile(
                      order: order,
                      canVoid: auth.isAdmin,
                      onVoid: () async {
                        final reason = await showDialog<String>(
                          context: context,
                          builder: (ctx) {
                            final controller = TextEditingController();
                            return AlertDialog(
                              title: DialogHeader(
                                title: 'Void Order',
                                onClose: () => Navigator.pop(ctx),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                      'Provide a reason before voiding this order.'),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: controller,
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Void reason',
                                      border: OutlineInputBorder(),
                                    ),
                                    minLines: 2,
                                    maxLines: 4,
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    if (controller.text.trim().isEmpty) {
                                      return;
                                    }
                                    Navigator.pop(ctx, controller.text.trim());
                                  },
                                  child: const Text('Void',
                                      style: TextStyle(color: AppColors.red)),
                                ),
                              ],
                            );
                          },
                        );
                        if (reason != null && reason.isNotEmpty) {
                          if (!context.mounted) return;
                          await _orderSvc.voidOrder(order.id, reason: reason);
                          if (!context.mounted) return;
                          final socketProvider = context.read<LocalOrderSocketProvider>();
                          if (socketProvider.isConnected) {
                            final voidedOrder = order.copyWith(
                              status: OrderStatus.voided,
                              voidReason: reason,
                            );
                            await socketProvider.sendOrder(voidedOrder);
                          }
                        }
                      },
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class HistoryOrderItemRow extends StatelessWidget {
  final OrderItem item;

  const HistoryOrderItemRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final subtotal = item.price * item.qty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(item.name, size: 12, weight: FontWeight.w700),
          const SizedBox(height: 2),
          Wrap(
            spacing: 10,
            runSpacing: 3,
            children: [
              AppText('Cup: ${item.cupSize}', size: 11, color: AppColors.textMuted),
              if (!item.cupSize.toLowerCase().contains('regular') && !item.cupSize.toLowerCase().contains('medium'))
                AppText('Sugar: ${item.sugarLevel}', size: 11, color: AppColors.textMuted),
              AppText('Qty: ${item.qty}', size: 11, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              AppText('Unit: ${formatPHP(item.price)}', size: 11, color: AppColors.textMuted),
              const SizedBox(width: 12),
              AppText('Subtotal: ${formatPHP(subtotal)}', size: 11, color: AppColors.textMuted),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  final VoidCallback onVoid;
  final bool canVoid;

  const _OrderTile({required this.order, required this.onVoid, required this.canVoid});

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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(DateFormat('MMM d • h:mm a').format(order.createdAt),
                size: 11, color: AppColors.textMuted),
            const SizedBox(height: 2),
            AppText(
              order.items
                  .map((item) => '${item.qty}× ${item.name} (${item.cupSize})')
                  .join(', '),
              size: 10,
              color: AppColors.textMuted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(formatPHP(order.total),
                size: 13, weight: FontWeight.w600, color: AppColors.goldDark),
            const SizedBox(width: 8),
            StatusBadge(
                label: order.statusLabel,
                isPaid: order.status == OrderStatus.paid || order.status == OrderStatus.completed),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 12, color: AppColors.borderColor),

                if (order.status == OrderStatus.voided && order.voidReason != null && order.voidReason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8EBEB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: AppText(
                        'Void reason: ${order.voidReason}',
                        size: 12,
                        color: AppColors.red,
                      ),
                    ),
                  ),

                // Items
                ...order.items.map((item) => HistoryOrderItemRow(item: item)),

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
                          const SizedBox(height: 6),
                          AppText('Cashier: ${order.cashierName.isNotEmpty ? order.cashierName : 'Unknown'}',
                              size: 11, color: AppColors.textMuted),
                          const SizedBox(height: 6),
                          AppText('Prepared By: ${order.preparedBy.isNotEmpty ? order.preparedBy : order.cashierName.isNotEmpty ? order.cashierName : 'Unknown'}',
                              size: 11, color: AppColors.textMuted),
                          const SizedBox(height: 6),
                          AppText('Order Type: ${order.orderTypeLabel}',
                              size: 11, color: AppColors.textMuted),
                          const SizedBox(height: 6),
                          if (order.orderNotes.trim().isNotEmpty)
                            AppText('Order Notes: ${order.orderNotes}',
                                size: 11, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                    if (order.status == OrderStatus.paid && canVoid)
                      GestureDetector(
                        onTap: onVoid,
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
