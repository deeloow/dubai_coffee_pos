import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class InventoryService {
  final Box _inventory = Hive.box('inventory');
  final Uuid _uuid = const Uuid();

  Stream<List<InventoryItem>> inventoryStream() async* {
    yield _inventory.values
        .cast<Map>()
        .map((item) => InventoryItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    await for (final _ in _inventory.watch()) {
      yield _inventory.values
          .cast<Map>()
          .map((item) => InventoryItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }
  }

  Future<void> addItem(InventoryItem item) async {
    final id = item.id.isEmpty ? _uuid.v4() : item.id;
    await _inventory.put(id, {...item.toMap(), 'id': id});
  }

  Future<void> updateItem(InventoryItem item) async {
    await _inventory.put(item.id, {...item.toMap(), 'id': item.id});
  }

  Future<void> deleteItem(String itemId) async {
    await _inventory.delete(itemId);
  }

  Future<void> adjustStock(String itemId, double delta) async {
    final map = _inventory.get(itemId);
    if (map == null) return;
    final updated = Map<String, dynamic>.from(map as Map);
    updated['quantity'] = (updated['quantity'] as num).toDouble() + delta;
    await _inventory.put(itemId, updated);
  }

  Future<void> seedInventoryIfEmpty() async {
    if (_inventory.isNotEmpty) return;

    final seedItems = [
      {'name': 'Coffee Beans (Arabica)', 'unit': 'kg', 'quantity': 10.0, 'lowStockThreshold': 2.0, 'costPerUnit': 800.0, 'category': 'Raw Materials'},
      {'name': 'Espresso Blend', 'unit': 'kg', 'quantity': 5.0, 'servedQuantity': 0.0, 'lowStockThreshold': 1.0, 'costPerUnit': 950.0, 'category': 'Raw Materials'},
      {'name': 'Whole Milk', 'unit': 'L', 'quantity': 20.0, 'servedQuantity': 0.0, 'lowStockThreshold': 5.0, 'costPerUnit': 65.0, 'category': 'Dairy'},
      {'name': 'Oat Milk', 'unit': 'L', 'quantity': 6.0, 'servedQuantity': 0.0, 'lowStockThreshold': 2.0, 'costPerUnit': 120.0, 'category': 'Dairy'},
      {'name': 'Sugar', 'unit': 'kg', 'quantity': 8.0, 'servedQuantity': 0.0, 'lowStockThreshold': 2.0, 'costPerUnit': 60.0, 'category': 'Dry Goods'},
      {'name': 'Vanilla Syrup', 'unit': 'bottle', 'quantity': 4.0, 'servedQuantity': 0.0, 'lowStockThreshold': 1.0, 'costPerUnit': 250.0, 'category': 'Syrups'},
      {'name': 'Caramel Sauce', 'unit': 'bottle', 'quantity': 3.0, 'servedQuantity': 0.0, 'lowStockThreshold': 1.0, 'costPerUnit': 220.0, 'category': 'Syrups'},
      {'name': 'Chocolate Powder', 'unit': 'kg', 'quantity': 2.0, 'lowStockThreshold': 0.5, 'costPerUnit': 400.0, 'category': 'Dry Goods'},
      {'name': 'Cups (Medium)', 'unit': 'pcs', 'quantity': 200.0, 'servedQuantity': 0.0, 'lowStockThreshold': 50.0, 'costPerUnit': 4.0, 'category': 'Packaging'},
      {'name': 'Cups (Large)', 'unit': 'pcs', 'quantity': 150.0, 'servedQuantity': 0.0, 'lowStockThreshold': 40.0, 'costPerUnit': 5.0, 'category': 'Packaging'},
      {'name': 'Lids', 'unit': 'pcs', 'quantity': 300.0, 'servedQuantity': 0.0, 'lowStockThreshold': 80.0, 'costPerUnit': 2.0, 'category': 'Packaging'},
      {'name': 'Croissants', 'unit': 'pcs', 'quantity': 20.0, 'servedQuantity': 0.0, 'lowStockThreshold': 5.0, 'costPerUnit': 45.0, 'category': 'Pastries'},
      {'name': 'Muffins', 'unit': 'pcs', 'quantity': 15.0, 'servedQuantity': 0.0, 'lowStockThreshold': 4.0, 'costPerUnit': 40.0, 'category': 'Pastries'},
      {'name': 'Cheesecake Slice', 'unit': 'pcs', 'quantity': 10.0, 'servedQuantity': 0.0, 'lowStockThreshold': 3.0, 'costPerUnit': 70.0, 'category': 'Pastries'},
    ];

    for (final item in seedItems) {
      final id = _uuid.v4();
      await _inventory.put(id, {
        ...item,
        'id': id,
      });
    }
  }
}
