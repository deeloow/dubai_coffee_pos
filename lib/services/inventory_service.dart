import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'local_order_socket_service.dart';

class InventoryService {
  final Box _inventory = Hive.box('inventory');
  final Uuid _uuid = const Uuid();

  Stream<List<InventoryItem>> inventoryStream() async* {
    yield _getInventoryItems();

    await for (final _ in _inventory.watch()) {
      yield _getInventoryItems();
    }
  }

  List<InventoryItem> _getInventoryItems() {
    final items = <InventoryItem>[];
    try {
      for (final item in _inventory.values) {
        if (item is Map) {
          try {
            final itemMap = Map<String, dynamic>.from(item);
            items.add(InventoryItem.fromMap(itemMap));
          } catch (e) {
            // Skip malformed entries
            continue;
          }
        }
      }
    } catch (e) {
      // If iteration fails, return empty list
      return [];
    }
    return items;
  }

  Future<List<InventoryItem>> fetchAllInventory() async {
    return _getInventoryItems();
  }

  Future<void> addItem(InventoryItem item) async {
    final id = item.id.isEmpty ? _uuid.v4() : item.id;
    await _inventory.put(id, {...item.toMap(), 'id': id});
  }

  Future<void> updateItem(InventoryItem item) async {
    await _inventory.put(item.id, {...item.toMap(), 'id': item.id});
  }

  Future<void> updateItemAndBroadcast(InventoryItem item) async {
    await _inventory.put(item.id, {...item.toMap(), 'id': item.id});
    _broadcastInventoryUpdate(item);
  }

  Future<InventoryItem?> fetchInventoryItem(String itemId) async {
    final map = _inventory.get(itemId);
    if (map == null) return null;
    try {
      final itemMap = Map<String, dynamic>.from(map);
      return InventoryItem.fromMap(itemMap, id: itemId);
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteItem(String itemId) async {
    await _inventory.delete(itemId);
  }

  Future<void> adjustStock(String itemId, double delta) async {
    final map = _inventory.get(itemId);
    if (map == null) return;
    try {
      final current = InventoryItem.fromMap(
        Map<String, dynamic>.from(map),
        id: itemId,
      );
      final newQty = (current.quantity + delta).clamp(0.0, double.infinity);
      final updated = current.copyWith(quantity: newQty);
      await _inventory.put(itemId, updated.toMap());
      // Broadcast inventory update via socket
      _broadcastInventoryUpdate(updated);
    } catch (e) {
      // If parsing fails, try generic update
      final updated = Map<String, dynamic>.from(map as Map);
      final oldQty = (updated['quantity'] as num?)?.toDouble() ?? 0.0;
      final newQty = (oldQty + delta).clamp(0.0, double.infinity);
      updated['quantity'] = newQty;
      updated['id'] = itemId;
      await _inventory.put(itemId, updated);
    }
  }

  Future<void> seedInventoryIfEmpty() async {
    if (_inventory.isEmpty) {
      print('InventoryService.seedInventoryIfEmpty: inventory empty, seeding cups');
      await _seedCupInventory();
      print('InventoryService.seedInventoryIfEmpty: seed complete');
      return;
    }

    final existing = _inventory.values.cast<Map>();
    final existingNames = existing
        .map((value) => ((value['name'] as String? ?? '').trim().toLowerCase()))
        .toSet();

    print('InventoryService.seedInventoryIfEmpty: existing names=$existingNames');
    if (!existingNames.contains('cups 12oz')) {
      print('InventoryService.seedInventoryIfEmpty: adding cups 12oz');
      await _inventory.put(_uuid.v4(), {
        'name': 'Cups 12oz',
        'unit': 'pcs',
        'quantity': 100.0,
        'servedQuantity': 0.0,
        'lowStockThreshold': 20.0,
        'costPerUnit': 4.0,
        'category': 'Packaging',
        'id': _uuid.v4(),
      });
      print('InventoryService.seedInventoryIfEmpty: added cups 12oz');
    }

    if (!existingNames.contains('cups 16oz')) {
      print('InventoryService.seedInventoryIfEmpty: adding cups 16oz');
      await _inventory.put(_uuid.v4(), {
        'name': 'Cups 16oz',
        'unit': 'pcs',
        'quantity': 100.0,
        'servedQuantity': 0.0,
        'lowStockThreshold': 20.0,
        'costPerUnit': 5.0,
        'category': 'Packaging',
        'id': _uuid.v4(),
      });
      print('InventoryService.seedInventoryIfEmpty: added cups 16oz');
    }

    if (!existingNames.contains('snack cup - regular')) {
      print('InventoryService.seedInventoryIfEmpty: adding snack cup - regular');
      await _inventory.put(_uuid.v4(), {
        'name': 'Snack Cup - Regular',
        'unit': 'pcs',
        'quantity': 100.0,
        'servedQuantity': 0.0,
        'lowStockThreshold': 20.0,
        'costPerUnit': 2.0,
        'category': 'Packaging',
        'id': _uuid.v4(),
      });
      print('InventoryService.seedInventoryIfEmpty: added snack cup - regular');
    }

    if (!existingNames.contains('snack cup - medium')) {
      print('InventoryService.seedInventoryIfEmpty: adding snack cup - medium');
      await _inventory.put(_uuid.v4(), {
        'name': 'Snack Cup - Medium',
        'unit': 'pcs',
        'quantity': 100.0,
        'servedQuantity': 0.0,
        'lowStockThreshold': 20.0,
        'costPerUnit': 2.5,
        'category': 'Packaging',
        'id': _uuid.v4(),
      });
      print('InventoryService.seedInventoryIfEmpty: added snack cup - medium');
    }
  }

  Future<void> clearAndReplaceWithItems(List<InventoryItem> items) async {
    await _inventory.clear();
    for (final item in items) {
      await _inventory.put(item.id, {...item.toMap(), 'id': item.id});
    }
  }

  Future<void> _seedCupInventory() async {
    final seedItems = [
      {'name': 'Cups 12oz', 'unit': 'pcs', 'quantity': 100.0, 'servedQuantity': 0.0, 'lowStockThreshold': 20.0, 'costPerUnit': 4.0, 'category': 'Packaging'},
      {'name': 'Cups 16oz', 'unit': 'pcs', 'quantity': 100.0, 'servedQuantity': 0.0, 'lowStockThreshold': 20.0, 'costPerUnit': 5.0, 'category': 'Packaging'},
      {'name': 'Snack Cup - Regular', 'unit': 'pcs', 'quantity': 100.0, 'servedQuantity': 0.0, 'lowStockThreshold': 20.0, 'costPerUnit': 2.0, 'category': 'Packaging'},
      {'name': 'Snack Cup - Medium', 'unit': 'pcs', 'quantity': 100.0, 'servedQuantity': 0.0, 'lowStockThreshold': 20.0, 'costPerUnit': 2.5, 'category': 'Packaging'},
    ];

    print('InventoryService._seedCupInventory: open=${_inventory.isOpen}, length=${_inventory.length}, runtime=${_inventory.runtimeType}');
    print('InventoryService._seedCupInventory: start seeding ${seedItems.length} items');
    for (final item in seedItems) {
      final id = _uuid.v4();
      print('InventoryService._seedCupInventory: putting ${item['name']} id=$id');
      await _inventory.put(id, {
        ...item,
        'id': id,
      });
      print('InventoryService._seedCupInventory: put complete for ${item['name']} id=$id');
    }
    print('InventoryService._seedCupInventory: finished seeding');
  }

  void _broadcastInventoryUpdate(InventoryItem item) {
    // Broadcast inventory update via socket
    LocalOrderSocketService().sendInventoryUpdate(item);
  }
}
