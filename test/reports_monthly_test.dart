import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive_test/hive_test.dart';
import 'package:provider/provider.dart';

import 'package:dubai_coffee_pos/models/models.dart';
import 'package:dubai_coffee_pos/screens/history/history_screen.dart';
import 'package:dubai_coffee_pos/services/auth_provider.dart';
import 'package:dubai_coffee_pos/services/local_order_socket_provider.dart';
import 'package:dubai_coffee_pos/services/order_service.dart';
import 'package:dubai_coffee_pos/services/report_service.dart';
import 'package:dubai_coffee_pos/screens/reports/reports_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final boxNames = <String>[
    'settings',
    'reports_history',
    'orders',
    'recipes',
    'inventory',
    'menu',
    'users',
    'session',
    'assignments',
  ];

  Future<void> openHiveBoxes() async {
    await Hive.openBox('settings');
    await Hive.openBox('reports_history');
    await Hive.openBox('orders');
    await Hive.openBox('recipes');
    await Hive.openBox('inventory');
    await Hive.openBox('menu');
    await Hive.openBox('users');
    await Hive.openBox('session');
    await Hive.openBox('assignments');
  }

  Future<void> clearHiveBoxes() async {
    for (final name in boxNames) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).clear();
      }
    }
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpTestHive();
  });

  setUp(() async {
    await clearHiveBoxes();
    await openHiveBoxes();
  });

  tearDown(() async {
    await clearHiveBoxes();
    for (final name in boxNames) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).close();
      }
    }
  });

  tearDownAll(() async {
    await tearDownTestHive();
  });

  test('monthly rollover archives missing month and advances current month', () async {
    final reportSvc = ReportService();
    final orderSvc = OrderService();

    // Create an order in June 2026 to be archived
    await orderSvc.saveOrder(
      Order(
        id: 'o-june-1',
        orderNumber: 1,
        customerName: 'Cust',
        cashierName: 'Cash',
        items: [
          OrderItem(menuItemId: 'i1', name: 'Coffee', price: 100, icon: '☕'),
        ],
        subtotal: 100,
        discount: 0,
        discountLabel: '',
        total: 100,
        tendered: 100,
        change: 0,
        paymentMethod: PaymentMethod.cash,
        createdAt: DateTime(2026, 6, 15),
        status: OrderStatus.paid,
      ),
      deductInventory: false,
    );

    // Set stored month to June 2026 so currentReportMonth will trigger auto-transition
    await reportSvc.markMonthlyReset(DateTime(2026, 6));

    final monthAfter = await reportSvc.currentReportMonth();

    // currentReportMonth should now be the real current month (system month)
    final now = DateTime.now();
    expect(monthAfter.year, now.year);
    expect(monthAfter.month, now.month);

    // There should be at least one monthly archive recorded for June
    final archives = await reportSvc.fetchArchives(type: ReportType.monthly);
    final juneArchive = archives.any((a) => a.reportDate.year == 2026 && a.reportDate.month == 6);
    expect(juneArchive, isTrue);
  });

  testWidgets('daily report shows reset button', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReportsScreen(
        initialReportType: ReportType.daily,
        initialReportDate: DateTime(2026, 7, 17),
        initialReportMonth: DateTime(2026, 7),
      ),
    ));

    await tester.pumpAndSettle();
    expect(find.text('Reset Daily Report'), findsOneWidget);
  });

  testWidgets('monthly report shows reset button', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReportsScreen(
        initialReportType: ReportType.monthly,
        initialReportDate: DateTime(2026, 7, 17),
        initialReportMonth: DateTime(2026, 7),
      ),
    ));

    await tester.pumpAndSettle();
    expect(find.text('Reset Monthly Report'), findsOneWidget);
  });

  testWidgets('history screen uses a scrollable body', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: const HistoryScrollableBody(
        searchSection: SizedBox.shrink(),
        statsSection: SizedBox.shrink(),
        emptyState: SizedBox.shrink(),
        orderTiles: [SizedBox.shrink()],
      ),
    ));

    expect(find.byType(CustomScrollView), findsOneWidget);
  });

  testWidgets('monthly report keeps data after daily reset', (WidgetTester tester) async {
    final reportSvc = ReportService();
    final now = DateTime.now();
    final monthlyOrder = Order(
      id: 'monthly-reset-order',
      orderNumber: 99,
      customerName: 'Cust',
      cashierName: 'Cash',
      items: [
        OrderItem(menuItemId: 'i1', name: 'Coffee', price: 100, icon: '☕'),
      ],
      subtotal: 100,
      discount: 0,
      discountLabel: '',
      total: 100,
      tendered: 100,
      change: 0,
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime(now.year, now.month, now.day, 10),
      status: OrderStatus.paid,
    );

    print('monthly reset test: before resetDailyPeriod');
    await tester.runAsync(() async {
      await reportSvc.resetDailyPeriod(resetAt: now);
    });
    print('monthly reset test: after resetDailyPeriod');

    print('monthly reset test: before pumpWidget');
    await tester.pumpWidget(MaterialApp(
      home: ReportsScreen(
        initialReportType: ReportType.monthly,
        initialReportDate: now,
        initialReportMonth: DateTime(now.year, now.month),
        ordersStreamOverride: Stream.value([monthlyOrder]),
      ),
    ));
    print('monthly reset test: after pumpWidget');

    print('monthly reset test: before pumpAndSettle');
    await tester.pumpAndSettle();
    print('monthly reset test: after pumpAndSettle');
    expect(find.byKey(const Key('reportsCompletedOrders')), findsOneWidget);
  });

  test('hive direct put works in widget environment', () async {
    await Hive.box('orders').put('widget-test-order', {'foo': 'bar'});
    final result = Hive.box('orders').get('widget-test-order');
    expect(result, {'foo': 'bar'});
  });

  testWidgets('completed order appears in daily report analytics', (WidgetTester tester) async {
    final now = DateTime.now();
    final dailyOrder = Order(
      id: 'daily-complete-order',
      orderNumber: 101,
      customerName: 'Barista Customer',
      cashierName: 'Barista',
      items: [
        OrderItem(menuItemId: 'i2', name: 'Matcha', price: 120, icon: '🍵', qty: 2),
      ],
      subtotal: 240,
      discount: 0,
      discountLabel: '',
      total: 240,
      tendered: 240,
      change: 0,
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime(now.year, now.month, now.day, 11),
      status: OrderStatus.completed,
    );

    await tester.pumpWidget(MaterialApp(
      home: ReportsScreen(
        initialReportType: ReportType.daily,
        initialReportDate: DateTime(now.year, now.month, now.day),
        initialReportMonth: DateTime(now.year, now.month),
        ordersStreamOverride: Stream.value([dailyOrder]),
      ),
    ));

    await tester.pumpAndSettle();
    expect(find.text('Completed orders: 1'), findsNWidgets(2));
    expect(find.textContaining('Revenue:'), findsOneWidget);
  });

  testWidgets('reports screen shows month and year filters when Monthly selected', (WidgetTester tester) async {
    debugPrint('test start');
    await tester.pumpWidget(MaterialApp(
      home: ReportsScreen(
        initialReportType: ReportType.monthly,
        initialReportDate: DateTime(2026, 7, 17),
        initialReportMonth: DateTime(2026, 7),
      ),
    ));
    // Poll until the monthly chip is rendered.
    var found = false;
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Monthly Report').evaluate().isNotEmpty) {
        found = true;
        break;
      }
    }
    expect(found, isTrue, reason: 'ReportsScreen failed to render Monthly Report chip after waiting');

    // Monthly view is the initial selection for this test
    expect(find.text('Monthly Report'), findsOneWidget);

    final monthDropdownFinder = find.byKey(const Key('monthlyMonthDropdown'));
    final yearDropdownFinder = find.byKey(const Key('monthlyYearDropdown'));

    var dropdownsVisible = false;
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (monthDropdownFinder.evaluate().isNotEmpty &&
          yearDropdownFinder.evaluate().isNotEmpty) {
        dropdownsVisible = true;
        break;
      }
    }

    expect(dropdownsVisible, isTrue,
        reason: 'Monthly filters did not appear after waiting');
    expect(monthDropdownFinder, findsOneWidget);
    expect(yearDropdownFinder, findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
