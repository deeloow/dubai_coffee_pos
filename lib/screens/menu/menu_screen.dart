import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/menu_service.dart';
import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final MenuService _menuSvc = MenuService();
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  String _categoryFilter = 'All';

  static const _categories = [
    'All',
    'Coffee-espresso base',
    'Cloud series',
    'Soda base',
    'Lemonade-freshly squeeze'
  ];

  @override
  void initState() {
    super.initState();
    _menuSvc.seedMenuIfEmpty();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MenuItem> _filtered(List<MenuItem> items) {
    return items.where((item) {
      final lower = item.name.toLowerCase();
      final searchLower = _search.toLowerCase();
      final matchesSearch = _search.isEmpty ||
          lower.contains(searchLower) ||
          item.category.toLowerCase().contains(searchLower);
      final matchesCategory =
          _categoryFilter == 'All' || item.category == _categoryFilter;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  void _showAddEditDialog(BuildContext context, {MenuItem? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MenuFormSheet(
        item: item,
        onSave: (menuItem) async {
          if (item == null) {
            await _menuSvc.addItem(menuItem);
            return false;
          }
          return await _menuSvc.updateItem(menuItem);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Menu Management'),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddEditDialog(context),
              tooltip: 'Add menu item',
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final path = await _menuSvc.exportToJsonFile();
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Menu exported to $path')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Export failed: $e')),
                  );
                }
              },
              tooltip: 'Export menu to JSON',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Reset Menu?'),
                    content: const Text(
                        'This will remove all existing menu items and replace them with the default menu. Continue?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          child: const Text('Reset')),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await _menuSvc.replaceMenuWithStandardSeed();
                    if (!mounted) return;
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Menu reset to default.')));
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                        SnackBar(content: Text('Reset failed: $e')));
                  }
                }
              },
              tooltip: 'Reset menu to default',
            ),
          ],
        ],
      ),
      body: StreamBuilder<List<MenuItem>>(
        stream: _menuSvc.menuStream(),
        initialData: const [],
        builder: (ctx, snap) {
          if (snap.hasError) {
            return const Center(
              child: Text('Unable to load menu management data.'),
            );
          }
          final allItems = snap.data!;
          final filtered = _filtered(allItems);
          return Column(
            children: [
              Container(
                color: AppColors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (value) => setState(() => _search = value),
                  decoration: InputDecoration(
                    hintText: 'Search menu…',
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.textMuted),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: AppColors.textMuted),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
              ),
              Container(
                height: 42,
                color: AppColors.bgLight,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: _categories.length,
                  itemBuilder: (_, index) {
                    final cat = _categories[index];
                    final selected = cat == _categoryFilter;
                    return GestureDetector(
                      onTap: () => setState(() => _categoryFilter = cat),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              selected ? AppColors.espresso : AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: selected
                                  ? AppColors.espresso
                                  : AppColors.borderColor,
                              width: 0.5),
                        ),
                        child: AppText(cat,
                            size: 11,
                            weight:
                                selected ? FontWeight.w700 : FontWeight.normal,
                            color: selected
                                ? AppColors.goldLight
                                : AppColors.brown2),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        message: 'No menu items found',
                        icon: Icons.menu_book_outlined)
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: filtered.length,
                        itemBuilder: (_, index) {
                          final item = filtered[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.borderColor, width: 0.5),
                            ),
                            child: ListTile(
                              leading: Text(item.icon,
                                  style: const TextStyle(fontSize: 26)),
                              title: AppText(item.name,
                                  size: 14, weight: FontWeight.w700),
                              subtitle: AppText(
                                  '${item.category} • ${item.badge}',
                                  size: 12,
                                  color: AppColors.textMuted),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppText('₱${item.price.toStringAsFixed(2)}',
                                      size: 13, weight: FontWeight.w600),
                                  if (isAdmin) ...[
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 20),
                                      onPressed: () => _showAddEditDialog(
                                          context,
                                          item: item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 20),
                                      onPressed: () async {
                                        final confirmed =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title:
                                                const Text('Delete Menu Item?'),
                                            content: Text(
                                                'Remove "${item.name}" from the menu?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, true),
                                                child: const Text('Delete',
                                                    style: TextStyle(
                                                        color: AppColors.red)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          await _menuSvc.deleteItem(item.id);
                                        }
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
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

class _MenuFormSheet extends StatefulWidget {
  final MenuItem? item;
  final Future<bool> Function(MenuItem) onSave;

  const _MenuFormSheet({this.item, required this.onSave});

  @override
  State<_MenuFormSheet> createState() => _MenuFormSheetState();
}

class _MenuFormSheetState extends State<_MenuFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _iconCtrl;
  late final TextEditingController _badgeCtrl;
  String _category = 'Coffee-espresso base';
  bool _available = true;
  bool _saving = false;

  static const _categories = [
    'Coffee-espresso base',
    'Cloud series',
    'Soda base',
    'Lemonade-freshly squeeze'
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _priceCtrl =
        TextEditingController(text: item?.price.toStringAsFixed(2) ?? '');
    _iconCtrl = TextEditingController(text: item?.icon ?? '☕');
    _badgeCtrl = TextEditingController(text: item?.badge ?? '');
    _category = item?.category ?? _categories.first;
    _available = item?.available ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _iconCtrl.dispose();
    _badgeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final menuItem = MenuItem(
        id: widget.item?.id ?? '',
        name: _nameCtrl.text.trim(),
        price: double.parse(_priceCtrl.text),
        icon: _iconCtrl.text.trim(),
        category: _category,
        badge: _badgeCtrl.text.trim(),
        available: _available,
      );
      final recipeRemapped = await widget.onSave(menuItem);
      if (mounted && recipeRemapped) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recipe remapped to "${menuItem.name}".'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.item != null;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isEditing ? 'Edit Menu Item' : 'Add Menu Item',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => value?.trim().isEmpty == true
                        ? 'Enter a menu name'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price'),
                    validator: (value) {
                      final price = double.tryParse(value ?? '');
                      if (price == null || price < 0) {
                        return 'Enter a valid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _iconCtrl,
                    decoration: const InputDecoration(labelText: 'Icon'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _badgeCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Badge (optional)'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories
                        .map((category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _category = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: _available,
                    onChanged: (value) => setState(() => _available = value),
                    title: const AppText('Available for sale'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(isEditing ? 'Save changes' : 'Add item'),
            ),
          ],
        ),
      ),
    );
  }
}
