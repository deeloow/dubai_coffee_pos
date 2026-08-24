import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/menu_service.dart';
import '../../services/auth_provider.dart';
import '../../services/local_order_socket_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

Widget buildMenuItemImage(String? imagePath, String? imageBase64, String? imageMimeType, {double size = 56}) {
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
    return Image.asset(resolvedPath, width: size, height: size, fit: BoxFit.cover);
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

class MenuScreen extends StatefulWidget {
  final Stream<List<MenuItem>>? menuStream;
  final bool? isAdminOverride;

  const MenuScreen({super.key, this.menuStream, this.isAdminOverride});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  MenuService? _menuSvc;
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  String _categoryFilter = 'All';
  List<String> _categories = ['All'];

  Future<void> _loadCategories() async {
    if (_menuSvc == null) return;
    final categories = await _menuSvc!.fetchCategoryNames();
    if (!mounted) return;
    setState(() {
      _categories = ['All', ...categories];
      if (!categories.contains(_categoryFilter) && _categoryFilter != 'All') {
        _categoryFilter = 'All';
      }
    });
  }

  Future<void> _deleteCategory(String categoryName) async {
    final menuService = _menuSvc ?? MenuService();
    final hasItems = await menuService.categoryHasMenuItems(categoryName);
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: DialogHeader(
          title: 'Delete Category?',
          onClose: () => Navigator.pop(dialogCtx, false),
        ),
        content: Text(
          hasItems
              ? 'This category contains menu items. Deleting the category may also remove or deactivate these items. Do you want to continue?'
              : 'Are you sure you want to delete "$categoryName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final categoryId = await menuService.resolveCategoryIdByName(categoryName);
    if (categoryId == null || categoryId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not find category: $categoryName')),
      );
      return;
    }

    await menuService.deleteCategory(categoryId);
    await _loadCategories();
    await _syncMenuWithPeers();
    if (!mounted) return;
    setState(() => _categoryFilter = 'All');
  }

  @override
  void initState() {
    super.initState();
    if (widget.menuStream == null) {
      _menuSvc = MenuService();
      _menuSvc!.seedMenuIfEmpty();
      _loadCategories();
    }
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

  Future<void> _syncMenuWithPeers() async {
    final socketProvider = context.read<LocalOrderSocketProvider>();
    final items = await _menuSvc!.fetchMenuItems();
    if (socketProvider.isConnected) {
      await socketProvider.sendMenuSync(items);
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    CategoryCupSizeType selectedType = CategoryCupSizeType.twelveAndSixteen;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: DialogHeader(
            title: 'Add Category',
            onClose: () => Navigator.pop(dialogCtx),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Cup Size', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                RadioListTile<CategoryCupSizeType>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: CategoryCupSizeType.twelveAndSixteen,
                  groupValue: selectedType,
                  title: const Text('12oz and 16oz'),
                  onChanged: (value) => setDialogState(() => selectedType = value ?? selectedType),
                ),
                RadioListTile<CategoryCupSizeType>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: CategoryCupSizeType.twelveOnly,
                  groupValue: selectedType,
                  title: const Text('12oz only'),
                  onChanged: (value) => setDialogState(() => selectedType = value ?? selectedType),
                ),
                RadioListTile<CategoryCupSizeType>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: CategoryCupSizeType.sixteenOnly,
                  groupValue: selectedType,
                  title: const Text('16oz only'),
                  onChanged: (value) => setDialogState(() => selectedType = value ?? selectedType),
                ),
                RadioListTile<CategoryCupSizeType>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: CategoryCupSizeType.regularAndMedium,
                  groupValue: selectedType,
                  title: const Text('Regular and Medium'),
                  onChanged: (value) => setDialogState(() => selectedType = value ?? selectedType),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Category name is required.')),
                  );
                  return;
                }
                Navigator.pop(dialogCtx, {'name': name, 'cupSizeType': selectedType});
              },
              child: const Text('Add Category'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final name = result['name'] as String? ?? '';
    final type = result['cupSizeType'] as CategoryCupSizeType? ?? CategoryCupSizeType.twelveAndSixteen;

    final error = await _menuSvc!.addCategory(name, type);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    await _loadCategories();
    await _syncMenuWithPeers();
    setState(() => _categoryFilter = name);
  }

  void _showAddEditDialog(BuildContext context, {MenuItem? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
          builder: (_) => _MenuFormSheet(
        item: item,
        onSave: (menuItem) async {
          if (item == null) {
            await _menuSvc!.addItem(menuItem);
          } else {
            await _menuSvc!.updateItem(menuItem);
          }
          if (mounted) {
            await _syncMenuWithPeers();
          }
          return false;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.isAdminOverride ?? context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Menu Management'),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: () => _showAddCategoryDialog(),
              tooltip: 'Add category',
            ),
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
                  final path = await _menuSvc!.exportToJsonFile();
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
                  barrierDismissible: false,
                  builder: (dialogCtx) => AlertDialog(
                    title: DialogHeader(
                      title: 'Reset Menu?',
                      onClose: () => Navigator.pop(dialogCtx, false),
                    ),
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
                    await _menuSvc!.replaceMenuWithStandardSeed();
                    await _syncMenuWithPeers();
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
        stream: widget.menuStream ?? _menuSvc!.menuStream(),
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
                color: AppColors.bgLight,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final selected = cat == _categoryFilter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() => _categoryFilter = cat),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 36),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.espresso
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: selected
                                      ? AppColors.espresso
                                      : AppColors.borderColor,
                                  width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppText(
                                  cat,
                                  size: 11,
                                  weight: selected
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: selected
                                      ? AppColors.goldLight
                                      : AppColors.brown2,
                                ),
                                if (cat != 'All' && isAdmin) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      await _deleteCategory(cat);
                                    },
                                    child: const Icon(Icons.close, size: 14, color: AppColors.red),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        message: 'No menu items found',
                        icon: Icons.menu_book_outlined)
                    : ListView(
                        padding: const EdgeInsets.all(10),
                        children: () {
                          final Map<String, List<MenuItem>> groups = {};
                          for (final it in filtered) {
                            final key = (it.category.trim().isEmpty)
                                ? 'Others'
                                : it.category.trim();
                            groups.putIfAbsent(key, () => []).add(it);
                          }

                          // Preserve order from _categories (except 'All'),
                          // then append any other categories alphabetically.
                          final List<String> orderedCats = [];
                          for (final c in _categories) {
                            if (c == 'All') continue;
                            if (groups.containsKey(c)) orderedCats.add(c);
                          }
                          final remaining = groups.keys
                              .where((k) => !orderedCats.contains(k))
                              .toList()
                            ..sort();
                          orderedCats.addAll(remaining);

                          final widgets = <Widget>[];
                          for (final cat in orderedCats) {
                            final items = groups[cat]!;
                            items.sort((a, b) => a.name.compareTo(b.name));
                            widgets.add(Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 4),
                              child: AppText(cat,
                                  size: 13, weight: FontWeight.w800),
                            ));
                            for (final item in items) {
                              widgets.add(Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.borderColor, width: 0.5),
                                ),
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: buildMenuItemImage(
                                        item.imagePath,
                                        item.imageBase64,
                                        item.imageMimeType,
                                        size: 56,
                                      ),
                                    ),
                                  ),
                                  title: AppText(item.name,
                                      size: 15,
                                      weight: FontWeight.w800,
                                      color: AppColors.espresso,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: AppText(
                                      '${item.category} • ${item.badge}',
                                      size: 12,
                                      color: AppColors.textMuted),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AppText('₱${(item.priceByCupSize['16oz'] ?? item.price).toStringAsFixed(2)}',
                                          size: 13,
                                          weight: FontWeight.w600),
                                      if (isAdmin) ...[
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 20),
                                          onPressed: () => _showAddEditDialog(
                                              context,
                                              item: item),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.delete_outline,
                                              size: 20),
                                          onPressed: () async {
                                            final confirmed =
                                                await showDialog<bool>(
                                              context: context,
                                              builder: (dialogContext) => AlertDialog(
                                                title: DialogHeader(
                                                  title: 'Delete Menu Item?',
                                                  onClose: () => Navigator.pop(dialogContext, false),
                                                ),
                                                content: Text(
                                                    'Remove "${item.name}" from the menu?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            dialogContext, false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            dialogContext, true),
                                                    child: const Text('Delete',
                                                        style: TextStyle(
                                                            color:
                                                                AppColors.red)),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirmed == true) {
                                              await _menuSvc!.deleteItem(item.id);
                                              await _syncMenuWithPeers();
                                            }
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ));
                            }
                          }
                          return widgets;
                        }(),
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
  late final TextEditingController _price12Ctrl;
  late final TextEditingController _price16Ctrl;
  late final TextEditingController _priceRegularCtrl;
  late final TextEditingController _priceMediumCtrl;
  late final TextEditingController _badgeCtrl;
  File? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  bool _isPickingImage = false;
  bool _clearImageRequested = false;
  String _category = 'Coffee-espresso base';
  bool _available = true;
  bool _saving = false;

  List<String> _categories = ['Coffee-espresso base'];

  List<String> _defaultCupSizesForCategory(String category) {
    return MenuItem.inferDefaultCupSizeType(category).availableSizes;
  }

  Future<CategoryCupSizeType> _resolveCategoryCupType(String category) async {
    if (category.trim().isEmpty) {
      return CategoryCupSizeType.twelveAndSixteen;
    }
    return MenuService().categoryCupSizeType(category);
  }

  CategoryCupSizeType _selectedCupType = CategoryCupSizeType.twelveAndSixteen;

  bool get _isSnacksCategory => _selectedCupType == CategoryCupSizeType.regularAndMedium;

  bool get _is16ozOnlyCategory => _selectedCupType == CategoryCupSizeType.sixteenOnly;

  Future<void> _applyCategoryConfiguration(String categoryName) async {
    final type = await MenuService().categoryCupSizeType(categoryName);
    if (!mounted) return;
    setState(() {
      _category = categoryName;
      _selectedCupType = type;
      _nameCtrl.clear();
      _price12Ctrl.clear();
      _price16Ctrl.clear();
      _priceRegularCtrl.clear();
      _priceMediumCtrl.clear();
    });
  }

  String? _validatePriceValue(String? value, {required String label}) {
    final cleaned = value?.trim() ?? '';
    if (cleaned.isEmpty) {
      return 'Please enter a valid $label price.';
    }

    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed < 0) {
      return 'Please enter a valid numeric price.';
    }

    return null;
  }

  double _parsePriceValue(String? value, {required String label}) {
    final cleaned = value?.trim() ?? '';
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed < 0) {
      throw FormatException('Invalid $label price: "$value"');
    }
    return parsed;
  }

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _price12Ctrl = TextEditingController(
      text: item?.priceByCupSize['12oz']?.toStringAsFixed(2) ?? item?.price.toStringAsFixed(2) ?? '',
    );
    _price16Ctrl = TextEditingController(
      text: item?.priceByCupSize['16oz']?.toStringAsFixed(2) ?? item?.price.toStringAsFixed(2) ?? '',
    );
    _priceRegularCtrl = TextEditingController(
      text: item?.priceByCupSize['Regular']?.toStringAsFixed(2) ?? item?.price.toStringAsFixed(2) ?? '',
    );
    _priceMediumCtrl = TextEditingController(
      text: item?.priceByCupSize['Medium']?.toStringAsFixed(2) ?? item?.price.toStringAsFixed(2) ?? '',
    );
    _badgeCtrl = TextEditingController(text: item?.badge ?? '');
    _loadCategories();
    _category = item?.category ?? 'Coffee-espresso base';
    _selectedCupType = item?.cupSizeType ?? MenuItem.inferDefaultCupSizeType(_category);
    _available = item?.available ?? true;
  }

  Future<void> _loadCategories() async {
    final names = await MenuService().fetchCategoryNames();
    if (!mounted) return;
    setState(() {
      _categories = names;
      final validCategory = names.contains(_category) ? _category : (names.isNotEmpty ? names.first : 'Coffee-espresso base');
      if (validCategory != _category) {
        _category = validCategory;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _price12Ctrl.dispose();
    _price16Ctrl.dispose();
    _priceRegularCtrl.dispose();
    _priceMediumCtrl.dispose();
    _badgeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _isPickingImage = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg'],
        allowMultiple: false,
      );
      final platformFile = result?.files.single;
      final extension = (platformFile?.extension ?? '').toLowerCase();
      if (platformFile != null && !{'png', 'jpg', 'jpeg'}.contains(extension)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a PNG, JPG, or JPEG image.')),
          );
        }
        return;
      }
      if (platformFile != null) {
        setState(() {
          _selectedImageFile = platformFile.path != null && platformFile.path!.isNotEmpty
              ? File(platformFile.path!)
              : null;
          _selectedImageBytes = platformFile.bytes;
          _clearImageRequested = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final categoryCupType = await MenuService().categoryCupSizeType(_category);
      final resolvedSizes = categoryCupType.availableSizes;
      final resolvedCupSize = resolvedSizes.first;
      MenuImageData? imageData;
      String? nextImagePath;
      String? nextImageBase64;
      String? nextImageMimeType;

      final menuService = MenuService();

      if (_clearImageRequested) {
        if (widget.item != null && widget.item!.id.isNotEmpty) {
          await menuService.clearMenuImage(widget.item!.id, previousPath: widget.item?.imagePath);
        }
        nextImagePath = MenuItem.defaultDrinkImageAsset;
        nextImageBase64 = null;
        nextImageMimeType = null;
      } else if (_selectedImageBytes != null) {
        imageData = await MenuService().saveMenuImageBytes(
          _selectedImageBytes!,
          menuItemId: widget.item?.id,
          previousPath: widget.item?.imagePath,
        );
        nextImagePath = imageData?.path;
        nextImageBase64 = imageData?.base64;
        nextImageMimeType = imageData?.mimeType;
      } else if (_selectedImageFile != null) {
        imageData = await MenuService().saveMenuImage(
          _selectedImageFile!,
          menuItemId: widget.item?.id,
          previousPath: widget.item?.imagePath,
        );
        nextImagePath = imageData?.path;
        nextImageBase64 = imageData?.base64;
        nextImageMimeType = imageData?.mimeType;
      } else {
        nextImagePath = widget.item?.imagePath ?? MenuItem.defaultDrinkImageAsset;
        nextImageBase64 = widget.item?.imageBase64;
        nextImageMimeType = widget.item?.imageMimeType;
      }

      final existing = widget.item;
      final isCoffeeBase = categoryCupType == CategoryCupSizeType.twelveAndSixteen;
      final isSnacks = categoryCupType == CategoryCupSizeType.regularAndMedium;
      final is16ozOnly = categoryCupType == CategoryCupSizeType.sixteenOnly;
      final is12ozOnly = categoryCupType == CategoryCupSizeType.twelveOnly;

      late Map<String, double> priceByCupSize;
      late double mainPrice;

      if (isCoffeeBase) {
        final price12Error = _validatePriceValue(_price12Ctrl.text, label: '12oz');
        final price16Error = _validatePriceValue(_price16Ctrl.text, label: '16oz');
        if (price12Error != null || price16Error != null) {
          final message = price12Error ?? price16Error ?? 'Please enter a valid numeric price.';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), backgroundColor: AppColors.red),
            );
          }
          return;
        }

        final price12 = _parsePriceValue(_price12Ctrl.text, label: '12oz');
        final price16 = _parsePriceValue(_price16Ctrl.text, label: '16oz');
        priceByCupSize = {'12oz': price12, '16oz': price16};
        mainPrice = price16;
      } else if (isSnacks) {
        final priceRegularError = _validatePriceValue(_priceRegularCtrl.text, label: 'Regular');
        final priceMediumError = _validatePriceValue(_priceMediumCtrl.text, label: 'Medium');
        if (priceRegularError != null || priceMediumError != null) {
          final message = priceRegularError ?? priceMediumError ?? 'Please enter a valid numeric price.';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), backgroundColor: AppColors.red),
            );
          }
          return;
        }

        final priceRegular = _parsePriceValue(_priceRegularCtrl.text, label: 'Regular');
        final priceMedium = _parsePriceValue(_priceMediumCtrl.text, label: 'Medium');
        priceByCupSize = {'Regular': priceRegular, 'Medium': priceMedium};
        mainPrice = priceMedium;
      } else if (is16ozOnly) {
        final price16Error = _validatePriceValue(_price16Ctrl.text, label: '16oz');
        if (price16Error != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(price16Error), backgroundColor: AppColors.red),
            );
          }
          return;
        }

        final price16 = _parsePriceValue(_price16Ctrl.text, label: '16oz');
        priceByCupSize = {'16oz': price16};
        mainPrice = price16;
      } else if (is12ozOnly) {
        final price12Error = _validatePriceValue(_price12Ctrl.text, label: '12oz');
        if (price12Error != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(price12Error), backgroundColor: AppColors.red),
            );
          }
          return;
        }

        final price12 = _parsePriceValue(_price12Ctrl.text, label: '12oz');
        priceByCupSize = {'12oz': price12};
        mainPrice = price12;
      }
      final menuItem = MenuItem(
        id: existing?.id ?? '',
        name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : (existing?.name ?? ''),
        price: mainPrice,
        icon: existing?.icon ?? '☕',
        category: _category,
        badge: _badgeCtrl.text.trim(),
        cupSizeType: categoryCupType,
        cupSize: resolvedCupSize,
        availableCupSizes: resolvedSizes,
        priceByCupSize: priceByCupSize,
        imagePath: nextImagePath,
        imageBase64: nextImageBase64,
        imageMimeType: nextImageMimeType,
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
    final categoryCupType = _selectedCupType;
    final isCoffeeBase = categoryCupType == CategoryCupSizeType.twelveAndSixteen;
    final isSnacks = categoryCupType == CategoryCupSizeType.regularAndMedium;
    final is16ozOnly = categoryCupType == CategoryCupSizeType.sixteenOnly;
    final is12ozOnly = categoryCupType == CategoryCupSizeType.twelveOnly;
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
            DialogHeader(
              title: isEditing ? 'Edit Menu Item' : 'Add Menu Item',
              onClose: () => Navigator.pop(context),
            ),
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
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories
                        .map((category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ))
                        .toList(),
                    onChanged: (value) async {
                      if (value != null) {
                        await _applyCategoryConfiguration(value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  if (isCoffeeBase) ...[
                    TextFormField(
                      controller: _price12Ctrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '12oz Price'),
                      validator: (value) => _validatePriceValue(value, label: '12oz'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _price16Ctrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '16oz Price'),
                      validator: (value) => _validatePriceValue(value, label: '16oz'),
                    ),
                  ] else if (isSnacks) ...[
                    TextFormField(
                      controller: _priceRegularCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Regular Price'),
                      validator: (value) => _validatePriceValue(value, label: 'Regular'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _priceMediumCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Medium Price'),
                      validator: (value) => _validatePriceValue(value, label: 'Medium'),
                    ),
                  ] else if (is16ozOnly) ...[
                    TextFormField(
                      controller: _price16Ctrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '16oz Price'),
                      validator: (value) => _validatePriceValue(value, label: '16oz'),
                    ),
                  ] else if (is12ozOnly) ...[
                    TextFormField(
                      controller: _price12Ctrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '12oz Price'),
                      validator: (value) => _validatePriceValue(value, label: '12oz'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppColors.bgLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: 96,
                              height: 96,
                              child: _selectedImageBytes != null
                                  ? Image.memory(
                                      _selectedImageBytes!,
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                    )
                                  : buildMenuItemImage(
                                      _clearImageRequested
                                          ? null
                                          : (_selectedImageFile?.path ?? widget.item?.imagePath),
                                      _clearImageRequested
                                          ? null
                                          : (_selectedImageFile != null ? null : widget.item?.imageBase64),
                                      _clearImageRequested
                                          ? null
                                          : widget.item?.imageMimeType,
                                      size: 96,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _isPickingImage ? null : _pickImage,
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('Upload image'),
                              ),
                              if (_selectedImageFile != null || _selectedImageBytes != null || widget.item?.imagePath != null || _clearImageRequested) ...[
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => setState(() {
                                    _selectedImageFile = null;
                                    _selectedImageBytes = null;
                                    _clearImageRequested = true;
                                  }),
                                  child: const Text('Clear'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _badgeCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Badge (optional)'),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Text(
                      categoryCupType == CategoryCupSizeType.twelveAndSixteen
                          ? 'Cup size is selected when the drink is added to the cart.'
                          : categoryCupType == CategoryCupSizeType.regularAndMedium
                          ? 'Size (Regular/Medium) is selected when the item is added to the cart.'
                          : categoryCupType == CategoryCupSizeType.sixteenOnly
                          ? '16oz is the only available size for this category.'
                          : '12oz is the only available size for this category.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
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
