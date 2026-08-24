import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'recipe_service.dart';

class OrderService {
  static bool _dailyArchiveSchedulerStarted = false;
  // The timer reference is retained for potential future cleanup.
  static Timer? _archiveSchedulerTimer; // ignore: unused_field

  final Box _orders = Hive.box('orders');
  final Uuid _uuid = const Uuid();
  final RecipeService _recipeService = RecipeService();

  static void startDailyArchiveScheduler() {
    if (_dailyArchiveSchedulerStarted) return;
    _dailyArchiveSchedulerStarted = true;
    final service = OrderService();
    service.archiveOldOrders();
    _archiveSchedulerTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => service.archiveOldOrders(),
    );
  }

  List<Order> _orderList({int? limit, bool includeArchived = true}) {
    final orders = <Order>[];
    try {
      for (final item in _orders.values) {
        if (item is Map) {
          try {
            final orderMap = Map<String, dynamic>.from(item);
            final order = Order.fromMap(orderMap);
            if (includeArchived || order.archivedAt == null) {
              orders.add(order);
            }
          } catch (e) {
            // Skip malformed order entries
            continue;
          }
        }
      }
    } catch (e) {
      // If iteration fails, return empty list
      return [];
    }
    
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (limit != null && limit < orders.length) {
      return orders.take(limit).toList();
    }
    return orders;
  }

  Stream<List<Order>> ordersStream({int? limit, bool includeArchived = true}) async* {
    debugPrint('OrderService: ordersStream start');
    if (Platform.environment['FLUTTER_TEST'] != 'true') {
      await archiveOldOrders();
      debugPrint('OrderService: ordersStream after archiveOldOrders');
    }
    final orders = _orderList(limit: limit, includeArchived: includeArchived);
    debugPrint('OrderService: ordersStream yielding ${orders.length} orders');
    yield orders;

    await for (final _ in _orders.watch()) {
      debugPrint('OrderService: ordersStream change event');
      yield _orderList(limit: limit, includeArchived: includeArchived);
    }
  }

  Future<List<Order>> fetchOrders({int? limit, int offset = 0, bool includeArchived = true}) async {
    await archiveOldOrders();
    final allOrders = _orderList(includeArchived: includeArchived);
    if (offset >= allOrders.length) {
      return [];
    }
    final page = allOrders.skip(offset);
    return limit != null ? page.take(limit).toList() : page.toList();
  }

  Future<int> getOrderCount() async {
    return _orders.length;
  }

  Future<String> saveOrder(
    Order order, {
      bool deductInventory = true,
      bool isServerRole = true,
    }) async {
    print('OrderService.saveOrder start orderNumber=${order.orderNumber} id=${order.id}');
    String resolvedId = order.id;
    if (resolvedId.isEmpty && order.orderNumber > 0) {
      Map<String, dynamic>? existingByOrderNumber;
      for (final item in _orders.values) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        if ((map['orderNumber'] as num?)?.toInt() == order.orderNumber) {
          existingByOrderNumber = map;
          break;
        }
      }
      if (existingByOrderNumber != null) {
        resolvedId = (existingByOrderNumber!['id'] as String?) ?? '';
      }
    }

    final id = resolvedId.isNotEmpty ? resolvedId : _uuid.v4();
    final existingMap = _orders.get(id);
    final alreadyExists = existingMap != null;
    final orderWithTotals = order.recalculateTotals();

    bool shouldDeductInventory = false;
    bool inventoryDeducted = false;
    if (deductInventory && isServerRole && (orderWithTotals.status == OrderStatus.paid || orderWithTotals.status == OrderStatus.completed)) {
      if (!alreadyExists) {
        shouldDeductInventory = true;
      } else {
        final existingOrder = Order.fromMap(Map<String, dynamic>.from(existingMap as Map));
        inventoryDeducted = existingOrder.inventoryDeducted;

        if (inventoryDeducted) {
          await _recipeService.seedDefaultRecipesIfEmpty();
          final restoreError = await _recipeService.restoreInventoryForOrder(existingOrder.items);
          if (restoreError != null) {
            throw Exception('Failed to reverse prior inventory for edit: $restoreError');
          }
          inventoryDeducted = false;
        }

        shouldDeductInventory = !inventoryDeducted;
      }
    }

    if (shouldDeductInventory) {
      inventoryDeducted = true;
      await _recipeService.seedDefaultRecipesIfEmpty();
      final deductError = await _recipeService.deductInventoryForOrder(orderWithTotals.items);
      if (deductError != null) {
        throw Exception('Insufficient inventory to complete order: $deductError');
      }
    }

    final orderToPersist = orderWithTotals.copyWith(inventoryDeducted: inventoryDeducted);
    final orderMap = {
      ...orderToPersist.toMap(),
      'id': id,
    };
    debugPrint('OrderService.saveOrder about to put order id=$id');
    try {
      print('OrderService.saveOrder about to put order id=$id');
      await _orders.put(id, orderMap);
      print('OrderService.saveOrder completed id=$id');
    } catch (e, st) {
      print('OrderService.saveOrder failed id=$id error=$e');
      print(st);
      rethrow;
    }
    return id;
  }

  Future<bool> orderExists(String orderId) async {
    return _orders.containsKey(orderId);
  }

  Future<void> voidOrder(String orderId, {required String reason}) async {
    final map = _orders.get(orderId);
    if (map == null) return;
    try {
      final order = Order.fromMap(Map<String, dynamic>.from(map as Map));
      
      // Only restore inventory if the order was previously deducted and is not already voided
      if (order.inventoryDeducted && order.status != OrderStatus.voided) {
        await _recipeService.seedDefaultRecipesIfEmpty();
        await _recipeService.restoreInventoryForOrder(order.items);
      }
      
      final updated = Map<String, dynamic>.from(map as Map);
      updated['status'] = OrderStatus.voided.index;
      updated['voidReason'] = reason;
      await _orders.put(orderId, updated);
    } catch (e) {
      // Failed to void order, silently skip
      return;
    }
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      if (_orders.containsKey(orderId)) {
        await _orders.delete(orderId);
      }
    } catch (e) {
      // Failed to delete order, silently skip
      return;
    }
  }

  Future<void> archiveOldOrders() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    for (final item in _orders.values) {
      if (item is! Map) continue;
      final entry = Map<String, dynamic>.from(item);
      final createdAtRaw = entry['createdAt'];
      DateTime? createdAt;
      if (createdAtRaw is DateTime) {
        createdAt = createdAtRaw;
      } else if (createdAtRaw is String) {
        createdAt = DateTime.tryParse(createdAtRaw);
      }
      if (createdAt == null) continue;
      final archivedAtRaw = entry['archivedAt'];
      final alreadyArchived = archivedAtRaw != null;
      if (createdAt.isBefore(todayStart) && !alreadyArchived) {
        entry['archivedAt'] = todayStart.toIso8601String();
        await _orders.put(entry['id'] ?? _uuid.v4(), entry);
      }
    }
  }

  Future<void> archiveOrdersBefore(DateTime boundary) async {
    final boundaryStart = DateTime(boundary.year, boundary.month, boundary.day);
    for (final item in _orders.values) {
      if (item is! Map) continue;
      final entry = Map<String, dynamic>.from(item);
      final createdAtRaw = entry['createdAt'];
      DateTime? createdAt;
      if (createdAtRaw is DateTime) {
        createdAt = createdAtRaw;
      } else if (createdAtRaw is String) {
        createdAt = DateTime.tryParse(createdAtRaw);
      }
      if (createdAt == null) continue;
      final archivedAtRaw = entry['archivedAt'];
      final alreadyArchived = archivedAtRaw != null;
      if (createdAt.isBefore(boundaryStart) && !alreadyArchived) {
        entry['archivedAt'] = boundaryStart.toIso8601String();
        await _orders.put(entry['id'] ?? _uuid.v4(), entry);
      }
    }
  }

  /// Archive all orders with createdAt on or before [boundary].
  /// This is used when performing an immediate daily reset to archive
  /// the current day's orders up to the reset timestamp.
  Future<void> archiveOrdersUpTo(DateTime boundary) async {
    for (final item in _orders.values) {
      if (item is! Map) continue;
      final entry = Map<String, dynamic>.from(item);
      final createdAtRaw = entry['createdAt'];
      DateTime? createdAt;
      if (createdAtRaw is DateTime) {
        createdAt = createdAtRaw;
      } else if (createdAtRaw is String) {
        createdAt = DateTime.tryParse(createdAtRaw);
      }
      if (createdAt == null) continue;
      final archivedAtRaw = entry['archivedAt'];
      final alreadyArchived = archivedAtRaw != null;
      if ((createdAt.isBefore(boundary) || createdAt.isAtSameMomentAs(boundary)) && !alreadyArchived) {
        entry['archivedAt'] = boundary.toIso8601String();
        await _orders.put(entry['id'] ?? _uuid.v4(), entry);
      }
    }
  }

  Future<int> getNextOrderNumber() async {
    final orders = <Order>[];
    try {
      for (final item in _orders.values) {
        if (item is Map) {
          try {
            final orderMap = Map<String, dynamic>.from(item);
            // ignore archived orders when calculating next daily order number
            if (orderMap.containsKey('archivedAt') && orderMap['archivedAt'] != null) {
              continue;
            }
            orders.add(Order.fromMap(orderMap));
          } catch (e) {
            // Skip malformed order entries
            continue;
          }
        }
      }
    } catch (e) {
      // If iteration fails, return 1
      return 1;
    }

    if (orders.isEmpty) return 1;
    final last = orders.map((o) => o.orderNumber).fold<int>(0, (a, b) => a > b ? a : b);
    return last + 1;
  }
}
