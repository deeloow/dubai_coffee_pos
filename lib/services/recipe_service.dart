import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'inventory_service.dart';

String _resolveCupInventoryName(String? cupSize, {String category = ''}) {
  final normalized = (cupSize ?? '').trim().toLowerCase();

  if (normalized.contains('medium')) {
    return 'Snack Cup - Medium';
  }
  if (normalized.contains('regular')) {
    return 'Snack Cup - Regular';
  }
  if (normalized.contains('22')) {
    return 'Cups 22oz';
  }
  if (normalized.contains('16')) {
    return 'Cups 16oz';
  }
  if (normalized.contains('12')) {
    return 'Cups 12oz';
  }

  return category.toLowerCase().contains('snack')
      ? 'Snack Cup - Regular'
      : 'Cups 12oz';
}

List<RecipeIngredient> fallbackRecipeIngredientsForOrderItem(
  OrderItem orderItem, {
    String category = '',
    String cupSize = '12oz',
}) {
  final selectedCupSize = cupSize.isNotEmpty ? cupSize : orderItem.cupSize;
  final resolvedCup = _resolveCupInventoryName(selectedCupSize, category: category);

  return [
    RecipeIngredient(
      inventoryItemId: '',
      inventoryItemName: resolvedCup,
      quantityNeeded: 1.0,
    ),
  ];
}

class RecipeService {
  final Box _recipes = Hive.box('recipes');
  final Box _inventory = Hive.box('inventory');
  final Box _menu = Hive.box('menu');
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
        final recipe = Recipe.fromMap(Map<String, dynamic>.from(raw as Map));
        return _normalizeMenuName(recipe.menuItemName) == normalizedOld;
      },
      orElse: () => '',
    );
    if (key.isEmpty) {
      return false;
    }
    final raw = _recipes.get(key);
    if (raw == null) return false;
    final recipe = Recipe.fromMap(Map<String, dynamic>.from(raw as Map), id: key);
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

  // Create a recipe for a menu item using its cup size
  Future<void> createRecipeForMenuItem(MenuItem item) async {
    try {
      final cupSize = (item.cupSize.isNotEmpty) ? item.cupSize : '12oz';
      final cupName = _resolveCupInventoryName(cupSize);
      final cupId = await _findInventoryIdByName(cupName);
      if (cupId == null) {
        return;
      }

      final existingRecipe = await getRecipeByMenuItemName(item.name);
      if (existingRecipe != null) {
        return;
      }

      final recipe = Recipe(
        id: '',
        menuItemName: item.name,
        ingredients: [
          RecipeIngredient(
            inventoryItemId: cupId,
            inventoryItemName: cupName,
            quantityNeeded: 1.0,
          ),
        ],
      );
      await saveRecipe(recipe);
    } catch (_) {
      return;
    }
  }

  // Update a recipe for a menu item using its cup size
  Future<void> updateRecipeForMenuItem(MenuItem item) async {
    try {
      final cupSize = (item.cupSize.isNotEmpty) ? item.cupSize : '12oz';
      final cupName = _resolveCupInventoryName(cupSize);
      final cupId = await _findInventoryIdByName(cupName);
      if (cupId == null) {
        return;
      }

      final normalized = _normalizeMenuName(item.name);
      String? recipeId;
      for (final key in _recipes.keys.cast<String>()) {
        final raw = _recipes.get(key);
        if (raw == null) continue;
        final recipe = Recipe.fromMap(Map<String, dynamic>.from(raw as Map), id: key);
        if (_normalizeMenuName(recipe.menuItemName) == normalized) {
          recipeId = key;
          break;
        }
      }

      if (recipeId == null) {
        await createRecipeForMenuItem(item);
        return;
      }

      final raw = _recipes.get(recipeId);
      if (raw == null) return;
      final recipe = Recipe.fromMap(Map<String, dynamic>.from(raw as Map), id: recipeId);
      final updated = Recipe(
        id: recipe.id,
        menuItemName: item.name,
        ingredients: [
          RecipeIngredient(
            inventoryItemId: cupId,
            inventoryItemName: cupName,
            quantityNeeded: 1.0,
          ),
        ],
      );
      await _recipes.put(recipeId, {...updated.toMap(), 'id': recipeId});
    } catch (_) {
      return;
    }
  }

  Future<String?> _findInventoryIdByName(String name) async {
    final lowerName = name.toLowerCase();
    for (final key in _inventory.keys.cast<String>()) {
      final value = _inventory.get(key);
      if (value == null) continue;
      final map = Map<String, dynamic>.from(value as Map);
      final invName = (map['name'] as String? ?? '').toLowerCase();
      if (invName == lowerName) {
        return key;
      }
    }
    return null;
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
      'Spanish Khalifa',
      'Caramel Macchiato',
      'Himalayan Pink Salt',
      'Flat White',
      'Long Black',
      'Choco Lava',
      'Matcha',
      'Strawberry Matcha',
    ];

    for (final menuName in menuItems) {
      const cupName = 'Cups 12oz';
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

  List<RecipeIngredient> buildFallbackRecipeIngredients(
    OrderItem orderItem, {
    String category = '',
  }) {
    return fallbackRecipeIngredientsForOrderItem(orderItem, category: category);
  }

  Future<List<RecipeIngredient>> _resolveIngredients(OrderItem orderItem) async {
    // Priority: Use OrderItem.cupSize (selected during checkout) over recipe or menu default
    // This ensures manual cup size selection is ALWAYS respected, even if recipe has different default
    final orderItemCupSize = orderItem.cupSize.isNotEmpty ? orderItem.cupSize : null;
    
    // Only use recipe if it has ingredients AND no explicit cup size was selected in order
    if (orderItemCupSize == null) {
      final recipe = await getRecipeByMenuItemName(orderItem.name);
      if (recipe != null && recipe.ingredients.isNotEmpty) {
        return recipe.ingredients;
      }
    }

    final foundMenu = orderItem.menuItemId.isNotEmpty
        ? _menu.get(orderItem.menuItemId)
        : null;
    final category = foundMenu != null
        ? (Map<String, dynamic>.from(foundMenu as Map)['category'] as String? ?? '')
        : '';
    final cupSizeFromMenu = foundMenu != null
        ? (Map<String, dynamic>.from(foundMenu as Map)['cupSize'] as String? ?? '12oz')
        : '12oz';

    // Use order's selected cup size if available, otherwise use menu default
    final selectedCupSize = orderItemCupSize ?? cupSizeFromMenu;

    return fallbackRecipeIngredientsForOrderItem(
      orderItem,
      category: category,
      cupSize: selectedCupSize,
    );
  }

  Future<String?> adjustInventoryForOrder(
    List<OrderItem> items, {
    required double deltaMultiplier,
  }) async {
    if (deltaMultiplier == 0) {
      return null;
    }

    MapEntry<String, Map<String, dynamic>>? findInventory(
        String inventoryItemId, String inventoryItemName) {
      final invMap = _inventory.get(inventoryItemId);
      if (invMap != null) {
        return MapEntry(
          inventoryItemId,
          Map<String, dynamic>.from(invMap as Map),
        );
      }

      final lowerName = inventoryItemName.toLowerCase();
      for (final key in _inventory.keys.cast<String>()) {
        final value = _inventory.get(key);
        if (value == null) continue;
        final map = Map<String, dynamic>.from(value as Map);
        final name = (map['name'] as String? ?? '').toLowerCase();
        if (name == lowerName) {
          return MapEntry(key, map);
        }
      }
      return null;
    }

    final Map<String, Map<String, dynamic>> aggregatedNeeds = {};
    for (final orderItem in items) {
      final ingredients = await _resolveIngredients(orderItem);
      if (ingredients.isEmpty) {
        continue;
      }

      for (final ingredient in ingredients) {
        final totalNeeded = ingredient.quantityNeeded * orderItem.qty * deltaMultiplier;
        final key = ingredient.inventoryItemId.isNotEmpty
            ? ingredient.inventoryItemId
            : ingredient.inventoryItemName.toLowerCase();

        final existing = aggregatedNeeds[key];
        if (existing != null) {
          existing['totalNeeded'] = (existing['totalNeeded'] as double) + totalNeeded;
        } else {
          aggregatedNeeds[key] = {
            'inventoryItemId': ingredient.inventoryItemId,
            'inventoryItemName': ingredient.inventoryItemName,
            'totalNeeded': totalNeeded,
          };
        }
      }
    }

    if (deltaMultiplier > 0) {
      for (final aggregated in aggregatedNeeds.values) {
        final invEntry = findInventory(
          aggregated['inventoryItemId'] as String,
          aggregated['inventoryItemName'] as String,
        );
        if (invEntry == null) continue;

        final inv = InventoryItem.fromMap(
          Map<String, dynamic>.from(invEntry.value),
          id: invEntry.key,
        );
        final totalNeeded = (aggregated['totalNeeded'] as double).abs();

        if (inv.quantity < totalNeeded) {
          return 'Item ${aggregated['inventoryItemName']} needs ${totalNeeded.toStringAsFixed(2)} ${inv.unit}, but only ${inv.quantity.toStringAsFixed(2)} is available';
        }
      }
    }

    for (final aggregated in aggregatedNeeds.values) {
      final invEntry = findInventory(
        aggregated['inventoryItemId'] as String,
        aggregated['inventoryItemName'] as String,
      );
      if (invEntry == null) continue;

      final inv = InventoryItem.fromMap(
        Map<String, dynamic>.from(invEntry.value),
        id: invEntry.key,
      );
      final needed = (aggregated['totalNeeded'] as double).abs();
      final quantityDelta = deltaMultiplier > 0 ? -needed : needed;

      inv.quantity += quantityDelta;
      if (deltaMultiplier > 0) {
        inv.servedQuantity += needed;
      } else {
        inv.servedQuantity -= needed;
      }

      final inventoryService = InventoryService();
      await inventoryService.updateItemAndBroadcast(inv);
    }

    return null;
  }

  // Deduct inventory for an order
  Future<String?> deductInventoryForOrder(List<OrderItem> items) async {
    return adjustInventoryForOrder(items, deltaMultiplier: 1.0);
  }

  Future<String?> restoreInventoryForOrder(List<OrderItem> items) async {
    return adjustInventoryForOrder(items, deltaMultiplier: -1.0);
  }
}
