import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dubai_coffee_pos/models/models.dart';
import 'package:dubai_coffee_pos/services/inventory_service.dart';
import 'package:dubai_coffee_pos/services/order_service.dart';
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tempDir = Directory.systemTemp.createTempSync('hive_inventory_test');
    Hive.init(tempDir.path);
    await Hive.openBox('recipes');
    await Hive.openBox('inventory');
    await Hive.openBox('orders');
    await Hive.openBox('menu');
  });

  setUp(() async {
    await Hive.box('recipes').clear();
    await Hive.box('inventory').clear();
    await Hive.box('orders').clear();
    await Hive.box('menu').clear();
  });

  test('client-side saves do not deduct inventory locally', () async {
    final inventoryService = InventoryService();
    final orderService = OrderService();

    const cupId = 'cup-16oz-client';
    await inventoryService.addItem(
      InventoryItem(
        id: cupId,
        name: 'Cups 16oz',
        unit: 'pcs',
        quantity: 10,
        lowStockThreshold: 2,
        costPerUnit: 5,
        category: 'Packaging',
      ),
    );

    final order = Order(
      id: '',
      orderNumber: 200,
      customerName: 'Barista',
      cashierName: 'Barista',
      items: [
        OrderItem(
          menuItemId: 'menu-1',
          name: 'Matcha',
          price: 80,
          icon: '🫖',
          qty: 2,
          cupSize: '16oz',
        ),
      ],
      subtotal: 160,
      discount: 0,
      discountLabel: 'No discount',
      total: 160,
      tendered: 160,
      change: 0,
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime.now(),
      status: OrderStatus.completed,
    );

    await orderService.saveOrder(order, deductInventory: true, isServerRole: false);

    final updated = await inventoryService.fetchInventoryItem(cupId);
    expect(updated, isNotNull);
    expect(updated!.quantity, 10);
  });

  test('completed orders deduct the correct cup inventory when saved by the admin', () async {
    final inventoryService = InventoryService();
    final orderService = OrderService();

    const cupId = 'cup-16oz';
    await inventoryService.addItem(
      InventoryItem(
        id: cupId,
        name: 'Cups 16oz',
        unit: 'pcs',
        quantity: 10,
        lowStockThreshold: 2,
        costPerUnit: 5,
        category: 'Packaging',
      ),
    );

    final order = Order(
      id: '',
      orderNumber: 100,
      customerName: 'Admin',
      cashierName: 'Admin',
      items: [
        OrderItem(
          menuItemId: 'menu-1',
          name: 'Matcha',
          price: 80,
          icon: '🫖',
          qty: 2,
          cupSize: '16oz',
        ),
      ],
      subtotal: 160,
      discount: 0,
      discountLabel: 'No discount',
      total: 160,
      tendered: 160,
      change: 0,
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime.now(),
      status: OrderStatus.completed,
    );

    await orderService.saveOrder(order, deductInventory: true);

    final updated = await inventoryService.fetchInventoryItem(cupId);
    expect(updated, isNotNull);
    expect(updated!.quantity, 8);
  });

  test('inventory is deducted only once when an order is later marked completed', () async {
    final inventoryService = InventoryService();
    final orderService = OrderService();

    const twelveOzId = 'cup-12oz';
    await inventoryService.addItem(
      InventoryItem(
        id: twelveOzId,
        name: 'Cups 12oz',
        unit: 'pcs',
        quantity: 10,
        lowStockThreshold: 2,
        costPerUnit: 4,
        category: 'Packaging',
      ),
    );

    final initialOrder = Order(
      id: '',
      orderNumber: 102,
      customerName: 'Admin',
      cashierName: 'Admin',
      items: [
        OrderItem(
          menuItemId: 'menu-12oz',
          name: 'Matcha',
          price: 80,
          icon: '🫖',
          qty: 2,
          cupSize: '12oz',
        ),
      ],
      subtotal: 160,
      discount: 0,
      discountLabel: 'No discount',
      total: 160,
      tendered: 160,
      change: 0,
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime.now(),
      status: OrderStatus.paid,
    );

    final persistedOrderId = await orderService.saveOrder(initialOrder, deductInventory: true, isServerRole: true);

    final afterFirstDeduction = await inventoryService.fetchInventoryItem(twelveOzId);
    expect(afterFirstDeduction, isNotNull);
    expect(afterFirstDeduction!.quantity, 8);

    final completedOrder = initialOrder.copyWith(
      id: persistedOrderId,
      status: OrderStatus.completed,
    );
    await orderService.saveOrder(completedOrder, deductInventory: true, isServerRole: true);

    final afterSecondDeduction = await inventoryService.fetchInventoryItem(twelveOzId);
    expect(afterSecondDeduction, isNotNull);
    expect(afterSecondDeduction!.quantity, 8);
  });

  test('editing an active order reverses the old cup deduction and reapplies inventory for the updated item set', () async {
    final inventoryService = InventoryService();
    final orderService = OrderService();

    const twelveOzId = 'cup-12oz-edit';
    const sixteenOzId = 'cup-16oz-edit';
    await inventoryService.addItem(
      InventoryItem(
        id: twelveOzId,
        name: 'Cups 12oz',
        unit: 'pcs',
        quantity: 10,
        lowStockThreshold: 2,
        costPerUnit: 4,
        category: 'Packaging',
      ),
    );
    await inventoryService.addItem(
      InventoryItem(
        id: sixteenOzId,
        name: 'Cups 16oz',
        unit: 'pcs',
        quantity: 10,
        lowStockThreshold: 2,
        costPerUnit: 5,
        category: 'Packaging',
      ),
    );

    final initialOrder = Order(
      id: '',
      orderNumber: 103,
      customerName: 'Admin',
      cashierName: 'Admin',
      items: [
        OrderItem(
          menuItemId: 'menu-12oz',
          name: 'Matcha',
          price: 80,
          icon: '🫖',
          qty: 2,
          cupSize: '12oz',
        ),
      ],
      subtotal: 160,
      discount: 0,
      discountLabel: 'No discount',
      total: 160,
      tendered: 160,
      change: 0,
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime.now(),
      status: OrderStatus.paid,
    );

    final persistedOrderId = await orderService.saveOrder(initialOrder, deductInventory: true, isServerRole: true);
    final initial12oz = await inventoryService.fetchInventoryItem(twelveOzId);
    expect(initial12oz, isNotNull);
    expect(initial12oz!.quantity, 8);

    final updatedOrder = initialOrder.copyWith(
      id: persistedOrderId,
      items: [
        OrderItem(
          menuItemId: 'menu-16oz',
          name: 'Caramel Macchiato',
          price: 90,
          icon: '☕',
          qty: 2,
          cupSize: '16oz',
        ),
      ],
      subtotal: 180,
      total: 180,
      status: OrderStatus.paid,
    );

    await orderService.saveOrder(updatedOrder, deductInventory: true, isServerRole: true);

    final restored12oz = await inventoryService.fetchInventoryItem(twelveOzId);
    final deducted16oz = await inventoryService.fetchInventoryItem(sixteenOzId);

    expect(restored12oz, isNotNull);
    expect(restored12oz!.quantity, 10);
    expect(deducted16oz, isNotNull);
    expect(deducted16oz!.quantity, 8);
  });

  test('order notes round-trip through the shared order payload and remain available for receipts', () async {
    final order = Order(
      id: 'note-order-1',
      orderNumber: 777,
      customerName: 'Customer',
      cashierName: 'Admin',
      items: [
        OrderItem(
          menuItemId: 'menu-matcha',
          name: 'Matcha',
          price: 80,
          icon: '🫖',
          qty: 2,
          sugarLevel: 'Less sugar',
          cupSize: '16oz',
        ),
      ],
      subtotal: 160,
      discount: 0,
      discountLabel: 'No discount',
      total: 160,
      tendered: 160,
      change: 0,
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime.now(),
      status: OrderStatus.paid,
      orderNotes: 'Less ice • Extra shot for Matcha',
    );

    final roundTripped = Order.fromMap(order.toMap(), id: order.id);
    expect(roundTripped.orderNotes, 'Less ice • Extra shot for Matcha');
  });

  test('cloud series orders always deduct from the 16oz cup inventory', () async {
    final inventoryService = InventoryService();
    final orderService = OrderService();

    const twelveOzId = 'cup-12oz-cloud';
    const sixteenOzId = 'cup-16oz-cloud';

    await inventoryService.addItem(
      InventoryItem(
        id: twelveOzId,
        name: 'Cups 12oz',
        unit: 'pcs',
        quantity: 10,
        lowStockThreshold: 2,
        costPerUnit: 4,
        category: 'Packaging',
      ),
    );
    await inventoryService.addItem(
      InventoryItem(
        id: sixteenOzId,
        name: 'Cups 16oz',
        unit: 'pcs',
        quantity: 10,
        lowStockThreshold: 2,
        costPerUnit: 5,
        category: 'Packaging',
      ),
    );

    final menuBox = Hive.box('menu');
    await menuBox.put('menu-cloud', {
      'id': 'menu-cloud',
      'name': 'Cloud Series – Matcha',
      'category': 'Cloud series',
      'cupSize': '12oz',
      'price': 80.0,
      'icon': '☁️',
      'badge': '',
      'available': true,
    });

    final order = Order(
      id: '',
      orderNumber: 104,
      customerName: 'Admin',
      cashierName: 'Admin',
      items: [
        OrderItem(
          menuItemId: 'menu-cloud',
          name: 'Cloud Series – Matcha',
          price: 80,
          icon: '☁️',
          qty: 1,
          cupSize: '12oz',
        ),
      ],
      subtotal: 80,
      discount: 0,
      discountLabel: 'No discount',
      total: 80,
      tendered: 80,
      change: 0,
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime.now(),
      status: OrderStatus.completed,
    );

    await orderService.saveOrder(order, deductInventory: true, isServerRole: true);

    final twelveOz = await inventoryService.fetchInventoryItem(twelveOzId);
    final sixteenOz = await inventoryService.fetchInventoryItem(sixteenOzId);
    expect(twelveOz, isNotNull);
    expect(sixteenOz, isNotNull);
    expect(twelveOz!.quantity, 10);
    expect(sixteenOz!.quantity, 9);
  });

  test('mixed-category orders deduct the total quantity for the selected cup size', () async {
    final inventoryService = InventoryService();
    final orderService = OrderService();

    const twelveOzId = 'cup-12oz';
    const sixteenOzId = 'cup-16oz';

    await inventoryService.addItem(
      InventoryItem(
        id: twelveOzId,
        name: 'Cups 12oz',
        unit: 'pcs',
        quantity: 10,
        lowStockThreshold: 2,
        costPerUnit: 4,
        category: 'Packaging',
      ),
    );
    await inventoryService.addItem(
      InventoryItem(
        id: sixteenOzId,
        name: 'Cups 16oz',
        unit: 'pcs',
        quantity: 10,
        lowStockThreshold: 2,
        costPerUnit: 5,
        category: 'Packaging',
      ),
    );

    final menuBox = Hive.box('menu');
    await menuBox.put('menu-cloud', {
      'id': 'menu-cloud',
      'name': 'Cloud Series – Matcha',
      'category': 'Cloud series',
      'cupSize': '12oz',
      'price': 80.0,
      'icon': '☁️',
      'badge': '',
      'available': true,
    });
    await menuBox.put('menu-soda', {
      'id': 'menu-soda',
      'name': 'Soda – Strawberry',
      'category': 'Soda series',
      'cupSize': '12oz',
      'price': 70.0,
      'icon': '🥤',
      'badge': '',
      'available': true,
    });
    await menuBox.put('menu-lemonade', {
      'id': 'menu-lemonade',
      'name': 'Lemonade – Freshly Squeezed',
      'category': 'Lemonade-freshly squeeze',
      'cupSize': '12oz',
      'price': 65.0,
      'icon': '🍋',
      'badge': '',
      'available': true,
    });

    final order = Order(
      id: '',
      orderNumber: 101,
      customerName: 'Admin',
      cashierName: 'Admin',
      items: [
        OrderItem(
          menuItemId: 'menu-cloud',
          name: 'Cloud Series – Matcha',
          price: 80,
          icon: '☁️',
          qty: 1,
        ),
        OrderItem(
          menuItemId: 'menu-soda',
          name: 'Soda – Strawberry',
          price: 70,
          icon: '🥤',
          qty: 1,
        ),
        OrderItem(
          menuItemId: 'menu-lemonade',
          name: 'Lemonade – Freshly Squeezed',
          price: 65,
          icon: '🍋',
          qty: 1,
        ),
      ],
      subtotal: 215,
      discount: 0,
      discountLabel: 'No discount',
      total: 215,
      tendered: 215,
      change: 0,
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime.now(),
      status: OrderStatus.completed,
    );

    await orderService.saveOrder(order, deductInventory: true);

    final twelveOz = await inventoryService.fetchInventoryItem(twelveOzId);
    final sixteenOz = await inventoryService.fetchInventoryItem(sixteenOzId);
    expect(twelveOz, isNotNull);
    expect(sixteenOz, isNotNull);
    expect(twelveOz!.quantity, 10);
    expect(sixteenOz!.quantity, 7);
  });
}
