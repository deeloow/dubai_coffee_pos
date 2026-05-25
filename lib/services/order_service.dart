import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'recipe_service.dart';

class OrderService {
  final Box _orders = Hive.box('orders');
  final Uuid _uuid = const Uuid();
  final RecipeService _recipeService = RecipeService();

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

  Stream<List<Order>> ordersStream() async* {
    yield _orders.values
        .cast<Map>()
        .map((item) => Order.fromMap(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await for (final _ in _orders.watch()) {
      yield _orders.values
          .cast<Map>()
          .map((item) => Order.fromMap(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  Future<void> voidOrder(String orderId) async {
    final map = _orders.get(orderId);
    if (map == null) return;
    final updated = Map<String, dynamic>.from(map as Map);
    updated['status'] = OrderStatus.voided.index;
    await _orders.put(orderId, updated);
  }

  Future<int> getNextOrderNumber() async {
    final orders = _orders.values
        .cast<Map>()
        .map((item) => Order.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    if (orders.isEmpty) return 1;
    final last = orders.map((o) => o.orderNumber).fold<int>(0, (a, b) => a > b ? a : b);
    return last + 1;
  }
}
