import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive_test/hive_test.dart';

import 'package:dubai_coffee_pos/models/models.dart';
import 'package:dubai_coffee_pos/services/inventory_service.dart';
import 'package:dubai_coffee_pos/services/order_service.dart';
import 'package:dubai_coffee_pos/services/report_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setUpTestHive();
  });

  setUp(() async {
    await Hive.openBox('settings');
    await Hive.openBox('reports_history');
    await Hive.openBox('orders');
    await Hive.openBox('recipes');
    await Hive.openBox('inventory');
    await Hive.openBox('menu');
  });

  tearDown(() async {
    if (Hive.isBoxOpen('settings')) {
      await Hive.box('settings').clear();
    }
    if (Hive.isBoxOpen('reports_history')) {
      await Hive.box('reports_history').clear();
    }
    if (Hive.isBoxOpen('orders')) {
      await Hive.box('orders').clear();
    }
    if (Hive.isBoxOpen('recipes')) {
      await Hive.box('recipes').clear();
    }
    if (Hive.isBoxOpen('inventory')) {
      await Hive.box('inventory').clear();
    }
    if (Hive.isBoxOpen('menu')) {
      await Hive.box('menu').clear();
    }
  });

  tearDownAll(() async {
    await tearDownTestHive();
  });

  test('applyRemoteDailyState does not reset daily report data', () async {
    final service = ReportService();
    final settings = Hive.box('settings');

    await settings.put('daily_total_revenue', 123.45);
    await settings.put('daily_order_count', 5);
    await settings.put('daily_hourly_sales', {'09:00': 10.0});
    await settings.put('daily_analytics', {'foo': 'bar'});
    await settings.put('daily_dashboard_stats', {'baz': 'qux'});
    await settings.put('reporting_business_date', DateTime(2026, 7, 28).toIso8601String());

    await service.applyRemoteDailyState(DateTime(2026, 7, 29));

    expect(settings.get('daily_total_revenue'), 123.45);
    expect(settings.get('daily_order_count'), 5);
    expect(settings.get('daily_hourly_sales'), {'09:00': 10.0});
    expect(settings.get('daily_analytics'), {'foo': 'bar'});
    expect(settings.get('daily_dashboard_stats'), {'baz': 'qux'});
    expect(await service.currentReportDate(), DateTime(2026, 7, 28));
  });

  test('resetDailyPeriod restores default cup inventory levels', () async {
    final service = ReportService();
    final inventoryService = InventoryService();

    await inventoryService.seedInventoryIfEmpty();
    final twelveOz = (await inventoryService.fetchAllInventory())
        .firstWhere((item) => item.name.toLowerCase() == 'cups 12oz');
    final sixteenOz = (await inventoryService.fetchAllInventory())
        .firstWhere((item) => item.name.toLowerCase() == 'cups 16oz');

    await inventoryService.updateItem(twelveOz.copyWith(quantity: 18.0));
    await inventoryService.updateItem(sixteenOz.copyWith(quantity: 42.0));

    await service.resetDailyPeriod(resetAt: DateTime(2026, 7, 29));

    final updatedInventory = await inventoryService.fetchAllInventory();
    final updatedTwelveOz = updatedInventory.firstWhere((item) => item.name.toLowerCase() == 'cups 12oz');
    final updatedSixteenOz = updatedInventory.firstWhere((item) => item.name.toLowerCase() == 'cups 16oz');

    expect(updatedTwelveOz.quantity, 100.0);
    expect(updatedSixteenOz.quantity, 100.0);
    expect(updatedTwelveOz.servedQuantity, 0.0);
    expect(updatedSixteenOz.servedQuantity, 0.0);
  });

  test('resetDailyPeriod preserves report state while resetting inventory', () async {
    final service = ReportService();
    final settings = Hive.box('settings');

    await settings.put('daily_total_revenue', 123.45);
    await settings.put('daily_order_count', 5);
    await settings.put('daily_hourly_sales', {'09:00': 10.0});
    await settings.put('daily_analytics', {'foo': 'bar'});
    await settings.put('daily_dashboard_stats', {'baz': 'qux'});

    await service.resetDailyPeriod(resetAt: DateTime(2026, 7, 16, 8));

    expect(await service.currentReportDate(), DateTime(2026, 7, 16));
    expect(settings.get('daily_total_revenue'), 0.0);
    expect(settings.get('daily_order_count'), 0);
    expect(settings.get('daily_hourly_sales'), isA<Map>());
    expect(settings.get('daily_analytics'), isA<Map>());
    expect(settings.get('daily_dashboard_stats'), isA<Map>());
  });

  test('resetMonthlyReport does not clear daily report state', () async {
    final service = ReportService();
    final orderService = OrderService();
    final settings = Hive.box('settings');
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final currentDay = DateTime(now.year, now.month, now.day);
    final order = Order(
      id: 'monthly-reset-order',
      orderNumber: 1001,
      customerName: 'Test Customer',
      cashierName: 'Test Cashier',
      items: const [],
      subtotal: 5000,
      discount: 0,
      discountLabel: '',
      total: 5000,
      tendered: 5000,
      change: 0,
      paymentMethod: PaymentMethod.cash,
      createdAt: now,
      status: OrderStatus.paid,
    );

    await settings.put('reporting_business_date', currentDay.toIso8601String());
    await settings.put('reporting_business_month', currentMonth.toIso8601String());
    await settings.put('daily_total_revenue', 456.78);
    await settings.put('daily_order_count', 3);
    await settings.put('monthly_total_revenue', 999.99);
    await settings.put('monthly_order_count', 12);
    await orderService.saveOrder(order, deductInventory: false);

    await service.resetMonthlyReport(resetAt: currentMonth);

    expect(settings.get('daily_total_revenue'), 456.78);
    expect(settings.get('daily_order_count'), 3);
    expect(await service.currentReportDate(), currentDay);
    expect(settings.get('monthly_total_revenue'), isNull);
    expect(settings.get('monthly_order_count'), isNull);
    expect(await service.currentReportMonth(), currentMonth);
    expect(Hive.box('orders').get(order.id)['archivedAt'], isNull);
    expect(
      (await orderService.fetchOrders(includeArchived: false)).single.id,
      order.id,
    );
  });

  test('deleteArchive removes archive metadata and local file', () async {
    final service = ReportService();
    final history = Hive.box('reports_history');
    final tempDir = await Directory.systemTemp.createTemp('archive_delete_test_');
    final tempFile = File('${tempDir.path}/archive_test.pdf');
    await tempFile.writeAsString('stub pdf');

    final archive = DailyReportArchive(
      id: 'archive-delete-test',
      reportType: ReportType.daily,
      label: 'Delete Me',
      generatedAt: DateTime(2026, 7, 28),
      reportDate: DateTime(2026, 7, 28),
      orderCount: 1,
      totalRevenue: 100,
      receiptCount: 1,
      filePath: tempFile.path,
    );

    await history.put(archive.id, archive.toMap());
    expect(await tempFile.exists(), isTrue);

    await service.deleteArchive(archive.id);

    expect(await history.containsKey(archive.id), isFalse);
    expect(await service.fetchArchives(), isEmpty);
    expect(await tempFile.exists(), isFalse);

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });
}
