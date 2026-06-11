import 'dart:async';
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
            final orderMap = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
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
    await archiveOldOrders();
    yield _orderList(limit: limit, includeArchived: includeArchived);

    await for (final _ in _orders.watch()) {
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

  Future<String> saveOrder(Order order) async {
    final id = order.id.isEmpty ? _uuid.v4() : order.id;
    final alreadyExists = _orders.containsKey(id);

    // Auto-deduct inventory if order is paid and this is a new order
    if (order.status == OrderStatus.paid && !alreadyExists) {
      await _recipeService.seedDefaultRecipesIfEmpty();
      final deductError = await _recipeService.deductInventoryForOrder(order.items);
      if (deductError != null) {
        throw Exception('Insufficient inventory to complete order: $deductError');
      }
    }

    final orderMap = {
      ...order.toMap(),
      'id': id,
    };
    await _orders.put(id, orderMap);
    return id;
  }

  Future<bool> orderExists(String orderId) async {
    return _orders.containsKey(orderId);
  }

  Future<void> voidOrder(String orderId, {required String reason}) async {
    final map = _orders.get(orderId);
    if (map == null) return;
    try {
      final updated = Map<String, dynamic>.from(map as Map<dynamic, dynamic>);
      updated['status'] = OrderStatus.voided.index;
      updated['voidReason'] = reason;
      await _orders.put(orderId, updated);
    } catch (e) {
      // Failed to void order, silently skip
      return;
    }
  }

  Future<void> archiveOldOrders() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    for (final item in _orders.values) {
      if (item is! Map) continue;
      final entry = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
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

  Future<int> getNextOrderNumber() async {
    final orders = <Order>[];
    try {
      for (final item in _orders.values) {
        if (item is Map) {
          try {
            final orderMap = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
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
