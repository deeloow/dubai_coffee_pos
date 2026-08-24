import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive_test/hive_test.dart';

import 'package:dubai_coffee_pos/models/models.dart';
import 'package:dubai_coffee_pos/screens/reports/reports_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpTestHive();
    await Hive.openBox('settings');
    await Hive.openBox('reports_history');
    await Hive.openBox('orders');
    await Hive.openBox('recipes');
    await Hive.openBox('inventory');
    await Hive.openBox('menu');
  });

  tearDownAll(() async {
    await tearDownTestHive();
  });

  testWidgets('widget uses injected orders stream instead of Hive', (WidgetTester tester) async {

    final now = DateTime.now();
    final order = Order(
      id: 'widget-injected-order',
      orderNumber: 1,
      customerName: 'Test',
      cashierName: 'T',
      items: [OrderItem(menuItemId: 'i1', name: 'Coffee', price: 100, icon: '☕')],
      subtotal: 100,
      discount: 0,
      discountLabel: '',
      total: 100,
      tendered: 100,
      change: 0,
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime(now.year, now.month, now.day, 10),
      status: OrderStatus.completed,
    );

    await tester.pumpWidget(MaterialApp(
      home: ReportsScreen(
        initialReportType: ReportType.daily,
        initialReportDate: DateTime(now.year, now.month, now.day),
        initialReportMonth: DateTime(now.year, now.month),
        ordersStreamOverride: Stream.value([order]),
      ),
    ));

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reportsCompletedOrders')), findsOneWidget);
  });
}
