import 'package:flutter_test/flutter_test.dart';

import 'package:dubai_coffee_pos/models/models.dart';
import 'package:dubai_coffee_pos/services/report_pdf_utils.dart';

void main() {
  test('buildReportSummary aggregates completed orders only', () {
    final orders = [
      Order(
        id: 'order-1',
        orderNumber: 1,
        customerName: 'Alice',
        cashierName: 'Cashier',
        items: [
          OrderItem(
            menuItemId: 'matcha',
            name: 'Matcha',
            price: 60,
            icon: '🍵',
            qty: 2,
            cupSize: '12oz',
          ),
          OrderItem(
            menuItemId: 'lemonade',
            name: 'Fresh Lemon',
            price: 50,
            icon: '🍋',
            qty: 1,
            cupSize: '16oz',
          ),
        ],
        subtotal: 170,
        discount: 0,
        discountLabel: '',
        total: 170,
        tendered: 170,
        change: 0,
        paymentMethod: PaymentMethod.cash,
        createdAt: DateTime(2026, 7, 14, 10),
        status: OrderStatus.completed,
      ),
      Order(
        id: 'order-2',
        orderNumber: 2,
        customerName: 'Bob',
        cashierName: 'Cashier',
        items: [
          OrderItem(
            menuItemId: 'macchiato',
            name: 'Caramel Macchiato',
            price: 80,
            icon: '☕',
            qty: 1,
            cupSize: '16oz',
          ),
        ],
        subtotal: 80,
        discount: 0,
        discountLabel: '',
        total: 80,
        tendered: 80,
        change: 0,
        paymentMethod: PaymentMethod.gcash,
        createdAt: DateTime(2026, 7, 14, 11),
        status: OrderStatus.paid,
      ),
      Order(
        id: 'order-3',
        orderNumber: 3,
        customerName: 'Cara',
        cashierName: 'Cashier',
        items: [
          OrderItem(
            menuItemId: 'matcha',
            name: 'Matcha',
            price: 60,
            icon: '🍵',
            qty: 1,
            cupSize: '12oz',
          ),
        ],
        subtotal: 60,
        discount: 0,
        discountLabel: '',
        total: 60,
        tendered: 60,
        change: 0,
        paymentMethod: PaymentMethod.cash,
        createdAt: DateTime(2026, 7, 15, 9),
        status: OrderStatus.voided,
      ),
    ];

    final summary = buildReportSummary(orders);

    expect(summary.totalOrders, 2);
    expect(summary.totalDrinksSold, 4);
    expect(summary.totalSales, 250);
    expect(summary.cups12oz, 2);
    expect(summary.cups16oz, 2);
    expect(summary.paymentTotals['Cash'], 170);
    expect(summary.paymentTotals['GCash'], 80);
    expect(summary.drinkSales['Matcha'], 2);
    expect(summary.drinkSales['Caramel Macchiato'], 1);
    expect(summary.drinkSales['Fresh Lemon'], 1);
  });

  test('sanitizePdfText removes emoji and other unsupported characters', () {
    expect(sanitizePdfText('Daily Report 📊'), 'Daily Report');
    expect(sanitizePdfText('Coffee ☕'), 'Coffee');
    expect(sanitizePdfText('Receipt • Summary'), 'Receipt Summary');
  });
}
