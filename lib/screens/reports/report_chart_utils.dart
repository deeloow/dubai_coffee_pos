import '../../models/models.dart';

class ReportChartUtils {
  static List<double> buildHourlyRevenueSeries(List<Order> orders) {
    final hourly = List<double>.filled(24, 0.0);
    for (final order in orders) {
      final isCompletedOrder =
          order.status == OrderStatus.paid || order.status == OrderStatus.completed;
      if (!isCompletedOrder) {
        continue;
      }

      final hour = order.createdAt.toLocal().hour;
      hourly[hour] += order.total;
    }
    return hourly;
  }

  static bool hasHourlyRevenueData(List<Order> orders) {
    return buildHourlyRevenueSeries(orders).any((value) => value > 0);
  }
}
