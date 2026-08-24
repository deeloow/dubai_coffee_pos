import '../models/models.dart';

class ReportPdfSummary {
  final int totalOrders;
  final int totalDrinksSold;
  final double totalSales;
  final int cups12oz;
  final int cups16oz;
  final Map<String, double> paymentTotals;
  final Map<String, int> drinkSales;

  const ReportPdfSummary({
    required this.totalOrders,
    required this.totalDrinksSold,
    required this.totalSales,
    required this.cups12oz,
    required this.cups16oz,
    required this.paymentTotals,
    required this.drinkSales,
  });
}

String sanitizePdfText(String input) {
  final cleaned = input
      .replaceAll(RegExp(r'[^\u0000-\u007F]'), ' ')
      .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned;
}

String formatPdfCurrency(double amount) {
  final value = amount.toStringAsFixed(2).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return '₱$value';
}

ReportPdfSummary buildReportSummary(List<Order> orders) {
  final includedOrders = orders.where((order) {
    return order.status == OrderStatus.paid || order.status == OrderStatus.completed;
  }).toList();

  final paymentTotals = <String, double>{};
  final drinkSales = <String, int>{};
  var totalDrinksSold = 0;
  var cups12oz = 0;
  var cups16oz = 0;
  var totalSales = 0.0;

  for (final order in includedOrders) {
    final orderValue = order.total as num;
    totalSales += orderValue.toDouble();

    final paymentLabel = order.paymentMethodLabel as String;
    paymentTotals[paymentLabel] = (paymentTotals[paymentLabel] ?? 0.0) + orderValue.toDouble();

    final lineItems = order.items.where((item) => item.qty > 0).toList();
    for (final item in lineItems) {
      final qty = item.qty as int;
      totalDrinksSold += qty;
      final name = item.name.toString();
      drinkSales[name] = (drinkSales[name] ?? 0) + qty;

      final cupSize = item.cupSize.toString();
      if (cupSize == '12oz') {
        cups12oz += qty;
      } else if (cupSize == '16oz') {
        cups16oz += qty;
      }
    }
  }

  return ReportPdfSummary(
    totalOrders: includedOrders.length,
    totalDrinksSold: totalDrinksSold,
    totalSales: totalSales,
    cups12oz: cups12oz,
    cups16oz: cups16oz,
    paymentTotals: paymentTotals,
    drinkSales: drinkSales,
  );
}
