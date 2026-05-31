import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/pos_provider.dart';
import '../../services/order_service.dart';
import '../../services/local_order_socket_provider.dart';
import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import 'receipt_sheet.dart';

class CartSheet extends StatefulWidget {
  const CartSheet({super.key});

  @override
  State<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<CartSheet> {
  final OrderService _orderSvc = OrderService();
  DiscountType _discType = DiscountType.none;
  final _discValCtrl = TextEditingController(text: '0');
  String _sugarLevel = 'Regular sugar';
  bool _processing = false;

  @override
  void dispose() {
    _discValCtrl.dispose();
    super.dispose();
  }

  void _updateDiscount() {
    final pos = context.read<PosProvider>();
    final val = double.tryParse(_discValCtrl.text) ?? 0;
    pos.setDiscount(DiscountInfo(type: _discType, value: val));
  }

  Future<void> _processPayment(
      BuildContext context, PaymentMethod method) async {
    final pos = context.read<PosProvider>();
    final auth = context.read<AuthProvider>();

    if (!pos.hasCustomer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter customer name first'),
            backgroundColor: AppColors.red),
      );
      return;
    }
    if (pos.isEmpty) return;

    if (method == PaymentMethod.cash) {
      _showCashDialog(context, method);
      return;
    }

    if (method == PaymentMethod.gcash) {
      _showGcashDialog(context, auth);
      return;
    }

    setState(() => _processing = true);
    await _finalize(context, method, pos.total, 0, auth);
  }

  Future<void> _showGcashDialog(
      BuildContext context, AuthProvider auth) async {
    final pos = context.read<PosProvider>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const AppText('GCash Payment',
            size: 16, weight: FontWeight.w600),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppText(
              'Scan the owner/admin GCash QR code below. Tap Done after the payment is completed.',
              size: 13,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 18),
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.borderColor, width: 0.5),
              ),
              child: const Center(
                child: Icon(Icons.qr_code, size: 110, color: AppColors.espresso),
              ),
            ),
            const SizedBox(height: 14),
            const AppText('Owner/Admin GCash QR',
                size: 13, weight: FontWeight.w600),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const AppText('Cancel',
                size: 13, color: AppColors.textMuted),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _processing = true);
              await _finalize(context, PaymentMethod.gcash,
                  pos.total, 0, auth);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCashDialog(
      BuildContext context, PaymentMethod method) async {
    final pos = context.read<PosProvider>();
    final auth = context.read<AuthProvider>();
    final ctrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final tendered = double.tryParse(ctrl.text) ?? 0;
          final change = tendered - pos.total;
          return AlertDialog(
            backgroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const AppText('Cash Payment',
                size: 16, weight: FontWeight.w600),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AppText('Amount due', size: 13),
                      AppText(formatPHP(pos.total),
                          size: 16,
                          weight: FontWeight.w700,
                          color: AppColors.goldDark),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: const TextStyle(
                      fontSize: 20, color: AppColors.espresso),
                  decoration: const InputDecoration(
                    labelText: 'Cash tendered',
                    prefixText: '₱ ',
                    prefixStyle: TextStyle(
                        fontSize: 18, color: AppColors.espresso),
                  ),
                  onChanged: (_) => setS(() {}),
                ),
                if (tendered >= pos.total && tendered > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3DE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const AppText('Change', size: 12, color: AppColors.green),
                        AppText(formatPHP(change),
                            size: 22,
                            weight: FontWeight.w700,
                            color: AppColors.green),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const AppText('Cancel', size: 13, color: AppColors.textMuted),
              ),
              ElevatedButton(
                onPressed: tendered < pos.total
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        setState(() => _processing = true);
                        await _finalize(
                            context, method, tendered, change, auth);
                      },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _finalize(
    BuildContext context,
    PaymentMethod method,
    double tendered,
    double change,
    AuthProvider auth,
  ) async {
    final pos = context.read<PosProvider>();
    try {
      final orderNum = await _orderSvc.getNextOrderNumber();
      final order = Order(
        id: '',
        orderNumber: orderNum,
        customerName: pos.customerName,
        cashierName: auth.user?.name ?? 'Unknown',
        items: List.from(pos.items),
        subtotal: pos.subtotal,
        discount: pos.discountAmount,
        discountLabel: pos.discount.label,
        vat: pos.vat,
        total: pos.total,
        tendered: tendered,
        change: change,
        paymentMethod: method,
        sugarLevel: _sugarLevel,
        createdAt: DateTime.now(),
        status: OrderStatus.paid,
      );

      final savedId = await _orderSvc.saveOrder(order);
      final savedOrder = Order(
        id: savedId,
        orderNumber: order.orderNumber,
        customerName: order.customerName,
        cashierName: order.cashierName,
        items: order.items,
        subtotal: order.subtotal,
        discount: order.discount,
        discountLabel: order.discountLabel,
        vat: order.vat,
        total: order.total,
        tendered: order.tendered,
        change: order.change,
        paymentMethod: order.paymentMethod,
        sugarLevel: order.sugarLevel,
        createdAt: order.createdAt,
        status: order.status,
      );

      final localSocket = context.read<LocalOrderSocketProvider>();
      if (localSocket.isConnected) {
        final sent = await localSocket.sendOrder(savedOrder);
        if (!sent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order confirmed, but failed to send to connected device.'),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }

      pos.clearOrder();
      setState(() => _processing = false);

      if (mounted) {
        Navigator.pop(context); // close cart sheet
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          isDismissible: false,
          builder: (_) => ReceiptSheet(order: savedOrder),
        );
      }
    } catch (e) {
      setState(() => _processing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Handle + header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.borderColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const AppText('Order Summary',
                              size: 16, weight: FontWeight.w600),
                          const Spacer(),
                          // Customer chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.bgLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.borderColor,
                                  width: 0.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline,
                                    size: 13,
                                    color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                AppText(pos.customerName,
                                    size: 12,
                                    weight: FontWeight.w500),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              pos.clearOrder();
                            },
                            child: const Icon(Icons.delete_outline,
                                color: AppColors.red, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: AppColors.borderColor),

                // Items
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    itemCount: pos.items.length,
                    itemBuilder: (_, i) {
                      final item = pos.items[i];
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Text(item.icon,
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  AppText(item.name,
                                      size: 13,
                                      weight: FontWeight.w500),
                                  AppText('${formatPHP(item.price)} each',
                                      size: 11,
                                      color: AppColors.textMuted),
                                ],
                              ),
                            ),
                            _QtyControl(
                              qty: item.qty,
                              onDec: () => pos.changeQty(i, -1),
                              onInc: () => pos.changeQty(i, 1),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              child: AppText(
                                  formatPHP(item.price * item.qty),
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: AppColors.goldDark,
                                  align: TextAlign.right),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Discount
                Container(
                  padding: const EdgeInsets.all(12),
                  color: AppColors.bgLight,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_offer_outlined,
                              size: 15, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          const AppText('Discount',
                              size: 12, color: AppColors.textMuted),
                          const Spacer(),
                          _DiscountDropdown(
                            value: _discType,
                            onChanged: (v) {
                              setState(() => _discType = v!);
                              _updateDiscount();
                            },
                          ),
                          if (_discType == DiscountType.percent ||
                              _discType == DiscountType.flat) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              child: TextField(
                                controller: _discValCtrl,
                                keyboardType:
                                    TextInputType.number,
                                style: const TextStyle(
                                    fontSize: 13),
                                decoration: InputDecoration(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(6),
                                    borderSide: const BorderSide(
                                        color: AppColors.borderColor),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.white,
                                ),
                                onChanged: (_) => _updateDiscount(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Summary
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    border: Border(
                        top: BorderSide(
                            color: AppColors.borderColor,
                            width: 0.5)),
                  ),
                  child: Column(
                    children: [
                      DividerRow(
                          left: 'Subtotal',
                          right: formatPHP(pos.subtotal)),
                      if (pos.discountAmount > 0)
                        DividerRow(
                            left: pos.discount.label,
                            right: '−${formatPHP(pos.discountAmount)}',
                            isDiscount: true),
                      DividerRow(
                          left: 'VAT (12%)',
                          right: formatPHP(pos.vat)),
                      const Divider(
                          height: 16,
                          color: AppColors.borderColor),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText('Sugar option',
                              size: 12, color: AppColors.textMuted),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in [
                                'No sugar',
                                'Less sugar',
                                'Regular sugar',
                                'Extra sugar'
                              ])
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _sugarLevel = option;
                                    context.read<PosProvider>().setSugarForAll(option);
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _sugarLevel == option
                                          ? AppColors.espresso
                                          : AppColors.white,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _sugarLevel == option
                                            ? AppColors.espresso
                                            : AppColors.borderColor,
                                      ),
                                    ),
                                    child: AppText(option,
                                        size: 12,
                                        weight: _sugarLevel == option
                                            ? FontWeight.w700
                                            : FontWeight.normal,
                                        color: _sugarLevel == option
                                            ? AppColors.goldLight
                                            : AppColors.brown2),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                      DividerRow(
                          left: 'Total',
                          right: formatPHP(pos.total),
                          isTotal: true),
                      const SizedBox(height: 14),

                      // Payment buttons
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 3.2,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        children: [
                          _payBtn('Cash', Icons.payments_outlined,
                              true, PaymentMethod.cash, context),
                          _payBtn('GCash', Icons.phone_android,
                              false, PaymentMethod.gcash, context),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
            if (_processing) const LoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _payBtn(String label, IconData icon, bool primary,
      PaymentMethod method, BuildContext context) {
    return GestureDetector(
      onTap: () => _processPayment(context, method),
      child: Container(
        decoration: BoxDecoration(
          color: primary ? AppColors.espresso : AppColors.cream,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: primary
                  ? AppColors.espresso
                  : AppColors.borderColor,
              width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: primary
                    ? AppColors.goldLight
                    : AppColors.espresso),
            const SizedBox(width: 6),
            AppText(label,
                size: 12,
                weight: FontWeight.w600,
                color: primary
                    ? AppColors.goldLight
                    : AppColors.espresso),
          ],
        ),
      ),
    );
  }
}

class _QtyControl extends StatelessWidget {
  final int qty;
  final VoidCallback onDec;
  final VoidCallback onInc;

  const _QtyControl(
      {required this.qty, required this.onDec, required this.onInc});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _btn(Icons.remove, onDec),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: AppText('$qty',
              size: 14, weight: FontWeight.w600),
        ),
        _btn(Icons.add, onInc),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback fn) {
    return GestureDetector(
      onTap: fn,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(6),
          color: AppColors.bgLight,
        ),
        child: Icon(icon, size: 14, color: AppColors.brown),
      ),
    );
  }
}

class _DiscountDropdown extends StatelessWidget {
  final DiscountType value;
  final void Function(DiscountType?) onChanged;

  const _DiscountDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<DiscountType>(
      value: value,
      underline: const SizedBox(),
      style: const TextStyle(fontSize: 12, color: AppColors.espresso),
      isDense: true,
      items: const [
        DropdownMenuItem(
            value: DiscountType.none,
            child: Text('No discount')),
        DropdownMenuItem(
            value: DiscountType.percent,
            child: Text('Percent %')),
        DropdownMenuItem(
            value: DiscountType.flat,
            child: Text('Fixed ₱')),
        DropdownMenuItem(
            value: DiscountType.senior,
            child: Text('Senior/PWD (20%)')),
        DropdownMenuItem(
            value: DiscountType.staff,
            child: Text('Staff (15%)')),
      ],
      onChanged: onChanged,
    );
  }
}
