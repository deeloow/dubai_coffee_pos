import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../models/models.dart';
import 'recipe_service.dart';

class MenuImageData {
  final String path;
  final String base64;
  final String mimeType;

  const MenuImageData({required this.path, required this.base64, required this.mimeType});
}

class MenuService {
  final Box _menu = Hive.box('menu');
  final Box _categoryBox = Hive.box('menu_categories');
  final Uuid _uuid = const Uuid();

  Map<String, String> _defaultCategoryCupConfigs() {
    final map = <String, String>{};
    for (final category in MenuData.categories) {
      final name = (category['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      map[name.toLowerCase()] = MenuItem.inferDefaultCupSizeType(name).persistedValue;
    }
    return map;
  }

  List<String> _defaultCategoryNames() {
    final names = MenuData.categories
        .map((category) => (category['name'] as String? ?? '').trim())
        .where((name) => name.isNotEmpty)
        .toList();

    final seen = <String>{};
    final ordered = <String>[];
    for (final name in names) {
      final normalized = name.toLowerCase();
      if (!seen.contains(normalized)) {
        seen.add(normalized);
        ordered.add(name);
      }
    }
    return ordered;
  }

  Future<Map<String, String>> _readCategoryCupConfigs() async {
    final stored = _categoryBox.get('category_cup_size_types');
    if (stored is Map) {
      final values = <String, String>{};
      stored.forEach((key, value) {
        final normalizedKey = (key ?? '').toString().trim().toLowerCase();
        final normalizedValue = value?.toString() ?? '';
        if (normalizedKey.isNotEmpty && normalizedValue.isNotEmpty) {
          values[normalizedKey] = normalizedValue;
        }
      });
      return values;
    }
    final defaults = _defaultCategoryCupConfigs();
    await _categoryBox.put('category_cup_size_types', defaults);
    return defaults;
  }

  Future<CategoryCupSizeType> categoryCupSizeType(String categoryName) async {
    final sanitized = categoryName.trim();
    if (sanitized.isEmpty) {
      return CategoryCupSizeType.twelveAndSixteen;
    }

    final configs = await _readCategoryCupConfigs();
    final value = configs[sanitized.toLowerCase()];
    if (value == null || value.isEmpty) {
      return MenuItem.inferDefaultCupSizeType(sanitized);
    }

    return CategoryCupSizeTypeX.fromPersisted(value);
  }

  Future<List<String>> fetchCategoryNames() async {
    final existing = _categoryBox.get('category_names');
    final defaults = _defaultCategoryNames();

    if (existing is List) {
      final parsed = existing
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      final merged = <String>[];
      final seen = <String>{};
      for (final name in [...defaults, ...parsed]) {
        final normalized = name.toLowerCase();
        if (!seen.contains(normalized)) {
          seen.add(normalized);
          merged.add(name);
        }
      }
      if (merged.isNotEmpty && (existing is! List || parsed.isEmpty || parsed.length != merged.length)) {
        await _categoryBox.put('category_names', merged);
      }
      if (_categoryBox.get('category_cup_size_types') is! Map) {
        final configs = _defaultCategoryCupConfigs();
        for (final name in merged) {
          configs.putIfAbsent(name.toLowerCase(), () => MenuItem.inferDefaultCupSizeType(name).persistedValue);
        }
        await _categoryBox.put('category_cup_size_types', configs);
      }
      return merged;
    }

    await _categoryBox.put('category_names', defaults);
    final configs = _defaultCategoryCupConfigs();
    await _categoryBox.put('category_cup_size_types', configs);
    return defaults;
  }

  Future<String?> addCategory(String categoryName, [CategoryCupSizeType? cupSizeType]) async {
    final sanitized = categoryName.trim();
    if (sanitized.isEmpty) {
      return 'Category name is required.';
    }

    final categories = await fetchCategoryNames();
    if (categories.any((name) => name.toLowerCase() == sanitized.toLowerCase())) {
      return 'This category already exists.';
    }

    final resolvedType = cupSizeType ?? MenuItem.inferDefaultCupSizeType(sanitized);
    final updated = [...categories, sanitized];
    final configs = await _readCategoryCupConfigs();
    final records = Map<String, dynamic>.from(_categoryBox.get('category_records') as Map? ?? {});
    final categoryId = _uuid.v4();
    records[categoryId] = {
      'id': categoryId,
      'name': sanitized,
      'cupSizeType': resolvedType.persistedValue,
    };
    configs[sanitized.toLowerCase()] = resolvedType.persistedValue;
    await _categoryBox.put('category_names', updated);
    await _categoryBox.put('category_cup_size_types', configs);
    await _categoryBox.put('category_records', records);
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchCategoryEntries() async {
    final records = Map<String, dynamic>.from(_categoryBox.get('category_records') as Map? ?? {});
    final names = await fetchCategoryNames();
    final resolved = <Map<String, dynamic>>[];
    final existingNames = <String>{};

    for (final entry in records.values) {
      final map = Map<String, dynamic>.from(entry as Map);
      final name = (map['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      if (existingNames.add(name.toLowerCase())) {
        resolved.add({'id': map['id'] ?? _uuid.v4(), 'name': name, 'cupSizeType': map['cupSizeType'] ?? MenuItem.inferDefaultCupSizeType(name).persistedValue});
      }
    }

    for (final name in names) {
      final normalized = name.toLowerCase();
      if (existingNames.contains(normalized)) continue;
      final type = await categoryCupSizeType(name);
      final id = _uuid.v4();
      resolved.add({'id': id, 'name': name, 'cupSizeType': type.persistedValue});
      records[id] = {'id': id, 'name': name, 'cupSizeType': type.persistedValue};
    }

    if (records.isNotEmpty) {
      await _categoryBox.put('category_records', records);
    }

    return resolved;
  }

  Future<void> replaceCategoriesWithEntries(
      List<Map<String, dynamic>> entries) async {
    final names = <String>[];
    final records = <String, dynamic>{};
    final configs = <String, String>{};
    final seenIds = <String>{};
    final seenNames = <String>{};

    for (final entry in entries) {
      final name = (entry['name']?.toString() ?? '').trim();
      if (name.isEmpty || !seenNames.add(name.toLowerCase())) continue;

      var id = (entry['id']?.toString() ?? '').trim();
      if (id.isEmpty || !seenIds.add(id)) {
        id = _uuid.v4();
        seenIds.add(id);
      }
      final cupSizeType = (entry['cupSizeType']?.toString() ??
              MenuItem.inferDefaultCupSizeType(name).persistedValue)
          .trim();

      names.add(name);
      configs[name.toLowerCase()] = cupSizeType;
      records[id] = {
        'id': id,
        'name': name,
        'cupSizeType': cupSizeType,
      };
    }

    await _categoryBox.put('category_names', names);
    await _categoryBox.put('category_cup_size_types', configs);
    await _categoryBox.put('category_records', records);
  }

  Future<String?> resolveCategoryIdByName(String categoryName) async {
    final sanitized = categoryName.trim();
    if (sanitized.isEmpty) return null;
    final entries = await fetchCategoryEntries();
    for (final entry in entries) {
      final name = (entry['name'] as String? ?? '').trim();
      if (name.toLowerCase() == sanitized.toLowerCase()) {
        return entry['id']?.toString();
      }
    }
    return null;
  }

  Future<bool> categoryHasMenuItems(String categoryName) async {
    final sanitized = categoryName.trim();
    if (sanitized.isEmpty) return false;
    for (final entry in _menu.values.cast<Map>()) {
      final map = Map<String, dynamic>.from(entry);
      final name = (map['category'] as String? ?? '').trim();
      if (name.toLowerCase() == sanitized.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  Future<void> deleteCategory(String categoryId) async {
    final records = Map<String, dynamic>.from(_categoryBox.get('category_records') as Map? ?? {});
    final target = records[categoryId];
    if (target == null) return;

    final categoryName = (target['name'] as String? ?? '').trim();
    if (categoryName.isNotEmpty) {
      final menuEntries = _menu.values.cast<Map>().toList();
      for (final entry in menuEntries) {
        final map = Map<String, dynamic>.from(entry);
        final currentCategory = (map['category'] as String? ?? '').trim();
        if (currentCategory.toLowerCase() == categoryName.toLowerCase()) {
          await _menu.delete(map['id']);
        }
      }

      final names = (await fetchCategoryNames())
          .where((name) => name.toLowerCase() != categoryName.toLowerCase())
          .toList();
      final configs = await _readCategoryCupConfigs();
      configs.remove(categoryName.toLowerCase());
      await _categoryBox.put('category_names', names);
      await _categoryBox.put('category_cup_size_types', configs);
    }

    records.remove(categoryId);
    await _categoryBox.put('category_records', records);
  }

  Future<void> deleteCategoryByName(String categoryName) async {
    final categoryId = await resolveCategoryIdByName(categoryName);
    if (categoryId == null || categoryId.isEmpty) return;
    await deleteCategory(categoryId);
  }

  Stream<List<String>> categoriesStream() async* {
    yield await fetchCategoryNames();

    await for (final _ in _categoryBox.watch()) {
      yield await fetchCategoryNames();
    }
  }

  Stream<List<MenuItem>> menuStream() async* {
    yield _menu.values
        .cast<Map>()
        .map((item) => MenuItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    await for (final _ in _menu.watch()) {
      yield _menu.values
          .cast<Map>()
          .map((item) => MenuItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }
  }

  MenuItem? getMenuItemById(String id) {
    try {
      return _menu.values
          .cast<Map>()
          .map((item) => MenuItem.fromMap(Map<String, dynamic>.from(item)))
          .firstWhere((menuItem) => menuItem.id == id);
    } catch (_) {
      return null;
    }
  }

  double priceForCupSize(MenuItem menuItem, String cupSize) {
    final latestMenuItem = menuItem.id.isNotEmpty ? getMenuItemById(menuItem.id) : null;
    final resolvedMenuItem = latestMenuItem ?? menuItem;
    final normalizedCupSize = (cupSize.isNotEmpty ? cupSize : resolvedMenuItem.cupSize).trim();
    final mappedPrice = resolvedMenuItem.priceByCupSize[normalizedCupSize];
    if (mappedPrice != null) {
      return mappedPrice;
    }

    final type = resolvedMenuItem.cupSizeType;
    switch (type) {
      case CategoryCupSizeType.twelveAndSixteen:
        return resolvedMenuItem.priceByCupSize['12oz'] ??
            resolvedMenuItem.priceByCupSize['16oz'] ??
            resolvedMenuItem.price;
      case CategoryCupSizeType.twelveOnly:
        return resolvedMenuItem.priceByCupSize['12oz'] ?? resolvedMenuItem.price;
      case CategoryCupSizeType.sixteenOnly:
        return resolvedMenuItem.priceByCupSize['16oz'] ?? resolvedMenuItem.price;
      case CategoryCupSizeType.regularAndMedium:
        return resolvedMenuItem.priceByCupSize['Regular'] ??
            resolvedMenuItem.priceByCupSize['Medium'] ??
            resolvedMenuItem.price;
    }
  }

  double displayPriceForMenuCard(MenuItem menuItem) {
    final latestMenuItem = menuItem.id.isNotEmpty ? getMenuItemById(menuItem.id) : null;
    final resolvedMenuItem = latestMenuItem ?? menuItem;

    switch (resolvedMenuItem.cupSizeType) {
      case CategoryCupSizeType.twelveAndSixteen:
        return resolvedMenuItem.priceByCupSize['12oz'] ?? resolvedMenuItem.price;
      case CategoryCupSizeType.twelveOnly:
        return resolvedMenuItem.priceByCupSize['12oz'] ?? resolvedMenuItem.price;
      case CategoryCupSizeType.sixteenOnly:
        return resolvedMenuItem.priceByCupSize['16oz'] ?? resolvedMenuItem.price;
      case CategoryCupSizeType.regularAndMedium:
        return resolvedMenuItem.priceByCupSize['Regular'] ?? resolvedMenuItem.price;
    }
  }

  Future<MenuImageData?> saveMenuImageBytes(
    List<int> bytes, {
    String? menuItemId,
    String? previousPath,
  }) async {
    try {
      final bytesData = Uint8List.fromList(bytes);
      final decoded = img.decodeImage(bytesData);
      if (decoded == null) {
        return null;
      }

      final resized = img.copyResize(
        decoded,
        width: 600,
        height: 600,
        maintainAspect: true,
      );

      final square = img.Image(width: 600, height: 600);
      final offsetX = (600 - resized.width) ~/ 2;
      final offsetY = (600 - resized.height) ~/ 2;
      for (var y = 0; y < square.height; y++) {
        for (var x = 0; x < square.width; x++) {
          square.setPixel(x, y, img.ColorRgb8(255, 255, 255));
        }
      }
      for (var y = 0; y < resized.height; y++) {
        for (var x = 0; x < resized.width; x++) {
          final pixel = resized.getPixel(x, y);
          square.setPixel(offsetX + x, offsetY + y, pixel);
        }
      }

      final supportDir = await getApplicationSupportDirectory();
      final safeId = (menuItemId ?? _uuid.v4()).replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final target = File('${supportDir.path}/menu_images/$safeId.jpg');
      await target.create(recursive: true);
      final encoded = img.encodeJpg(square, quality: 85);
      await target.writeAsBytes(encoded, flush: true);

      if (previousPath != null && previousPath.isNotEmpty && previousPath != target.path) {
        try {
          final previousFile = File(previousPath);
          if (previousFile.existsSync()) {
            await previousFile.delete();
          }
        } catch (_) {}
      }

      return MenuImageData(
        path: target.path,
        base64: base64Encode(encoded),
        mimeType: 'image/jpeg',
      );
    } catch (_) {
      return null;
    }
  }

  Future<MenuImageData?> saveMenuImage(
    File source, {
    String? menuItemId,
    String? previousPath,
  }) async {
    final bytes = await source.readAsBytes();
    return saveMenuImageBytes(bytes, menuItemId: menuItemId, previousPath: previousPath);
  }

  Future<List<Map<String, dynamic>>> _buildDefaultSeedData() async {
    final seedData = <Map<String, dynamic>>[];

    for (final category in MenuData.categories) {
      final categoryName = category['name'] as String? ?? '';
      final items = category['items'] as List<dynamic>? ?? const <dynamic>[];

      for (final item in items) {
        final itemMap = Map<String, dynamic>.from(item as Map);
        final name = itemMap['name'] as String? ?? '';
        final price = (itemMap['price'] as num).toDouble();
        final icon = itemMap['icon'] as String? ?? '☕';
        final badge = itemMap['badge'] as String? ?? '';

        final cupType = MenuItem.inferDefaultCupSizeType(categoryName);
        final priceByCupSize = switch (cupType) {
          CategoryCupSizeType.twelveAndSixteen => {'12oz': 60.0, '16oz': 80.0},
          CategoryCupSizeType.twelveOnly => {'12oz': price},
          CategoryCupSizeType.sixteenOnly => {'16oz': price},
          CategoryCupSizeType.regularAndMedium => {'Regular': price, 'Medium': price},
        };

        seedData.add({
          'name': name,
          'price': price,
          'icon': icon,
          'category': categoryName,
          'badge': badge,
          'priceByCupSize': priceByCupSize,
          'imagePath': MenuItem.defaultDrinkImageAsset,
          'imageBase64': null,
          'imageMimeType': null,
        });
      }
    }

    return seedData;
  }

  bool _hasLegacyCoffeeSizeVariants(List<MenuItem> items) {
    return items.any((item) {
      if (item.cupSizeType != CategoryCupSizeType.twelveAndSixteen) {
        return false;
      }
      final normalized = item.name.toLowerCase();
      return normalized.endsWith('12oz') || normalized.endsWith('16oz') || normalized.contains(' 12oz') || normalized.contains(' 16oz');
    });
  }

  Future<void> seedMenuIfEmpty() async {
    if (_menu.isNotEmpty) {
      final existingItems = _menu.values
          .cast<Map>()
          .map((item) => MenuItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      if (!_hasLegacyCoffeeSizeVariants(existingItems)) {
        return;
      }
    }

    await replaceMenuWithStandardSeed();
  }

  Future<List<MenuItem>> fetchMenuItems() async {
    return _menu.values
        .cast<Map>()
        .map((item) => MenuItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> toggleAvailability(String itemId, bool available) async {
    final map = _menu.get(itemId);
    if (map == null) return;
    final updated = Map<String, dynamic>.from(map as Map);
    updated['available'] = available;
    await _menu.put(itemId, updated);
  }

  Future<void> addItem(MenuItem item) async {
    final id = item.id.isEmpty ? _uuid.v4() : item.id;
    await _menu.put(id, {...item.toMap(), 'id': id});
    await _createRecipeForMenuItem(item.copyWith(id: id));
  }

  Future<bool> updateItem(MenuItem item) async {
    if (item.id.isEmpty) {
      await addItem(item);
      return false;
    }

    final existingMap = _menu.get(item.id);
    final existingName = existingMap != null
        ? (Map<String, dynamic>.from(existingMap as Map)['name'] as String?)
        : null;

    await _menu.put(item.id, {...item.toMap(), 'id': item.id});
    await _updateRecipeForMenuItem(item);

    if (existingName != null &&
        existingName.trim().isNotEmpty &&
        existingName.trim().toLowerCase() != item.name.trim().toLowerCase()) {
      return await RecipeService()
          .renameRecipeForMenuItem(existingName, item.name);
    }

    return false;
  }

  Future<void> _createRecipeForMenuItem(MenuItem item) async {
    final recipeService = RecipeService();
    await recipeService.createRecipeForMenuItem(item);
  }

  Future<void> _updateRecipeForMenuItem(MenuItem item) async {
    final recipeService = RecipeService();
    await recipeService.updateRecipeForMenuItem(item);
  }

  Future<void> clearMenuImage(String itemId, {String? previousPath}) async {
    final existingMap = _menu.get(itemId);
    if (existingMap == null) return;

    final updatedMap = Map<String, dynamic>.from(existingMap as Map)
      ..['imagePath'] = MenuItem.defaultDrinkImageAsset
      ..['imageBase64'] = null
      ..['imageMimeType'] = null;

    await _menu.put(itemId, updatedMap..['id'] = itemId);

    if (previousPath != null && previousPath.isNotEmpty) {
      try {
        final previousFile = File(previousPath);
        if (previousFile.existsSync()) {
          await previousFile.delete();
        }
      } catch (_) {}
    }
  }

  Future<void> deleteItem(String itemId) async {
    await _menu.delete(itemId);
  }

  Future<void> replaceMenuWithItems(List<MenuItem> items) async {
    final existingIdsByKey = <String, String>{};
    for (final entry in _menu.values.cast<Map>()) {
      final existing = MenuItem.fromMap(Map<String, dynamic>.from(entry));
      final key = '${existing.name.trim().toLowerCase()}::${existing.category.trim().toLowerCase()}';
      existingIdsByKey[key] = existing.id;
    }

    for (final key in _menu.keys.cast<dynamic>().toList()) {
      await _menu.delete(key);
    }

    for (final item in items) {
      final key = '${item.name.trim().toLowerCase()}::${item.category.trim().toLowerCase()}';
      final resolvedId = item.id.isNotEmpty ? item.id : (existingIdsByKey[key] ?? '');
      final id = resolvedId.isEmpty ? const Uuid().v4() : resolvedId;
      await _menu.put(id, {...item.toMap(), 'id': id});
    }
  }

  /// Export menu box contents to a JSON file in application documents directory.
  /// Returns the full path of the exported file.
  Future<String> exportToJsonFile() async {
    final items = _menu.values
        .cast<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    final dir = await getApplicationDocumentsDirectory();
    final safeTs = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/menu_dump_$safeTs.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(items));
    return file.path;
  }

  /// Replace the entire menu with the standard seed provided by the app.
  /// This will delete all existing menu entries.
  Future<void> replaceMenuWithStandardSeed() async {
    for (final entry in _menu.values.cast<Map>()) {
      final existing = MenuItem.fromMap(Map<String, dynamic>.from(entry));
      if (existing.hasCustomImage && existing.imagePath != null && existing.imagePath!.isNotEmpty) {
        final imageFile = File(existing.imagePath!);
        if (imageFile.existsSync() && !existing.imagePath!.startsWith('assets/')) {
          try {
            await imageFile.delete();
          } catch (_) {}
        }
      }
    }

    for (final key in _menu.keys.cast<dynamic>().toList()) {
      await _menu.delete(key);
    }

    await _categoryBox.put('category_names', _defaultCategoryNames());

    final seedData = await _buildDefaultSeedData();

    for (final item in seedData) {
      final id = _uuid.v4();
      await _menu.put(id, {
        ...item,
        'available': true,
        'id': id,
      });
    }
  }
}
