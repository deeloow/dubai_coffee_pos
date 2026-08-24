import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/inventory_service.dart';
import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final InventoryService _invSvc = InventoryService();
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _categoryFilter = 'All';

  static const categories = ['All', 'Packaging'];

  @override
  void initState() {
    super.initState();
    // Inventory seeding is now handled by MainShell for admin mode only
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<InventoryItem> _filter(List<InventoryItem> items) {
    return items.where((item) {
      final matchSearch = _search.isEmpty ||
          item.name.toLowerCase().contains(_search) ||
          item.category.toLowerCase().contains(_search);
      final matchCat =
          _categoryFilter == 'All' || item.category == _categoryFilter;
      return matchSearch && matchCat;
    }).toList()
      ..sort((a, b) => a.stockStatus.index.compareTo(b.stockStatus.index));
  }

  void _showAddEditDialog(BuildContext context, {InventoryItem? item}) {
    final isLandscape = ResponsiveLayout.of(context).isLandscape;

    if (isLandscape) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
            child: _InventoryFormSheet(
              item: item,
              onSave: (newItem) async {
                if (item == null) {
                  await _invSvc.addItem(newItem);
                } else {
                  await _invSvc.updateItem(newItem);
                }
              },
            ),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _InventoryFormSheet(
        item: item,
        onSave: (newItem) async {
          if (item == null) {
            await _invSvc.addItem(newItem);
          } else {
            await _invSvc.updateItem(newItem);
          }
        },
      ),
    );
  }

  void _showAdjustDialog(BuildContext context, InventoryItem item) {
    final ctrl = TextEditingController();
    bool isAdd = true;
    final isLandscape = ResponsiveLayout.of(context).isLandscape;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final maxHeight = MediaQuery.of(context).size.height * 0.86;

          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: keyboardHeight > 0 ? keyboardHeight + 12 : 20,
            ),
            child: MediaQuery.removeViewInsets(
              removeBottom: true,
              context: context,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isLandscape ? 420 : 560, maxHeight: maxHeight),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DialogHeader(
                                    title: 'Adjust Stock',
                                    titleSize: 16,
                                    titleWeight: FontWeight.w600,
                                    onClose: () => Navigator.pop(ctx),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(child: AppText(item.name, size: 13, weight: FontWeight.w500)),
                                        AppText('${item.quantity} ${item.unit}', size: 13, weight: FontWeight.w600, color: AppColors.goldDark),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setS(() => isAdd = true),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 9),
                                            decoration: BoxDecoration(
                                              color: isAdd ? AppColors.green : AppColors.bgLight,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: AppText('+ Add Stock', size: 12, weight: FontWeight.w600, color: isAdd ? AppColors.white : AppColors.textMuted),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setS(() => isAdd = false),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 9),
                                            decoration: BoxDecoration(
                                              color: !isAdd ? AppColors.red : AppColors.bgLight,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Center(
                                              child: AppText('− Deduct', size: 12, weight: FontWeight.w600, color: !isAdd ? AppColors.white : AppColors.textMuted),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: ctrl,
                                    autofocus: true,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Quantity (${item.unit})',
                                      prefixIcon: Icon(isAdd ? Icons.add_circle_outline : Icons.remove_circle_outline, color: isAdd ? AppColors.green : AppColors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const AppText('Cancel', size: 13, color: AppColors.textMuted),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton(
                                  onPressed: () async {
                                    final val = double.tryParse(ctrl.text) ?? 0;
                                    if (val <= 0) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please enter a valid quantity'), backgroundColor: AppColors.red),
                                        );
                                      }
                                      return;
                                    }

                                    if (!isAdd && (item.quantity - val) < 0) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Cannot deduct more than available (${item.quantity} ${item.unit})'), backgroundColor: AppColors.red),
                                        );
                                      }
                                      return;
                                    }

                                    await _invSvc.adjustStock(item.id, isAdd ? val : -val);
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Stock ${isAdd ? 'added' : 'deducted'} successfully'), backgroundColor: AppColors.green),
                                      );
                                    }
                                  },
                                  child: const Text('Confirm'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final responsive = ResponsiveLayout.of(context);
    final isLandscape = responsive.isLandscape;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        toolbarHeight: isLandscape ? 46 : 56,
        title: const Text('Inventory'),
        actions: isAdmin && !isLandscape
            ? [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddEditDialog(context),
                  tooltip: 'Add item',
                ),
              ]
            : null,
      ),
      body: StreamBuilder<List<InventoryItem>>(
        stream: _invSvc.inventoryStream(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold)),
            );
          }

          final allItems = snap.data!;
          final filtered = _filter(allItems);

          final lowStock =
              allItems.where((i) => i.stockStatus == StockStatus.low).length;
          final outOfStock = allItems
              .where((i) => i.stockStatus == StockStatus.outOfStock)
              .length;

          final header = isLandscape
              ? Container(
                  color: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _search = v.toLowerCase()),
                            decoration: InputDecoration(
                              hintText: 'Search inventory…',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.goldDark, width: 1.2),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 220,
                        height: 38,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          itemBuilder: (_, i) {
                            final cat = categories[i];
                            final active = _categoryFilter == cat;
                            return GestureDetector(
                              onTap: () => setState(() => _categoryFilter = cat),
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: active ? AppColors.espresso : AppColors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: active ? AppColors.espresso : AppColors.borderColor,
                                    width: 0.5,
                                  ),
                                ),
                                child: Center(
                                  child: AppText(
                                    cat,
                                    size: 10,
                                    weight: active ? FontWeight.w600 : FontWeight.normal,
                                    color: active ? AppColors.goldLight : AppColors.brown2,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          if (isAdmin)
                            FilledButton.icon(
                              onPressed: () => _showAddEditDialog(context),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.espresso,
                                foregroundColor: AppColors.goldLight,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                minimumSize: const Size(0, 38),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          if (isAdmin) const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Clear filters',
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _search = '';
                                _categoryFilter = 'All';
                              });
                            },
                            icon: const Icon(Icons.filter_alt_off_outlined),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (lowStock > 0 || outOfStock > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        color: const Color(0xFFFFF8E1),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_outlined, size: 16, color: Color(0xFFE65100)),
                            const SizedBox(width: 8),
                            if (outOfStock > 0)
                              AppText('$outOfStock out of stock  ', size: 12, color: AppColors.red, weight: FontWeight.w600),
                            if (lowStock > 0)
                              AppText('$lowStock low stock', size: 12, color: const Color(0xFFE65100), weight: FontWeight.w600),
                          ],
                        ),
                      ),
                    Container(
                      color: AppColors.white,
                      padding: const EdgeInsets.all(10),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _search = v.toLowerCase()),
                        decoration: const InputDecoration(
                          hintText: 'Search inventory…',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        itemCount: categories.length,
                        itemBuilder: (_, i) {
                          final cat = categories[i];
                          final active = _categoryFilter == cat;
                          return GestureDetector(
                            onTap: () => setState(() => _categoryFilter = cat),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: active ? AppColors.espresso : AppColors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: active ? AppColors.espresso : AppColors.borderColor,
                                  width: 0.5,
                                ),
                              ),
                              child: Center(
                                child: AppText(
                                  cat,
                                  size: 11,
                                  weight: active ? FontWeight.w600 : FontWeight.normal,
                                  color: active ? AppColors.goldLight : AppColors.brown2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                      child: Row(
                        children: [
                          _MiniStat(label: 'Total Items', value: '${allItems.length}'),
                          const SizedBox(width: 8),
                          _MiniStat(label: 'Low Stock', value: '$lowStock', color: const Color(0xFFE65100)),
                          const SizedBox(width: 8),
                          _MiniStat(label: 'Out of Stock', value: '$outOfStock', color: AppColors.red),
                        ],
                      ),
                    ),
                  ],
                );

          return Column(
            children: [
              header,
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        message: 'No items found',
                        icon: Icons.inventory_2_outlined,
                      )
                    : isLandscape
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final crossAxisCount = width >= 1600
                                  ? 6
                                  : width >= 1200
                                      ? 5
                                      : width >= 900
                                          ? 4
                                          : width >= 700
                                              ? 3
                                              : 2;
                              final childAspectRatio = width >= 1600
                                  ? 2.8
                                  : width >= 1200
                                      ? 2.4
                                      : width >= 900
                                          ? 2.0
                                          : width >= 700
                                              ? 1.7
                                              : 1.3;

                              return GridView.builder(
                                padding: EdgeInsets.fromLTRB(6, 4, 6, 8 + MediaQuery.of(context).viewInsets.bottom),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 4,
                                  mainAxisSpacing: 4,
                                  childAspectRatio: childAspectRatio,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (_, i) => _InventoryTile(
                                  item: filtered[i],
                                  isAdmin: isAdmin,
                                  onAdjust: () => _showAdjustDialog(context, filtered[i]),
                                  onEdit: () => _showAddEditDialog(context, item: filtered[i]),
                                  onDelete: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title: DialogHeader(
                                          title: 'Delete Item?',
                                          onClose: () => Navigator.pop(dialogContext, false),
                                        ),
                                        content: Text('Remove "${filtered[i].name}" from inventory?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dialogContext, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(dialogContext, true),
                                            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _invSvc.deleteItem(filtered[i].id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Inventory item deleted successfully'),
                                            backgroundColor: AppColors.red,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                          )
                        : ListView.builder(
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(10, 8, 10, 80 + MediaQuery.of(context).viewInsets.bottom),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _InventoryTile(
                              item: filtered[i],
                              isAdmin: isAdmin,
                              onAdjust: () => _showAdjustDialog(context, filtered[i]),
                              onEdit: () => _showAddEditDialog(context, item: filtered[i]),
                              onDelete: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: DialogHeader(
                                      title: 'Delete Item?',
                                      onClose: () => Navigator.pop(dialogContext, false),
                                    ),
                                    content: Text('Remove "${filtered[i].name}" from inventory?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext, true),
                                        child: const Text('Delete', style: TextStyle(color: AppColors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _invSvc.deleteItem(filtered[i].id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Inventory item deleted successfully'),
                                        backgroundColor: AppColors.red,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _MiniStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderColor, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(value,
                size: 16,
                weight: FontWeight.w700,
                color: color ?? AppColors.espresso),
            AppText(label, size: 10, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  final InventoryItem item;
  final bool isAdmin;
  final VoidCallback onAdjust;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InventoryTile({
    required this.item,
    required this.isAdmin,
    required this.onAdjust,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _statusColor {
    switch (item.stockStatus) {
      case StockStatus.outOfStock:
        return AppColors.red;
      case StockStatus.low:
        return const Color(0xFFE65100);
      case StockStatus.inStock:
        return AppColors.green;
    }
  }

  String get _statusLabel {
    switch (item.stockStatus) {
      case StockStatus.outOfStock:
        return 'Out';
      case StockStatus.low:
        return 'Low';
      case StockStatus.inStock:
        return 'OK';
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final isLandscape = responsive.isLandscape;

    final actionButtons = <Widget>[
      GestureDetector(
        onTap: onAdjust,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.bgLight,
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(Icons.tune, size: 16, color: AppColors.espresso),
        ),
      ),
      if (isAdmin) ...[
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onEdit,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.bgLight,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.brown2),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onDelete,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFFCEBEB),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.delete_outline, size: 16, color: AppColors.red),
          ),
        ),
      ],
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 7 : 12,
        vertical: isLandscape ? 4 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.stockStatus == StockStatus.outOfStock
              ? AppColors.red.withValues(alpha: 0.3)
              : item.stockStatus == StockStatus.low
                  ? const Color(0xFFE65100).withValues(alpha: 0.3)
                  : AppColors.borderColor,
          width: 0.5,
        ),
      ),
      child: isLandscape
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 3,
                  height: isLandscape ? 18 : 48,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              item.name,
                              size: 10,
                              weight: FontWeight.w600,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: AppText(
                              _statusLabel,
                              size: 8,
                              weight: FontWeight.w700,
                              color: _statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      AppText('${item.quantity} ${item.unit}', size: 9, weight: FontWeight.w700, color: _statusColor),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Row(mainAxisSize: MainAxisSize.min, children: actionButtons),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 6,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(item.name, size: 13, weight: FontWeight.w600),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: AppText(_statusLabel,
                                size: 10,
                                weight: FontWeight.w700,
                                color: _statusColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          AppText(item.category, size: 11, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          const AppText('•', size: 11, color: AppColors.borderColor),
                          const SizedBox(width: 8),
                          AppText('₱${item.costPerUnit.toStringAsFixed(2)}/${item.unit}', size: 11, color: AppColors.textMuted),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          AppText('${item.quantity} ${item.unit}', size: 15, weight: FontWeight.w700, color: _statusColor),
                          AppText(' / ${item.lowStockThreshold} ${item.unit} threshold', size: 10, color: AppColors.textMuted),
                        ],
                      ),
                      const SizedBox(height: 4),
                      AppText('Served: ${item.servedQuantity.toStringAsFixed(1)} ${item.unit}', size: 11, color: AppColors.textMuted),
                    ],
                  ),
                ),
                Column(
                  children: [
                    GestureDetector(
                      onTap: onAdjust,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.bgLight,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(Icons.tune, size: 16, color: AppColors.espresso),
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: onEdit,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.bgLight,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.brown2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCEBEB),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.delete_outline, size: 16, color: AppColors.red),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
    );
  }
}

// ─── Add/Edit Inventory Form Sheet ────────────────────────────────────────────

class _InventoryFormSheet extends StatefulWidget {
  final InventoryItem? item;
  final Future<void> Function(InventoryItem) onSave;

  const _InventoryFormSheet({this.item, required this.onSave});

  @override
  State<_InventoryFormSheet> createState() => _InventoryFormSheetState();
}

class _InventoryFormSheetState extends State<_InventoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _thresholdCtrl;
  late final TextEditingController _costCtrl;
  String _category = 'Packaging';
  bool _saving = false;

  static const _categories = ['Packaging'];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _unitCtrl = TextEditingController(text: item?.unit ?? 'pcs');
    _qtyCtrl = TextEditingController(
        text: item != null ? item.quantity.toString() : '');
    _thresholdCtrl = TextEditingController(
        text: item != null ? item.lowStockThreshold.toString() : '');
    _costCtrl = TextEditingController(
        text: item != null ? item.costPerUnit.toString() : '');
    _category = item?.category ?? 'Packaging';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _qtyCtrl.dispose();
    _thresholdCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final newItem = InventoryItem(
        id: widget.item?.id ?? '', // Preserve the ID if editing
        name: _nameCtrl.text.trim(),
        unit: _unitCtrl.text.trim(),
        quantity: double.parse(_qtyCtrl.text),
        servedQuantity: widget.item?.servedQuantity ?? 0.0,
        lowStockThreshold: double.parse(_thresholdCtrl.text),
        costPerUnit: double.parse(_costCtrl.text),
        category: _category,
      );

      // Validate quantity is not negative
      if (newItem.quantity < 0) {
        throw Exception('Quantity cannot be negative');
      }

      // Validate threshold is not negative
      if (newItem.lowStockThreshold < 0) {
        throw Exception('Low stock threshold cannot be negative');
      }

      final isEditing = widget.item != null;
      await widget.onSave(newItem);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Inventory item updated successfully'
                : 'Inventory item added successfully'),
            backgroundColor: AppColors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.item != null;
    final isLandscape = ResponsiveLayout.of(context).isLandscape;

    return Container(
      margin: isLandscape ? const EdgeInsets.all(0) : const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + bottom),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              DialogHeader(
                title: isEdit ? 'Edit Inventory Item' : 'Add Inventory Item',
                onClose: () => Navigator.pop(context),
              ),
              SizedBox(height: isLandscape ? 12 : 16),

              AppTextField(
                label: 'Item Name',
                controller: _nameCtrl,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Unit (kg, L, pcs…)',
                      controller: _unitCtrl,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      label: 'Current Qty',
                      controller: _qtyCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) =>
                          double.tryParse(v ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Low Stock Threshold',
                      controller: _thresholdCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) =>
                          double.tryParse(v ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      label: 'Cost per Unit (₱)',
                      controller: _costCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) =>
                          double.tryParse(v ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Category picker
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderColor, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText('Category',
                        size: 12, color: AppColors.textMuted),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _categories.map((cat) {
                        final selected = _category == cat;
                        return GestureDetector(
                          onTap: () => setState(() => _category = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.espresso
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? AppColors.espresso
                                    : AppColors.borderColor,
                                width: 0.5,
                              ),
                            ),
                            child: AppText(cat,
                                size: 11,
                                weight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: selected
                                    ? AppColors.goldLight
                                    : AppColors.espresso),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.goldLight)),
                        )
                      : Text(isEdit ? 'Save Changes' : 'Add Item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
