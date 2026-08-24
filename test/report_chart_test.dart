import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dubai_coffee_pos/models/models.dart';
import 'package:dubai_coffee_pos/screens/reports/report_chart_utils.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tempDir = Directory.systemTemp.createTempSync('hive_report_chart_test');
    Hive.init(tempDir.path);
    await Hive.openBox('orders');
  });

  test('daily chart uses completed orders for hourly revenue', () async {
    final completed = Order(
      id: '1',
      orderNumber: 1,
      customerName: 'Test',
      cashierName: 'Test',
      items: [
        OrderItem(
          menuItemId: 'm1',
          name: 'Coffee',
          price: 50,
          icon: '☕',
          qty: 1,
          cupSize: '16oz',
        ),
      ],
      subtotal: 50,
      discount: 0,
      discountLabel: 'No discount',
      total: 50,
      tendered: 50,
      change: 0,
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime(2026, 7, 20, 14, 30),
      status: OrderStatus.completed,
    );

    final pending = completed.copyWith(id: '2', status: OrderStatus.paid);
    final voided = completed.copyWith(id: '3', status: OrderStatus.voided);

    final series = ReportChartUtils.buildHourlyRevenueSeries([completed, pending, voided]);

    expect(series[14], 100);
    expect(series[14], isNot(0));
    expect(ReportChartUtils.hasHourlyRevenueData([completed, pending, voided]), isTrue);
  });
}
