import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class RecipeService {
  final Box _recipes = Hive.box('recipes');
  final Box _inventory = Hive.box('inventory');
  final Uuid _uuid = const Uuid();

  // Get all recipes
  Future<List<Recipe>> getAllRecipes() async {
    return _recipes.values
        .cast<Map>()
        .map((item) => Recipe.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  // Get recipe by menu item name
  Future<Recipe?> getRecipeByMenuItemName(String menuItemName) async {
    final normalized = _normalizeMenuName(menuItemName);
    try {
      final recipes = _recipes.values
          .cast<Map>()
          .map((item) => Recipe.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      final exactMatch = recipes.firstWhere(
        (r) => _normalizeMenuName(r.menuItemName) == normalized,
        orElse: () => throw Exception('Recipe not found'),
      );
      return exactMatch;
    } catch (_) {
      try {
        final recipes = _recipes.values
            .cast<Map>()
            .map((item) => Recipe.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        return recipes.firstWhere(
          (r) {
            final baseName = _normalizeMenuName(r.menuItemName);
            return baseName.contains(normalized) || normalized.contains(baseName);
          },
          orElse: () => throw Exception('Recipe not found'),
        );
      } catch (_) {
        return null;
      }
    }
  }

  String _normalizeMenuName(String name) {
    return name.trim().toLowerCase();
  }

  Future<bool> renameRecipeForMenuItem(String oldName, String newName) async {
    final normalizedOld = _normalizeMenuName(oldName);
    final key = _recipes.keys.cast<String>().firstWhere(
      (id) {
        final raw = _recipes.get(id);
        if (raw == null) return false;
        final recipe = Recipe.fromMap(Map<String, dynamic>.from(raw as Map<String, dynamic>));
        return _normalizeMenuName(recipe.menuItemName) == normalizedOld;
      },
      orElse: () => '',
    );
    if (key.isEmpty) {
      return false;
    }
    final raw = _recipes.get(key);
    if (raw == null) return false;
    final recipe = Recipe.fromMap(Map<String, dynamic>.from(raw as Map<String, dynamic>), id: key);
    final updated = Recipe(
      id: recipe.id,
      menuItemName: newName,
      ingredients: recipe.ingredients,
    );
    await _recipes.put(key, {...updated.toMap(), 'id': key});
    return true;
  }

  // Save a new recipe
  Future<String> saveRecipe(Recipe recipe) async {
    final id = recipe.id.isEmpty ? _uuid.v4() : recipe.id;
    final recipeMap = {
      ...recipe.toMap(),
      'id': id,
    };
    await _recipes.put(id, recipeMap);
    return id;
  }

  // Delete a recipe
  Future<void> deleteRecipe(String recipeId) async {
    await _recipes.delete(recipeId);
  }

  // Seed default recipes for seeded menu items if no recipes exist yet.
  Future<void> seedDefaultRecipesIfEmpty() async {
    if (_recipes.isNotEmpty) return;

    Future<String?> inventoryId(String itemName) async {
      final lowerName = itemName.toLowerCase();
      for (final value in _inventory.values.cast<Map>()) {
        final map = Map<String, dynamic>.from(value);
        final name = (map['name'] as String? ?? '').toLowerCase();
        if (name == lowerName) {
          return map['id'] as String?;
        }
      }
      return null;
    }

    final menuItems = [
      'Spanish Khalifa 12oz',
      'Spanish Khalifa 16oz',
      'Caramel Macchiato 12oz',
      'Caramel Macchiato 16oz',
      'Himalayan Pink Salt 12oz',
      'Himalayan Pink Salt 16oz',
      'Flat White 12oz',
      'Flat White 16oz',
      'Long Black 12oz',
      'Long Black 16oz',
      'Choco Lava 12oz',
      'Choco Lava 16oz',
      'Matcha 12oz',
      'Matcha 16oz',
      'Strawberry Matcha 12oz',
      'Strawberry Matcha 16oz',
    ];

    String cupNameForMenu(String menuName) {
      final lower = menuName.toLowerCase();
      if (lower.contains('12oz')) return 'Cups 12oz';
      if (lower.contains('16oz')) return 'Cups 16oz';
      return 'Cups 12oz';
    }

    for (final menuName in menuItems) {
      final cupName = cupNameForMenu(menuName);
      final cupId = await inventoryId(cupName);
      if (cupId == null) continue;

      final recipe = Recipe(
        id: '',
        menuItemName: menuName,
        ingredients: [
          RecipeIngredient(
            inventoryItemId: cupId,
            inventoryItemName: cupName,
            quantityNeeded: 1.0,
          ),
        ],
      );
      await saveRecipe(recipe);
    }
  }

  // Deduct inventory for an order
  // Returns false if any ingredient is out of stock, true if successful
  Future<String?> deductInventoryForOrder(List<OrderItem> items) async {
    MapEntry<String, Map<String, dynamic>>? findInventory(
        String inventoryItemId, String inventoryItemName) {
      final invMap = _inventory.get(inventoryItemId);
      if (invMap != null) {
        return MapEntry(inventoryItemId,
            Map<String, dynamic>.from(invMap as Map<String, dynamic>));
      }

      final lowerName = inventoryItemName.toLowerCase();
      for (final key in _inventory.keys.cast<String>()) {
        final value = _inventory.get(key);
        if (value == null) continue;
        final map = Map<String, dynamic>.from(value as Map<String, dynamic>);
        final name = (map['name'] as String? ?? '').toLowerCase();
        if (name == lowerName) {
          return MapEntry(key, map);
        }
      }
      return null;
    }

    // First, check if all items have enough inventory
    for (final orderItem in items) {
      final recipe = await getRecipeByMenuItemName(orderItem.name);
      if (recipe == null) {
        // No recipe defined for this item, skip inventory deduction
        continue;
      }

      for (final ingredient in recipe.ingredients) {
        final invEntry = findInventory(
          ingredient.inventoryItemId,
          ingredient.inventoryItemName,
        );
        if (invEntry == null) continue;

        final inv = InventoryItem.fromMap(
            Map<String, dynamic>.from(invEntry.value), id: invEntry.key);
        final totalNeeded = ingredient.quantityNeeded * orderItem.qty;

        if (inv.quantity < totalNeeded) {
          // Not enough stock
          return
              'Item ${orderItem.name} needs ${totalNeeded.toStringAsFixed(2)} ${inv.unit} of ${ingredient.inventoryItemName}, but only ${inv.quantity.toStringAsFixed(2)} is available';
        }
      }
    }

    // All items have enough stock, now deduct them
    for (final orderItem in items) {
      final recipe = await getRecipeByMenuItemName(orderItem.name);
      if (recipe == null) continue;

      for (final ingredient in recipe.ingredients) {
        final invEntry = findInventory(
          ingredient.inventoryItemId,
          ingredient.inventoryItemName,
        );
        if (invEntry == null) continue;

        final inv = InventoryItem.fromMap(
            Map<String, dynamic>.from(invEntry.value), id: invEntry.key);
        final totalNeeded = ingredient.quantityNeeded * orderItem.qty;

        // Deduct the inventory and track how much has been served
        inv.quantity -= totalNeeded;
        inv.servedQuantity += totalNeeded;
        await _inventory.put(invEntry.key, inv.toMap());
      }
    }

    return null;
  }
}
