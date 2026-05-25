import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dubai_coffee_pos/models/models.dart';
import 'package:dubai_coffee_pos/screens/pos/receipt_sheet.dart';

void main() {
  testWidgets('Receipt sheet renders order details', (WidgetTester tester) async {
    final order = Order(
      id: 'test-order',
      orderNumber: 1,
      customerName: 'Test Customer',
      cashierName: 'Test Cashier',
      items: [
        OrderItem(name: 'Espresso', price: 120.0, icon: '☕', qty: 2),
      ],
      subtotal: 240.0,
      discount: 0,
      discountLabel: 'No discount',
      vat: 28.8,
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
