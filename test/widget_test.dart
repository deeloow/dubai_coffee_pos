import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dubai_coffee_pos/models/models.dart';
import 'package:dubai_coffee_pos/screens/history/history_screen.dart';
import 'package:dubai_coffee_pos/screens/pos/receipt_sheet.dart';
import 'package:dubai_coffee_pos/services/recipe_service.dart';

void main() {
  test('history payment filter matches case-insensitively', () {
    final order = Order(
      id: 'test-order',
      orderNumber: 1,
      customerName: 'Test Customer',
      cashierName: 'Test Cashier',
      items: const [],
      subtotal: 0,
      discount: 0,
      discountLabel: 'No discount',
      total: 0,
      tendered: 0,
      change: 0,
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime.now(),
      status: OrderStatus.paid,
    );

    expect(matchesHistoryFilter(order, 'Cash'), isTrue);
    expect(matchesHistoryFilter(order, 'cash'), isTrue);
    expect(matchesHistoryFilter(order, 'GCash'), isFalse);
  });

  test('fallback cup inventory uses 16oz cups for soda or lemonade items', () {
    final orderItem = OrderItem(
      menuItemId: 'item-1',
      name: 'Strawberry',
      price: 50,
      icon: '🍓',
      qty: 1,
    );

    final ingredients = fallbackRecipeIngredientsForOrderItem(
      orderItem,
      category: 'Soda base',
    );

    expect(ingredients, hasLength(1));
    expect(ingredients.single.inventoryItemName, 'Cups 16oz');
    expect(ingredients.single.quantityNeeded, 1.0);
  });

  testWidgets('Receipt sheet renders order details', (WidgetTester tester) async {
    final order = Order(
      id: 'test-order',
      orderNumber: 1,
      customerName: 'Test Customer',
      cashierName: 'Test Cashier',
      items: [
        OrderItem(
          menuItemId: 'item-1',
          name: 'Espresso',
          price: 120.0,
          icon: '☕',
          qty: 2,
        ),
      ],
      subtotal: 240.0,
      discount: 0,
      discountLabel: 'No discount',
      total: 268.8,
      tendered: 300.0,
      change: 31.2,
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime.now(),
      status: OrderStatus.paid,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReceiptSheet(order: order),
        ),
      ),
    );

    expect(find.text('Dubai Coffee'), findsOneWidget);
    expect(find.text('Official Receipt'), findsOneWidget);
    expect(find.text('Espresso × 2'), findsOneWidget);
    expect(find.text('₱268.80'), findsOneWidget);
  });
}
