import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class ReceiptSheet extends StatelessWidget {
  final Order order;

  const ReceiptSheet({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Logo
          Image.asset('assets/icon.png', width: 54, height: 54),
          const SizedBox(height: 4),
          const Text('Dubai Coffee',
              style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.goldDark)),
          const AppText('Official Receipt',
              size: 11, color: AppColors.textMuted),

          const SizedBox(height: 12),

          // Order meta
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText(
                  'Order #${order.orderNumber.toString().padLeft(3, '0')}',
                  size: 11,
                  color: AppColors.textMuted),
              AppText(
                  DateFormat('MMM d, yyyy • hh:mm a')
                      .format(order.createdAt),
                  size: 11,
                  color: AppColors.textMuted),
            ],
          ),

          // Customer
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                AppText(order.customerName,
                    size: 13, weight: FontWeight.w600),
                const Spacer(),
                AppText('Cashier: ${order.cashierName}',
                    size: 11, color: AppColors.textMuted),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderColor),

          // Items
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: order.items.length,
              itemBuilder: (_, i) {
                final item = order.items[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(item.icon,
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppText(
                            '${item.name} × ${item.qty}',
                            size: 12),
                      ),
                      AppText(formatPHP(item.price * item.qty),
                          size: 12,
                          weight: FontWeight.w500),
                    ],
                  ),
                );
              },
            ),
          ),

          const Divider(height: 12, color: AppColors.borderColor),

          DividerRow(
              left: 'Subtotal',
              right: formatPHP(order.subtotal)),
          if (order.discount > 0)
            DividerRow(
                left: order.discountLabel,
                right: '−${formatPHP(order.discount)}',
                isDiscount: true),
          DividerRow(
              left: 'VAT (12%)', right: formatPHP(order.vat)),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: DashedLine(),
          ),

          DividerRow(
              left: 'Total',
              right: formatPHP(order.total),
              isTotal: true),
          DividerRow(
              left: 'Payment (${order.paymentMethodLabel})',
              right: formatPHP(order.tendered)),

          if (order.change > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3DE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppText('Change: ',
                      size: 13, color: AppColors.green),
                  AppText(formatPHP(order.change),
                      size: 18,
                      weight: FontWeight.w700,
                      color: AppColors.green),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          const AppText('Thank you for visiting Dubai Coffee!',
              size: 11, color: AppColors.textMuted, align: TextAlign.center),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('New Order'),
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.espresso,
                foregroundColor: AppColors.goldLight,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class DashedLine extends StatelessWidget {
  const DashedLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        30,
        (_) => Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: AppColors.borderColor,
          ),
        ),
      ),
    );
  }
}
