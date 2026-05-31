import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'recipe_service.dart';

class MenuService {
  final Box _menu = Hive.box('menu');
  final Uuid _uuid = const Uuid();

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

  Future<void> seedMenuIfEmpty() async {
    if (_menu.isNotEmpty) return;

    final seedData = [
      {
        'name': 'Spanish Khalifa 12oz',
        'price': 50.0,
        'icon': '☕',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Spanish Khalifa 16oz',
        'price': 80.0,
        'icon': '☕',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Caramel Macchiato 12oz',
        'price': 60.0,
        'icon': '☕',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Caramel Macchiato 16oz',
        'price': 80.0,
        'icon': '☕',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Himalayan Pink Salt 12oz',
        'price': 60.0,
        'icon': '☕',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Himalayan Pink Salt 16oz',
        'price': 80.0,
        'icon': '☕',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Flat White 12oz',
        'price': 60.0,
        'icon': '🤍',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Flat White 16oz',
        'price': 80.0,
        'icon': '🤍',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Long Black 12oz',
        'price': 50.0,
        'icon': '☕',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Long Black 16oz',
        'price': 80.0,
        'icon': '☕',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Choco Lava 12oz',
        'price': 60.0,
        'icon': '🍫',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Choco Lava 16oz',
        'price': 80.0,
        'icon': '🍫',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Matcha 12oz',
        'price': 60.0,
        'icon': '🍵',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Matcha 16oz',
        'price': 80.0,
        'icon': '🍵',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Strawberry Matcha 12oz',
        'price': 60.0,
        'icon': '🍓',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Strawberry Matcha 16oz',
        'price': 80.0,
        'icon': '🍓',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Chocolate',
        'price': 50.0,
        'icon': '🍫',
        'category': 'Cloud series',
        'badge': ''
      },
      {
        'name': 'Strawberry',
        'price': 50.0,
        'icon': '🍓',
        'category': 'Cloud series',
        'badge': ''
      },
      {
        'name': 'Matcha',
        'price': 50.0,
        'icon': '🍵',
        'category': 'Cloud series',
        'badge': ''
      },
      {
        'name': 'Cookies & Cream',
        'price': 50.0,
        'icon': '🍪',
        'category': 'Cloud series',
        'badge': ''
      },
      {
        'name': 'Cookies Matcha',
        'price': 50.0,
        'icon': '🍪',
        'category': 'Cloud series',
        'badge': ''
      },
      {
        'name': 'Strawberry Matcha',
        'price': 50.0,
        'icon': '🍓',
        'category': 'Cloud series',
        'badge': ''
      },
      {
        'name': 'Green Apple',
        'price': 50.0,
        'icon': '🍏',
        'category': 'Soda base',
        'badge': ''
      },
      {
        'name': 'Strawberry',
        'price': 50.0,
        'icon': '🍓',
        'category': 'Soda base',
        'badge': ''
      },
      {
        'name': 'Fresh Lemon',
        'price': 50.0,
        'icon': '🍋',
        'category': 'Lemonade-freshly squeeze',
        'badge': ''
      },
      {
        'name': 'Strawberry',
        'price': 50.0,
        'icon': '🍓',
        'category': 'Lemonade-freshly squeeze',
        'badge': ''
      },
    ];

    for (final item in seedData) {
      final id = _uuid.v4();
      await _menu.put(id, {
        ...item,
        'available': true,
        'id': id,
      });
    }
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

    if (existingName != null &&
        existingName.trim().isNotEmpty &&
        existingName.trim().toLowerCase() != item.name.trim().toLowerCase()) {
      return await RecipeService()
          .renameRecipeForMenuItem(existingName, item.name);
    }

    return false;
  }

  Future<void> deleteItem(String itemId) async {
    await _menu.delete(itemId);
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
    // Clear existing menu
    for (final key in _menu.keys.cast<dynamic>().toList()) {
      await _menu.delete(key);
    }

    final seedData = [
      // Coffee-espresso base (12oz and 16oz variants)
      {
        'name': 'Spanish Khalifa 12oz',
        'price': 50.0,
        'icon': '☕',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Spanish Khalifa 16oz',
        'price': 80.0,
        'icon': '☕',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Caramel Macchiato 12oz',
        'price': 60.0,
        'icon': '☕',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Caramel Macchiato 16oz',
        'price': 80.0,
        'icon': '☕',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Himalayan Pink Salt 12oz',
        'price': 60.0,
        'icon': '☕',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Himalayan Pink Salt 16oz',
        'price': 80.0,
        'icon': '☕',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Flat White 12oz',
        'price': 60.0,
        'icon': '🤍',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Flat White 16oz',
        'price': 80.0,
        'icon': '🤍',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Long Black 12oz',
        'price': 50.0,
        'icon': '☕',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Long Black 16oz',
        'price': 80.0,
        'icon': '☕',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Choco Lava 12oz',
        'price': 60.0,
        'icon': '🍫',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Choco Lava 16oz',
        'price': 80.0,
        'icon': '🍫',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Matcha 12oz',
        'price': 60.0,
        'icon': '🍵',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Matcha 16oz',
        'price': 80.0,
        'icon': '🍵',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Strawberry Matcha 12oz',
        'price': 60.0,
        'icon': '🍓',
        'category': 'Coffee-espresso base',
        'badge': ''
      },
      {
        'name': 'Strawberry Matcha 16oz',
        'price': 80.0,
        'icon': '🍓',
        'category': 'Coffee-espresso base',
        'badge': ''
      },

      // Cloud series
      {
        'name': 'Chocolate',
        'price': 50.0,
        'icon': '🍫',
        'category': 'Cloud series',
        'badge': ''
      },
      {
        'name': 'Strawberry',
        'price': 50.0,
        'icon': '🍓',
        'category': 'Cloud series',
        'badge': ''
      },
      {
        'name': 'Matcha',
        'price': 50.0,
        'icon': '🍵',
        'category': 'Cloud series',
        'badge': ''
      },
      {
        'name': 'Cookies & Cream',
        'price': 50.0,
        'icon': '🍪',
        'category': 'Cloud series',
        'badge': ''
      },
      {
        'name': 'Cookies Matcha',
        'price': 50.0,
        'icon': '🍪',
        'category': 'Cloud series',
        'badge': ''
      },
      {
        'name': 'Strawberry Matcha',
        'price': 50.0,
        'icon': '🍓',
        'category': 'Cloud series',
        'badge': ''
      },

      // Soda base
      {
        'name': 'Green Apple',
        'price': 50.0,
        'icon': '🍏',
        'category': 'Soda base',
        'badge': ''
      },
      {
        'name': 'Strawberry',
        'price': 50.0,
        'icon': '🍓',
        'category': 'Soda base',
        'badge': ''
      },

      // Lemonade
      {
        'name': 'Fresh Lemon',
        'price': 50.0,
        'icon': '🍋',
        'category': 'Lemonade-freshly squeeze',
        'badge': ''
      },
      {
        'name': 'Strawberry',
        'price': 50.0,
        'icon': '🍓',
        'category': 'Lemonade-freshly squeeze',
        'badge': ''
      },
    ];

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
