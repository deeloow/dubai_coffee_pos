import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/order_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import 'receipt_sheet.dart';

class ReceiptListSheet extends StatefulWidget {
  final BuildContext parentContext;

  const ReceiptListSheet({super.key, required this.parentContext});

  @override
  State<ReceiptListSheet> createState() => _ReceiptListSheetState();
}

class _ReceiptListSheetState extends State<ReceiptListSheet> {
  static const int _receiptPageSize = 250;

  final OrderService _orderSvc = OrderService();
  String _search = '';
  bool _showAllReceipts = false;
  int _receiptLimit = _receiptPageSize;

  bool _matchesSearch(Order order) {
    return _search.isEmpty ||
        order.orderNumber.toString().contains(_search) ||
        order.customerName.toLowerCase().contains(_search) ||
        order.items.any((i) => i.name.toLowerCase().contains(_search));
  }

  void _openReceipt(Order order) {
    showModalBottomSheet(
      context: widget.parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiptSheet(order: order),
    );
  }

  Widget _buildReceiptTile(Order order) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderColor, width: 0.5),
            ),
            alignment: Alignment.center,
            child: AppText(
              order.status == OrderStatus.voided
                  ? 'VOID'
                  : '#${order.orderNumber.toString().padLeft(3, '0')}',
              size: 12,
              weight: FontWeight.w700,
              color: order.status == OrderStatus.voided
                  ? AppColors.red
                  : AppColors.espresso,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(order.customerName, size: 14, weight: FontWeight.w700),
                const SizedBox(height: 4),
                AppText(
                  '${order.items.length} items • ${order.paymentMethodLabel}',
                  size: 12,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 2),
                AppText(
                  DateFormat('MMM d • h:mm a').format(order.createdAt),
                  size: 11,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppText(formatPHP(order.total),
                  size: 13, weight: FontWeight.w700, color: AppColors.goldDark),
              const SizedBox(height: 6),
              StatusBadge(
                label: order.statusLabel,
                isPaid: order.status == OrderStatus.paid,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: AppText('Receipt list',
                      size: 16, weight: FontWeight.w700),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (value) => setState(() {
                _search = value.toLowerCase();
                _showAllReceipts = true;
                _receiptLimit = _receiptPageSize;
              }),
              decoration: const InputDecoration(
                hintText: 'Search order number, customer or item',
                prefixIcon:
                    Icon(Icons.search, color: AppColors.textMuted, size: 20),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<Order>>(
              stream: _orderSvc.ordersStream(
                  limit: _showAllReceipts ? null : _receiptLimit),
              initialData: const [],
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return const Center(
                    child: Text('Unable to load receipts.'),
                  );
                }

                final displayOrders = snap.data!;
                final filteredOrders =
                    displayOrders.where(_matchesSearch).toList();
                final loadedReceipts = displayOrders.length;
                final visibleReceipts = filteredOrders.length;

                if (!_showAllReceipts &&
                    displayOrders.length >= _receiptLimit) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: AppText(
                                'Showing $visibleReceipts of $loadedReceipts loaded receipts. Load more to see older receipts.',
                                size: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _receiptLimit += _receiptPageSize;
                                if (_receiptLimit >= displayOrders.length) {
                                  _showAllReceipts = true;
                                }
                              }),
                              child: const Text('Load more'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: filteredOrders.isEmpty
                            ? const EmptyState(
                                message: 'No receipts found',
                                icon: Icons.receipt_long_outlined)
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                itemCount: filteredOrders.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, index) {
                                  final order = filteredOrders[index];
                                  return GestureDetector(
                                    onTap: () => _openReceipt(order),
                                    child: _buildReceiptTile(order),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                }

                if (filteredOrders.isEmpty) {
                  return const EmptyState(
                      message: 'No receipts found',
                      icon: Icons.receipt_long_outlined);
                }

                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final order = filteredOrders[index];
                    return GestureDetector(
                      onTap: () => _openReceipt(order),
                      child: _buildReceiptTile(order),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
