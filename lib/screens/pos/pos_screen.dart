import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/pos_provider.dart';
import '../../services/menu_service.dart';
import '../../services/order_service.dart';
import '../../services/auth_provider.dart';
import '../../services/local_order_socket_provider.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import 'cash_payment_dialog.dart';
import 'customer_name_sheet.dart';
import 'receipt_list_sheet.dart';
import 'receipt_sheet.dart';

bool shouldShowCartFab({required bool isLandscape, required bool hasItems}) {
  return !isLandscape && hasItems;
}

Widget buildMenuItemImage(
    String? imagePath, String? imageBase64, String? imageMimeType,
    {double size = 56}) {
  if ((imageBase64 ?? '').isNotEmpty) {
    try {
      return Image.memory(
        base64Decode(imageBase64!),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } catch (_) {}
  }

  final resolvedPath = (imagePath ?? '').isNotEmpty
      ? imagePath!
      : MenuItem.defaultDrinkImageAsset;

  if (resolvedPath.startsWith('assets/')) {
    return Image.asset(resolvedPath,
        width: size, height: size, fit: BoxFit.cover);
  }

  final file = File(resolvedPath);
  if (file.existsSync()) {
    return Image.file(file, width: size, height: size, fit: BoxFit.cover);
  }

  return Image.asset(
    MenuItem.defaultDrinkImageAsset,
    width: size,
    height: size,
    fit: BoxFit.cover,
  );
}

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final MenuService _menuSvc = MenuService();
  final _searchCtrl = TextEditingController();
  final _orderNotesCtrl = TextEditingController();
  final OrderService _orderSvc = OrderService();
  OrderType _orderType = OrderType.dineIn;
  final TextEditingController _discValCtrl = TextEditingController(text: '0');
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  String _sugarLevel = 'Regular sugar';

  List<MenuItem> _mergeMenuVariants(List<MenuItem> items) {
    final grouped = <String, List<MenuItem>>{};
    String baseName(String name) =>
        name.replaceAll(RegExp(r'\s+(12oz|16oz|22oz)\$'), '').trim();
    final rank = {'12oz': 0, '16oz': 1, '22oz': 2};

    for (final item in items) {
      final key = '${item.category}|${baseName(item.name).toLowerCase()}';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return grouped.values.map((variants) {
      variants.sort((a, b) {
        if (a.available != b.available) {
          return a.available ? -1 : 1;
        }
        return (rank[a.cupSize] ?? 0).compareTo(rank[b.cupSize] ?? 0);
      });
      final representative = variants.first;
      return representative.copyWith(
        name: baseName(representative.name),
        price: representative.price,
      );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _menuSvc.seedMenuIfEmpty();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _orderNotesCtrl.dispose();
    super.dispose();
  }

  void _showCustomerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const CustomerNameSheet(),
    );
  }

  Future<String?> _showCupSizePicker(
      BuildContext context, MenuItem menuItem) async {
    final availableSizes = menuItem.availableCupSizes.isNotEmpty
        ? menuItem.availableCupSizes
        : const ['12oz', '16oz'];
    String selected = availableSizes.first;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (builderContext, setState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: AppText('Select Cup Size',
                            size: 16, weight: FontWeight.w700),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...availableSizes.map((size) {
                    final isSelected = selected == size;
                    return GestureDetector(
                      onTap: () => setState(() => selected = size),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color:
                              isSelected ? AppColors.espresso : AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.espresso
                                : AppColors.borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.goldLight
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.goldLight
                                      : AppColors.textMuted,
                                  width: 1.5,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: isSelected
                                  ? const Center(
                                      child: Icon(Icons.check,
                                          size: 14, color: AppColors.espresso),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            AppText(size,
                                size: 14,
                                weight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.goldLight
                                    : AppColors.espresso),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(selected),
                    child: const Text('Add to Order'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    return result;
  }

  Future<void> _showReceipt(
      BuildContext context, String orderId, Order order) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiptSheet(order: order),
    );
  }

  Future<void> _processPayment(BuildContext context) async {
    final pos = context.read<PosProvider>();
    final currentContext = context;

    if (!pos.hasCustomer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter customer name first'),
            backgroundColor: AppColors.red),
      );
      return;
    }
    if (pos.isEmpty) return;

    final selectedMethod = await showDialog<PaymentMethod>(
      context: currentContext,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: DialogHeader(
          title: 'Select Payment Method',
          titleSize: 16,
          titleWeight: FontWeight.w700,
          onClose: () => Navigator.pop(ctx),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.money_outlined, color: AppColors.espresso),
              title: const AppText('Cash', size: 14, weight: FontWeight.w600),
              subtitle: const AppText(
                  'Complete the order immediately with cash payment.',
                  size: 12,
                  color: AppColors.textMuted),
              onTap: () => Navigator.pop(ctx, PaymentMethod.cash),
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: const Icon(Icons.qr_code, color: AppColors.espresso),
              title: const AppText('GCash', size: 14, weight: FontWeight.w600),
              subtitle: const AppText(
                  'Show the admin-managed QR code and number for payment.',
                  size: 12,
                  color: AppColors.textMuted),
              onTap: () => Navigator.pop(ctx, PaymentMethod.gcash),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const AppText('Cancel', size: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );

    if (selectedMethod == null) return;
    setState(() => _selectedPaymentMethod = selectedMethod);

    if (selectedMethod == PaymentMethod.cash) {
      // ignore: use_build_context_synchronously
      await _showCashDialog(currentContext);
      return;
    }

    // ignore: use_build_context_synchronously
    await _showGcashDialog(currentContext);
  }

  Future<void> _showGcashDialog(BuildContext context) async {
    final pos = context.read<PosProvider>();
    if (!mounted) return;
    final currentContext = context;
    final settings = SettingsService();
    final qrFile = await settings.loadPaymentQrCodeFile();
    final gcashNumber = settings.gcashNumber;
    final refCtrl = TextEditingController();

    await showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (ctx) {
        final isLandscape = ResponsiveLayout.of(ctx).isLandscape;

        return KeyboardSafeDialog(
          child: LayoutBuilder(
            builder: (layoutContext, constraints) {
              final dialogWidth = constraints.maxWidth > 760
                  ? 760.0
                  : constraints.maxWidth - 32;
              final useSideBySide = isLandscape && constraints.maxWidth >= 620;

              return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: dialogWidth),
                child: AlertDialog(
                  scrollable: true,
                  backgroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  insetPadding: EdgeInsets.zero,
                  titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  title: DialogHeader(
                    title: 'GCash Payment',
                    titleSize: 16,
                    titleWeight: FontWeight.w600,
                    onClose: () => Navigator.pop(ctx),
                  ),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(bottom: 8),
                      child: useSideBySide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const AppText(
                                        'Scan the owner/admin GCash QR code below. Tap Done after the payment is completed.',
                                        size: 13,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(height: 14),
                                      ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: 220),
                                        child: AspectRatio(
                                          aspectRatio: 1,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.bgLight,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                  color: AppColors.borderColor,
                                                  width: 0.5),
                                            ),
                                            child: qrFile != null
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    child: Image.file(
                                                      qrFile,
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                    ),
                                                  )
                                                : const Center(
                                                    child: Icon(Icons.qr_code,
                                                        size: 110,
                                                        color:
                                                            AppColors.espresso),
                                                  ),
                                          ),
                                        ),
                                      ),
                                      if (gcashNumber != null &&
                                          gcashNumber.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.bgLight,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: AppColors.borderColor),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const AppText('GCash Number',
                                                  size: 12,
                                                  weight: FontWeight.w600),
                                              const SizedBox(height: 4),
                                              AppText(gcashNumber,
                                                  size: 13,
                                                  color: AppColors.espresso),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      const AppText('Owner/Admin GCash QR',
                                          size: 13, weight: FontWeight.w600),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.bgLight,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: AppColors.borderColor),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const AppText('Amount due',
                                                size: 12,
                                                color: AppColors.textMuted),
                                            const SizedBox(height: 4),
                                            AppText(formatPHP(pos.total),
                                                size: 18,
                                                weight: FontWeight.w700,
                                                color: AppColors.goldDark),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const AppText('Payment instructions',
                                          size: 12, weight: FontWeight.w600),
                                      const SizedBox(height: 4),
                                      const AppText(
                                          'Send the payment via GCash, then confirm once the transfer is complete.',
                                          size: 12,
                                          color: AppColors.textMuted),
                                      const SizedBox(height: 10),
                                      TextField(
                                        controller: refCtrl,
                                        keyboardType: TextInputType.text,
                                        textInputAction: TextInputAction.done,
                                        scrollPadding:
                                            const EdgeInsets.only(bottom: 120),
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Reference number (optional)',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const AppText('Payment status',
                                          size: 12, weight: FontWeight.w600),
                                      const SizedBox(height: 4),
                                      const AppText('Awaiting confirmation',
                                          size: 12, color: AppColors.textMuted),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppText(
                                  'Scan the owner/admin GCash QR code below. Tap Done after the payment is completed.',
                                  size: 13,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 220),
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.bgLight,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color: AppColors.borderColor,
                                              width: 0.5),
                                        ),
                                        child: qrFile != null
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: Image.file(
                                                  qrFile,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                ),
                                              )
                                            : const Center(
                                                child: Icon(Icons.qr_code,
                                                    size: 110,
                                                    color: AppColors.espresso),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (gcashNumber != null &&
                                    gcashNumber.isNotEmpty) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgLight,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: AppColors.borderColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const AppText('GCash Number',
                                            size: 12, weight: FontWeight.w600),
                                        const SizedBox(height: 4),
                                        AppText(gcashNumber,
                                            size: 13,
                                            color: AppColors.espresso),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                TextField(
                                  controller: refCtrl,
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.done,
                                  scrollPadding:
                                      const EdgeInsets.only(bottom: 120),
                                  decoration: const InputDecoration(
                                    labelText: 'Reference number (optional)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                    ),
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
                        await _finalize(
                            currentContext, PaymentMethod.gcash, pos.total, 0);
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showCashDialog(BuildContext context) async {
    final pos = context.read<PosProvider>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CashPaymentDialog(
        total: pos.total,
        onConfirm: (tendered, change) async {
          Navigator.pop(ctx);
          await _finalize(context, PaymentMethod.cash, tendered, change);
        },
        onCancel: () => Navigator.pop(ctx),
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  Future<void> _finalize(BuildContext context, PaymentMethod method,
      double tendered, double change) async {
    final pos = context.read<PosProvider>();
    final localSocket = context.read<LocalOrderSocketProvider>();
    final auth = context.read<AuthProvider>();
    if (!mounted) return;
    final currentContext = context;

    try {
      pos.refreshPricesFromMenu();
      final resolvedItems = pos.items.map((item) {
        final menuItem = _menuSvc.getMenuItemById(item.menuItemId);
        if (menuItem == null) {
          return item.copyWith();
        }
        final resolvedPrice = _menuSvc.priceForCupSize(menuItem, item.cupSize);
        return item.copyWith(price: resolvedPrice);
      }).toList();
      final resolvedSubtotal =
          resolvedItems.fold(0.0, (sum, item) => sum + (item.price * item.qty));
      final resolvedDiscount = pos.discount.apply(resolvedSubtotal);
      final resolvedTotal = resolvedSubtotal - resolvedDiscount;
      final orderNum = await _orderSvc.getNextOrderNumber();
      final order = Order(
        id: '',
        orderNumber: orderNum,
        customerName: pos.customerName,
        cashierName: auth.user?.name ?? 'Unknown',
        items: resolvedItems,
        subtotal: resolvedSubtotal,
        discount: resolvedDiscount,
        discountLabel: pos.discount.label,
        total: resolvedTotal,
        tendered: tendered,
        change: change,
        paymentMethod: method,
        sugarLevel: _sugarLevel,
        orderNotes: _orderNotesCtrl.text.trim(),
        orderType: _orderType,
        createdAt: DateTime.now(),
        status: OrderStatus.paid,
      );

      final savedOrderId = await _orderSvc.saveOrder(order, isServerRole: true);
      final savedOrder = order.copyWith(id: savedOrderId);

      if (localSocket.isConnected) {
        final sent = await localSocket.sendOrder(savedOrder);
        if (sent) {
          await localSocket.syncInventoryToPeers();
        } else if (mounted) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(
              content: Text(
                  'Order confirmed, but failed to send to connected device.'),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }

      pos.clearOrder();
      setState(() {
        _discValCtrl.text = '0';
        _sugarLevel = 'Regular sugar';
        _orderType = OrderType.dineIn;
        _orderNotesCtrl.clear();
      });

      if (!mounted) return;
      // ignore: use_build_context_synchronously
      final navigator = Navigator.of(currentContext);
      if (navigator.canPop()) {
        navigator.pop();
      }
      // ignore: use_build_context_synchronously
      await _showReceipt(navigator.context, order.id, savedOrder);
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  Future<String?> _handleAddItem(
      MenuItem menuItem, BuildContext context, PosProvider pos) async {
    if (!pos.hasCustomer) {
      _showCustomerSheet(context);
      return null;
    }

    final needsCupSizePrompt = menuItem.availableCupSizes.length > 1 ||
        menuItem.cupSizeType == CategoryCupSizeType.regularAndMedium ||
        menuItem.cupSizeType == CategoryCupSizeType.twelveAndSixteen;

    if (needsCupSizePrompt) {
      final selectedSize = await _showCupSizePicker(context, menuItem);
      if (selectedSize == null) return null;
      pos.addItemWithCupSize(menuItem, selectedSize);
      return selectedSize;
    }

    pos.addItem(menuItem);
    return menuItem.cupSize;
  }

  void _showReceiptList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiptListSheet(parentContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final auth = context.watch<AuthProvider>();
    final responsive = ResponsiveLayout.of(context);
    final isLandscape = responsive.isLandscape;
    pos.refreshPricesFromMenu();
    final hasItems = pos.items.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.espresso,
        elevation: 0,
        foregroundColor: AppColors.goldLight,
        toolbarHeight: isLandscape ? 56 : kToolbarHeight,
        title: SizedBox(
          width: double.infinity,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icon.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Dubai Coffee',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showReceiptList(context),
            icon: const Icon(Icons.receipt_long_outlined,
                color: AppColors.goldLight),
            tooltip: 'Receipt list',
          ),
          if (pos.hasCustomer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.darkBrown,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 14, color: AppColors.goldLight),
                      const SizedBox(width: 4),
                      AppText(pos.customerName,
                          size: 12, color: AppColors.goldLight),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.darkBrown,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AppText(auth.user?.name ?? 'Cashier',
                    size: 12, color: AppColors.goldLight),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 860;
          final crossCount = isLandscape
              ? (responsive.isTablet
                  ? (constraints.maxWidth >= 1100 ? 8 : 6)
                  : (constraints.maxWidth >= 760 ? 5 : 4))
              : (isWide ? 3 : 2);
          final menuSection = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isLandscape)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: AppColors.borderColor, width: 0.6),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () => _showCustomerSheet(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: pos.hasCustomer
                                  ? AppColors.bgLight
                                  : const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  pos.hasCustomer
                                      ? Icons.person_outline
                                      : Icons.person_add_outlined,
                                  size: 16,
                                  color: pos.hasCustomer
                                      ? AppColors.espresso
                                      : AppColors.goldDark,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: AppText(
                                    pos.hasCustomer
                                        ? pos.customerName
                                        : 'Customer',
                                    size: 12,
                                    weight: FontWeight.w600,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    color: pos.hasCustomer
                                        ? AppColors.espresso
                                        : AppColors.goldDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppColors.bgLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search,
                                  size: 18, color: AppColors.textMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: pos.setSearchQuery,
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.espresso),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    hintText: 'Search drink',
                                    hintStyle: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12),
                                    suffixIcon: pos.searchQuery.isNotEmpty
                                        ? IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.close,
                                                size: 16,
                                                color: AppColors.textMuted),
                                            onPressed: () {
                                              _searchCtrl.clear();
                                              pos.setSearchQuery('');
                                            },
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.espresso,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: hasItems
                              ? () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            _OrderSummaryPage(parent: this)),
                                  )
                              : null,
                          icon: const Icon(Icons.shopping_cart_outlined,
                              size: 16, color: AppColors.goldLight),
                          label: AppText(
                              '${pos.items.fold(0, (sum, item) => sum + item.qty)}',
                              size: 12,
                              color: AppColors.goldLight),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                if (!pos.hasCustomer)
                  GestureDetector(
                    onTap: () => _showCustomerSheet(context),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                          horizontal: isLandscape ? 14 : 20,
                          vertical: isLandscape ? 10 : 14),
                      margin: EdgeInsets.only(bottom: isLandscape ? 8 : 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.person_add_outlined,
                              size: 18, color: AppColors.gold),
                          SizedBox(width: 10),
                          Expanded(
                            child: AppText(
                              'Tap to enter customer name before ordering',
                              size: 13,
                              color: AppColors.goldDark,
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios,
                              size: 12, color: AppColors.gold),
                        ],
                      ),
                    ),
                  ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 12 : 16,
                      vertical: isLandscape ? 8 : 10),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: AppColors.borderColor, width: 0.6),
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: AppColors.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: pos.setSearchQuery,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.espresso),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search category or drink',
                            hintStyle:
                                const TextStyle(color: AppColors.textMuted),
                            suffixIcon: pos.searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close,
                                        size: 18, color: AppColors.textMuted),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      pos.setSearchQuery('');
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: isLandscape ? 8 : 12),
              if (pos.searchQuery.isEmpty)
                StreamBuilder<List<String>>(
                  stream: _menuSvc.categoriesStream(),
                  initialData: const [],
                  builder: (ctx, snap) {
                    final categories = snap.data ?? [];
                    final categoryTabs = ['All', ...categories];
                    return SizedBox(
                      height: isLandscape ? 36 : 52,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        itemCount: categoryTabs.length,
                    itemBuilder: (_, i) {
                      final cat = categoryTabs[i];
                      final active = pos.currentCategory == cat;
                      return GestureDetector(
                        onTap: () => pos.setCategory(cat),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          padding: EdgeInsets.symmetric(
                              horizontal: isLandscape ? 10 : 18,
                              vertical: isLandscape ? 6 : 12),
                          decoration: BoxDecoration(
                            color:
                                active ? AppColors.espresso : AppColors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: active
                                  ? AppColors.espresso
                                  : AppColors.borderColor,
                            ),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: AppColors.espresso
                                          .withValues(alpha: 20),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: AppText(
                              cat
                                  .replaceAll('Coffee-espresso base', 'Coffee')
                                  .replaceAll(
                                      'Lemonade-freshly squeeze', 'Lemonade'),
                              size: isLandscape ? 11 : 12,
                              weight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                              color: active
                                  ? AppColors.goldLight
                                  : AppColors.espresso,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
              SizedBox(height: isLandscape ? 6 : 10),
              Expanded(
                child: StreamBuilder<List<MenuItem>>(
                  stream: _menuSvc.menuStream(),
                  initialData: const [],
                  builder: (ctx, snap) {
                    if (snap.hasError) {
                      return const Center(
                        child: Text('Unable to load menu items.'),
                      );
                    }

                    final allItems = snap.data!;
                    final List<MenuItem> items;
                    if (pos.searchQuery.isNotEmpty) {
                      items = allItems
                          .where((i) => i.name
                              .toLowerCase()
                              .contains(pos.searchQuery.toLowerCase()))
                          .toList();
                    } else if (pos.currentCategory == 'All') {
                      items = _mergeMenuVariants(allItems);
                    } else {
                      items = allItems
                          .where((i) => i.category == pos.currentCategory)
                          .toList();
                    }

                    if (items.isEmpty) {
                      return const EmptyState(
                          message: 'No items found',
                          icon: Icons.search_off_outlined);
                    }

                    return GridView.builder(
                      padding: EdgeInsets.all(isLandscape ? 4 : 10),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossCount,
                        crossAxisSpacing: isLandscape ? 8 : 12,
                        mainAxisSpacing: isLandscape ? 8 : 12,
                        childAspectRatio: isLandscape
                            ? (responsive.isTablet ? 0.82 : 0.84)
                            : 0.9,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        return _MenuCard(
                          item: items[i],
                          onTap: () async {
                            if (!pos.hasCustomer) {
                              _showCustomerSheet(context);
                              return;
                            }
                            final menuItem = items[i];
                            final selectedSize = await _handleAddItem(menuItem, context, pos);
                            final shouldShowAddedMessage = selectedSize != null ||
                                menuItem.cupSizeType != CategoryCupSizeType.twelveAndSixteen;
                            if (shouldShowAddedMessage && context.mounted) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(selectedSize != null
                                      ? '${menuItem.name} ($selectedSize) added'
                                      : '${menuItem.name} (${menuItem.cupSize}) added'),
                                  duration: const Duration(milliseconds: 800),
                                  backgroundColor: AppColors.espresso,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );

          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: isLandscape ? 8 : 12,
              horizontal: isLandscape ? 8 : 12,
            ),
            child: Column(
              children: [
                Expanded(child: menuSection),
              ],
            ),
          );
        },
      ),
      floatingActionButton:
          shouldShowCartFab(isLandscape: isLandscape, hasItems: hasItems)
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => _OrderSummaryPage(parent: this)),
                    );
                  },
                  backgroundColor: AppColors.espresso,
                  label: Row(
                    children: [
                      const Icon(Icons.shopping_cart_outlined,
                          color: AppColors.goldLight),
                      const SizedBox(width: 8),
                      AppText(
                          '${pos.items.fold(0, (sum, item) => sum + item.qty)} items',
                          size: 13,
                          color: AppColors.goldLight),
                      const SizedBox(width: 8),
                      AppText(formatPHP(pos.total),
                          size: 13, color: AppColors.goldLight),
                    ],
                  ),
                )
              : null,
    );
  }
}

class _OrderSummaryPage extends StatefulWidget {
  final _PosScreenState parent;

  const _OrderSummaryPage({required this.parent});

  @override
  State<_OrderSummaryPage> createState() => _OrderSummaryPageState();
}

class _OrderSummaryPageState extends State<_OrderSummaryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pos = context.read<PosProvider>();
      if (pos.isEmpty) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final itemCount = pos.items.fold(0, (sum, item) => sum + item.qty);
    final selectedSugar = ['Regular sugar', '0%', '25%', '50%', '75%', '100%'];

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.espresso,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Back to cashier',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText('Order Summary',
                size: 18, weight: FontWeight.w700, color: Colors.white),
            AppText('$itemCount items', size: 12, color: Colors.white),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
                children: [
                  if (pos.isEmpty) ...[
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_bag_outlined,
                                size: 56, color: AppColors.borderColor),
                            SizedBox(height: 12),
                            AppText('No drinks added yet',
                                size: 14, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    ...pos.items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final menuItem = widget.parent._menuSvc
                          .getMenuItemById(item.menuItemId);
                      final categoryCupType = menuItem?.cupSizeType ?? CategoryCupSizeType.twelveAndSixteen;
                      final isCoffeeBase = categoryCupType == CategoryCupSizeType.twelveAndSixteen;
                      final isSnacks = categoryCupType == CategoryCupSizeType.regularAndMedium;
                      final sugarValue = selectedSugar.contains(item.sugarLevel)
                          ? item.sugarLevel
                          : 'Regular sugar';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: AppColors.borderColor, width: 0.6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: buildMenuItemImage(
                                        menuItem?.imagePath,
                                        menuItem?.imageBase64,
                                        menuItem?.imageMimeType,
                                        size: 56,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AppText(item.name,
                                            size: 15,
                                            weight: FontWeight.w800,
                                            color: AppColors.espresso,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                        if (menuItem != null) ...[
                                          const SizedBox(height: 4),
                                          AppText(menuItem.category,
                                              size: 12,
                                              color: AppColors.textMuted),
                                        ],
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            if ((isCoffeeBase || isSnacks) &&
                                                menuItem != null) ...[                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: AppColors.bgLight,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: AppText(
                                                    'Cup: ${item.cupSize}',
                                                    size: 11,
                                                    color: AppColors.textMuted),
                                              ),
                                            ],
                                            if (!isSnacks)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: AppColors.bgLight,
                                                  borderRadius:
                                                      BorderRadius.circular(999),
                                                ),
                                                child: AppText(
                                                    'Sugar: ${item.sugarLevel}',
                                                    size: 11,
                                                    color: AppColors.textMuted),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      pos.removeItem(index);
                                      if (mounted) setState(() {});
                                    },
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.red),
                                    tooltip: 'Remove item',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (isCoffeeBase && menuItem != null) ...[
                                const AppText('Cup size',
                                    size: 12, color: AppColors.textMuted),
                                const SizedBox(height: 6),
                                Row(
                                  children: ['12oz', '16oz'].map((size) {
                                    final selected = item.cupSize == size;
                                    final menuPrice = widget.parent._menuSvc
                                        .priceForCupSize(menuItem, size);
                                    return Expanded(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor: selected
                                                ? AppColors.espresso
                                                : AppColors.white,
                                            side: BorderSide(
                                                color: selected
                                                    ? AppColors.espresso
                                                    : AppColors.borderColor),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                          ),
                                          onPressed: () {
                                            pos.setItemCupSize(
                                                index,
                                                item.menuItemId,
                                                size,
                                                menuPrice);
                                            if (mounted) setState(() {});
                                          },
                                          child: AppText(size,
                                              size: 12,
                                              weight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: selected
                                                  ? AppColors.goldLight
                                                  : AppColors.espresso),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                              ] else if (isSnacks && menuItem != null) ...[
                                const AppText('Size',
                                    size: 12, color: AppColors.textMuted),
                                const SizedBox(height: 6),
                                Row(
                                  children: ['Regular', 'Medium'].map((size) {
                                    final selected = item.cupSize == size;
                                    final menuPrice = widget.parent._menuSvc
                                        .priceForCupSize(menuItem, size);
                                    return Expanded(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor: selected
                                                ? AppColors.espresso
                                                : AppColors.white,
                                            side: BorderSide(
                                                color: selected
                                                    ? AppColors.espresso
                                                    : AppColors.borderColor),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                          ),
                                          onPressed: () {
                                            pos.setItemCupSize(
                                                index,
                                                item.menuItemId,
                                                size,
                                                menuPrice);
                                            if (mounted) setState(() {});
                                          },
                                          child: AppText(size,
                                              size: 12,
                                              weight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: selected
                                                  ? AppColors.goldLight
                                                  : AppColors.espresso),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (!isSnacks) ...[
                                const AppText('Sugar level',
                                    size: 12, color: AppColors.textMuted),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgLight,
                                    borderRadius: BorderRadius.circular(14),
                                    border:
                                        Border.all(color: AppColors.borderColor),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: sugarValue,
                                      isExpanded: true,
                                      items: selectedSugar
                                          .map((level) => DropdownMenuItem(
                                              value: level,
                                              child: AppText(level,
                                                  size: 13,
                                                  color: AppColors.espresso)))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        pos.setItemSugarLevel(index, value);
                                        if (mounted) setState(() {});
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          pos.changeQty(index, -1);
                                          if (mounted) setState(() {});
                                        },
                                        icon: const Icon(
                                            Icons.remove_circle_outline_rounded,
                                            color: AppColors.espresso),
                                      ),
                                      AppText('${item.qty}',
                                          size: 15, weight: FontWeight.w700),
                                      IconButton(
                                        onPressed: () {
                                          pos.changeQty(index, 1);
                                          if (mounted) setState(() {});
                                        },
                                        icon: const Icon(
                                            Icons.add_circle_outline_rounded,
                                            color: AppColors.espresso),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const AppText('Subtotal',
                                          size: 12, color: AppColors.textMuted),
                                      AppText(formatPHP(item.price * item.qty),
                                          size: 15,
                                          weight: FontWeight.w700,
                                          color: AppColors.goldDark),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(18),
                      border:
                          Border.all(color: AppColors.borderColor, width: 0.6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppText('Order information',
                            size: 13, weight: FontWeight.w700),
                        const SizedBox(height: 12),
                        Row(
                          children: OrderType.values.map((type) {
                            final selected = widget.parent._orderType == type;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      widget.parent._orderType = type;
                                      setState(() {});
                                      widget.parent.setState(() {});
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? AppColors.espresso
                                            : AppColors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: selected
                                                ? AppColors.espresso
                                                : AppColors.borderColor,
                                            width: selected ? 2 : 1),
                                      ),
                                      child: Center(
                                        child: AppText(
                                          type == OrderType.dineIn
                                              ? 'Dine-In'
                                              : 'Take-Out',
                                          size: 13,
                                          weight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: selected
                                              ? AppColors.goldLight
                                              : AppColors.espresso,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: widget.parent._orderNotesCtrl,
                          maxLines: 3,
                          minLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Order notes',
                            filled: true,
                            fillColor: AppColors.bgLight,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppColors.borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppColors.borderColor),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.cream,
                border: Border(
                    top: BorderSide(color: AppColors.borderColor, width: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppText('Total drinks',
                                size: 12, color: AppColors.textMuted),
                            AppText('$itemCount',
                                size: 16,
                                weight: FontWeight.w700,
                                color: AppColors.espresso),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const AppText('Grand total',
                                size: 12, color: AppColors.textMuted),
                            AppText(formatPHP(pos.total),
                                size: 16,
                                weight: FontWeight.w700,
                                color: AppColors.goldDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const AppText('Continue ordering',
                              size: 14, weight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.espresso,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: pos.isEmpty
                              ? null
                              : () => widget.parent._processPayment(context),
                          child: const AppText('Place order',
                              size: 14,
                              weight: FontWeight.w700,
                              color: AppColors.goldLight),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;

  const _MenuCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final isLandscape = responsive.isLandscape;
    final menuSvc = MenuService();

    return GestureDetector(
      onTap: item.available ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: item.available ? AppColors.white : AppColors.bgLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderColor, width: 0.5),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(isLandscape ? 6 : 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: isLandscape ? 48 : 64,
                      height: isLandscape ? 48 : 64,
                      child: buildMenuItemImage(
                        item.imagePath,
                        item.imageBase64,
                        item.imageMimeType,
                        size: isLandscape ? 48 : 64,
                      ),
                    ),
                  ),
                  SizedBox(height: isLandscape ? 6 : 8),
                  SizedBox(
                    width: double.infinity,
                    child: AppText(item.name,
                        size: isLandscape ? 11 : 12,
                        weight: FontWeight.w800,
                        align: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        color: item.available
                            ? AppColors.espresso
                            : AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  AppText(formatPHP(menuSvc.displayPriceForMenuCard(item)),
                      size: isLandscape ? 10 : 11,
                      weight: FontWeight.w700,
                      color: item.available
                          ? AppColors.goldDark
                          : AppColors.textMuted),
                ],
              ),
            ),
            if (item.badge.isNotEmpty)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: AppText(item.badge,
                      size: 8,
                      weight: FontWeight.w600,
                      color: AppColors.espresso),
                ),
              ),
            if (!item.available)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: AppText('Unavailable',
                        size: 10, color: AppColors.textMuted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
