import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  static const categories = [
    'All', 'Raw Materials', 'Dairy', 'Dry Goods',
    'Syrups', 'Packaging', 'Pastries'
  ];

  @override
  void initState() {
    super.initState();
    _invSvc.seedInventoryIfEmpty();
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
      final matchCat = _categoryFilter == 'All' ||
          item.category == _categoryFilter;
      return matchSearch && matchCat;
    }).toList()
      ..sort((a, b) => a.stockStatus.index.compareTo(b.stockStatus.index));
  }

  void _showAddEditDialog(BuildContext context, {InventoryItem? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const AppText('Adjust Stock', size: 16, weight: FontWeight.w600),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bgLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(child: AppText(item.name, size: 13, weight: FontWeight.w500)),
                    AppText('${item.quantity} ${item.unit}',
                        size: 13, weight: FontWeight.w600, color: AppColors.goldDark),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setS(() => isAdd = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isAdd ? AppColors.green : AppColors.bgLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: AppText('+ Add Stock',
                              size: 12, weight: FontWeight.w600,
                              color: isAdd ? AppColors.white : AppColors.textMuted),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setS(() => isAdd = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isAdd ? AppColors.red : AppColors.bgLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: AppText('− Deduct',
                              size: 12, weight: FontWeight.w600,
                              color: !isAdd ? AppColors.white : AppColors.textMuted),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Quantity (${item.unit})',
                  prefixIcon: Icon(
                    isAdd ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    color: isAdd ? AppColors.green : AppColors.red,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AppText('Cancel', size: 13, color: AppColors.textMuted),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = double.tryParse(ctrl.text) ?? 0;
                if (val <= 0) return;
                await _invSvc.adjustStock(item.id, isAdd ? val : -val);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddEditDialog(context),
              tooltip: 'Add item',
            ),
        ],
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

          final lowStock = allItems.where((i) => i.stockStatus == StockStatus.low).length;
          final outOfStock = allItems.where((i) => i.stockStatus == StockStatus.outOfStock).length;

          return Column(
            children: [
              // Summary bar
              if (lowStock > 0 || outOfStock > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: const Color(0xFFFFF8E1),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_outlined,
                          size: 16, color: Color(0xFFE65100)),
                      const SizedBox(width: 8),
                      if (outOfStock > 0)
                        AppText('$outOfStock out of stock  ', size: 12,
                            color: AppColors.red, weight: FontWeight.w600),
                      if (lowStock > 0)
                        AppText('$lowStock low stock', size: 12,
                            color: const Color(0xFFE65100), weight: FontWeight.w600),
                    ],
                  ),
                ),

              // Search
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.all(10),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Search inventory…',
                    prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textMuted),
                  ),
                ),
              ),

              // Category filter
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
                          child: AppText(cat,
                              size: 11,
                              weight: active ? FontWeight.w600 : FontWeight.normal,
                              color: active ? AppColors.goldLight : AppColors.brown2),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    _MiniStat(label: 'Total Items', value: '${allItems.length}'),
                    const SizedBox(width: 8),
                    _MiniStat(label: 'Low Stock', value: '$lowStock',
                        color: const Color(0xFFE65100)),
                    const SizedBox(width: 8),
                    _MiniStat(label: 'Out of Stock', value: '$outOfStock',
                        color: AppColors.red),
                  ],
                ),
              ),

              // List
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        message: 'No items found',
                        icon: Icons.inventory_2_outlined)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 80),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _InventoryTile(
                          item: filtered[i],
                          isAdmin: isAdmin,
                          onAdjust: () => _showAdjustDialog(context, filtered[i]),
                          onEdit: () => _showAddEditDialog(context, item: filtered[i]),
                          onDelete: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete Item?'),
                                content: Text('Remove "${filtered[i].name}" from inventory?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Delete',
                                        style: TextStyle(color: AppColors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _invSvc.deleteItem(filtered[i].id);
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
                size: 16, weight: FontWeight.w700,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.stockStatus == StockStatus.outOfStock
              ? AppColors.red.withOpacity(0.3)
              : item.stockStatus == StockStatus.low
                  ? const Color(0xFFE65100).withOpacity(0.3)
                  : AppColors.borderColor,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 6,
            height: 48,
            decoration: BoxDecoration(
              color: _statusColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText(item.name,
                          size: 13, weight: FontWeight.w600),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: AppText(_statusLabel,
                          size: 10, weight: FontWeight.w700, color: _statusColor),
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
                    AppText('₱${item.costPerUnit.toStringAsFixed(2)}/${item.unit}',
                        size: 11, color: AppColors.textMuted),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    AppText('${item.quantity} ${item.unit}',
                        size: 15, weight: FontWeight.w700,
                        color: _statusColor),
                    AppText(' / ${item.lowStockThreshold} ${item.unit} threshold',
                        size: 10, color: AppColors.textMuted),
                  ],
                ),
                const SizedBox(height: 4),
                AppText('Served: ${item.servedQuantity.toStringAsFixed(1)} ${item.unit}',
                    size: 11, color: AppColors.textMuted),
              ],
            ),
          ),

          // Actions
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
                    child: const Icon(Icons.edit_outlined,
                        size: 16, color: AppColors.brown2),
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
                    child: const Icon(Icons.delete_outline,
                        size: 16, color: AppColors.red),
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
  String _category = 'Raw Materials';
  bool _saving = false;

  static const _categories = [
    'Raw Materials', 'Dairy', 'Dry Goods', 'Syrups', 'Packaging', 'Pastries'
  ];

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
    _category = item?.category ?? 'Raw Materials';
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
        id: widget.item?.id ?? '',
        name: _nameCtrl.text.trim(),
        unit: _unitCtrl.text.trim(),
        quantity: double.parse(_qtyCtrl.text),
        lowStockThreshold: double.parse(_thresholdCtrl.text),
        costPerUnit: double.parse(_costCtrl.text),
        category: _category,
      );
      await widget.onSave(newItem);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.item != null;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
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
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              AppText(isEdit ? 'Edit Inventory Item' : 'Add Inventory Item',
                  size: 16, weight: FontWeight.w600),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Item Name',
                controller: _nameCtrl,
                validator: (v) => v == null || v.isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Unit (kg, L, pcs…)',
                      controller: _unitCtrl,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      label: 'Current Qty',
                      controller: _qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null,
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      label: 'Cost per Unit (₱)',
                      controller: _costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null,
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
                    const AppText('Category', size: 12, color: AppColors.textMuted),
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
                              color: selected ? AppColors.espresso : AppColors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? AppColors.espresso : AppColors.borderColor,
                                width: 0.5,
                              ),
                            ),
                            child: AppText(cat,
                                size: 11,
                                weight: selected ? FontWeight.w600 : FontWeight.normal,
                                color: selected ? AppColors.goldLight : AppColors.espresso),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldLight)),
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
