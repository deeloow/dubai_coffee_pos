import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
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
      {'name': 'Espresso', 'price': 89.0, 'icon': '☕', 'category': 'Hot Coffee', 'badge': ''},
      {'name': 'Americano', 'price': 99.0, 'icon': '🫖', 'category': 'Hot Coffee', 'badge': ''},
      {'name': 'Cappuccino', 'price': 129.0, 'icon': '☕', 'category': 'Hot Coffee', 'badge': 'Best'},
      {'name': 'Latte', 'price': 129.0, 'icon': '🥛', 'category': 'Hot Coffee', 'badge': ''},
      {'name': 'Macchiato', 'price': 119.0, 'icon': '☕', 'category': 'Hot Coffee', 'badge': ''},
      {'name': 'Flat White', 'price': 119.0, 'icon': '🤍', 'category': 'Hot Coffee', 'badge': ''},
      {'name': 'Dubai Karak', 'price': 109.0, 'icon': '🌿', 'category': 'Hot Coffee', 'badge': 'Local'},
      {'name': 'Café Mocha', 'price': 139.0, 'icon': '🍫', 'category': 'Hot Coffee', 'badge': ''},
      {'name': 'Hazelnut Latte', 'price': 149.0, 'icon': '🌰', 'category': 'Hot Coffee', 'badge': 'New'},
      {'name': 'Iced Americano', 'price': 109.0, 'icon': '🧊', 'category': 'Cold Drinks', 'badge': ''},
      {'name': 'Cold Brew', 'price': 139.0, 'icon': '🧋', 'category': 'Cold Drinks', 'badge': 'Best'},
      {'name': 'Iced Latte', 'price': 139.0, 'icon': '🥤', 'category': 'Cold Drinks', 'badge': ''},
      {'name': 'Iced Mocha', 'price': 149.0, 'icon': '🍫', 'category': 'Cold Drinks', 'badge': ''},
      {'name': 'Frappuccino', 'price': 159.0, 'icon': '🧋', 'category': 'Cold Drinks', 'badge': 'New'},
      {'name': 'Lemon Soda', 'price': 89.0, 'icon': '🍋', 'category': 'Cold Drinks', 'badge': ''},
      {'name': 'Croissant', 'price': 89.0, 'icon': '🥐', 'category': 'Pastries', 'badge': ''},
      {'name': 'Muffin', 'price': 79.0, 'icon': '🧁', 'category': 'Pastries', 'badge': ''},
      {'name': 'Cheesecake', 'price': 129.0, 'icon': '🍰', 'category': 'Pastries', 'badge': 'Best'},
      {'name': 'Banana Bread', 'price': 99.0, 'icon': '🍞', 'category': 'Pastries', 'badge': ''},
      {'name': 'Cinnamon Roll', 'price': 109.0, 'icon': '🌀', 'category': 'Pastries', 'badge': 'New'},
      {'name': 'Butter Cookie', 'price': 59.0, 'icon': '🍪', 'category': 'Pastries', 'badge': ''},
      {'name': 'Extra Shot', 'price': 30.0, 'icon': '⚡', 'category': 'Add-ons', 'badge': ''},
      {'name': 'Oat Milk', 'price': 40.0, 'icon': '🌾', 'category': 'Add-ons', 'badge': ''},
      {'name': 'Vanilla Syrup', 'price': 25.0, 'icon': '🍯', 'category': 'Add-ons', 'badge': ''},
      {'name': 'Caramel Drizzle', 'price': 25.0, 'icon': '🍮', 'category': 'Add-ons', 'badge': ''},
      {'name': 'Whipped Cream', 'price': 20.0, 'icon': '🍦', 'category': 'Add-ons', 'badge': ''},
      {'name': 'Sugar-free', 'price': 20.0, 'icon': '🌿', 'category': 'Add-ons', 'badge': ''},
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

    if (existingName != null && existingName.trim().isNotEmpty &&
        existingName.trim().toLowerCase() != item.name.trim().toLowerCase()) {
      return await RecipeService().renameRecipeForMenuItem(existingName, item.name);
    }

    return false;
  }

  Future<void> deleteItem(String itemId) async {
    await _menu.delete(itemId);
  }
}
