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
    if (_inventory.isEmpty) {
      await _seedCupInventory();
      return;
    }

    final cupNames = {'cups 12oz', 'cups 16oz'};
    final onlyCups = _inventory.values.cast<Map>().every((value) {
      final map = Map<String, dynamic>.from(value);
      final name = (map['name'] as String? ?? '').toLowerCase();
      final unit = map['unit'] as String? ?? '';
      return cupNames.contains(name) && unit == 'pcs';
    });

    if (!onlyCups) {
      await _inventory.clear();
      await _seedCupInventory();
    }
  }

  Future<void> _seedCupInventory() async {
    final seedItems = [
      {'name': 'Cups 12oz', 'unit': 'pcs', 'quantity': 200.0, 'servedQuantity': 0.0, 'lowStockThreshold': 20.0, 'costPerUnit': 4.0, 'category': 'Packaging'},
      {'name': 'Cups 16oz', 'unit': 'pcs', 'quantity': 150.0, 'servedQuantity': 0.0, 'lowStockThreshold': 20.0, 'costPerUnit': 5.0, 'category': 'Packaging'},
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
