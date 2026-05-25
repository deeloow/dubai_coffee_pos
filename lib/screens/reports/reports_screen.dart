import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/models.dart';
import '../../services/order_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderSvc = OrderService();
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Reports & Analytics')),
      body: StreamBuilder<List<Order>>(
        stream: orderSvc.ordersStream(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.gold)),
            );
          }

          final allOrders = snap.data!;
          final paid = allOrders
              .where((o) => o.status == OrderStatus.paid)
              .toList();

          final totalRev =
              paid.fold(0.0, (s, o) => s + o.total);
          final avgOrder =
              paid.isEmpty ? 0.0 : totalRev / paid.length;
          final topItem = _getTopItem(paid);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Stats
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.0,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StatCard(
                      label: 'Total Revenue',
                      value: formatPHP(totalRev),
                      gold: true,
                      delta: '↑ session'),
                  StatCard(
                      label: 'Orders',
                      value: '${paid.length}',
                      delta: 'paid orders'),
                  StatCard(
                      label: 'Avg Order Value',
                      value: formatPHP(avgOrder)),
                  StatCard(label: 'Top Item', value: topItem),
                ],
              ),
              const SizedBox(height: 16),

              // Top items bar chart
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.emoji_events_outlined,
                            size: 16, color: AppColors.gold),
                        SizedBox(width: 6),
                        AppText('Top Selling Items',
                            size: 14, weight: FontWeight.w600),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _TopItemsBars(orders: paid),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Payment breakdown
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.pie_chart_outline,
                            size: 16, color: AppColors.gold),
                        SizedBox(width: 6),
                        AppText('Sales by Payment Method',
                            size: 14, weight: FontWeight.w600),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _PaymentPieChart(orders: paid),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Hourly chart
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bar_chart,
                            size: 16, color: AppColors.gold),
                        SizedBox(width: 6),
                        AppText('Hourly Sales',
                            size: 14, weight: FontWeight.w600),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _HourlyBarChart(orders: paid),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getTopItem(List<Order> orders) {
    final counts = <String, int>{};
    for (final o in orders) {
      for (final i in o.items) {
        counts[i.name] = (counts[i.name] ?? 0) + i.qty;
      }
    }
    if (counts.isEmpty) return '—';
    return counts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}

class _TopItemsBars extends StatelessWidget {
  final List<Order> orders;

  const _TopItemsBars({required this.orders});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final o in orders) {
      for (final i in o.items) {
        counts[i.name] = (counts[i.name] ?? 0) + i.qty;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    final maxVal = top.isEmpty ? 1 : top.first.value;

    if (top.isEmpty) {
      return const AppText('No sales data yet',
          size: 12, color: AppColors.textMuted);
    }

    return Column(
      children: top.map((e) {
        final pct = e.value / maxVal;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: AppText(e.key,
                    size: 11, color: AppColors.brown2),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppColors.borderColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.gold),
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 50,
                child: AppText('${e.value} sold',
                    size: 11,
                    weight: FontWeight.w600,
                    color: AppColors.goldDark,
                    align: TextAlign.right),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PaymentPieChart extends StatelessWidget {
  final List<Order> orders;

  const _PaymentPieChart({required this.orders});

  @override
  Widget build(BuildContext context) {
    final methods = {
      'Cash': 0.0,
      'GCash': 0.0,
      'Card': 0.0,
      'PayMaya': 0.0
    };
    for (final o in orders) {
      methods[o.paymentMethodLabel] =
          (methods[o.paymentMethodLabel] ?? 0) + o.total;
    }
    final total = methods.values.fold(0.0, (a, b) => a + b);
    if (total == 0) {
      return const AppText('No payment data yet',
          size: 12, color: AppColors.textMuted);
    }

    final colors = [
      AppColors.espresso,
      AppColors.gold,
      AppColors.brown,
      AppColors.goldDark,
    ];

    final entries = methods.entries
        .where((e) => e.value > 0)
        .toList();

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: List.generate(entries.length, (i) {
                  final pct = entries[i].value / total * 100;
                  return PieChartSectionData(
                    color: colors[i % colors.length],
                    value: entries[i].value,
                    title: '${pct.toStringAsFixed(0)}%',
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.goldLight,
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(entries.length, (i) {
            final pct = entries[i].value / total * 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AppText(entries[i].key, size: 11),
                  const SizedBox(width: 4),
                  AppText('${pct.toStringAsFixed(0)}%',
                      size: 11,
                      weight: FontWeight.w600,
                      color: AppColors.goldDark),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _HourlyBarChart extends StatelessWidget {
  final List<Order> orders;

  const _HourlyBarChart({required this.orders});

  @override
  Widget build(BuildContext context) {
    // Aggregate by hour (8am-7pm = indices 0-11)
    final hourly = List.filled(12, 0.0);
    for (final o in orders) {
      final h = o.createdAt.hour;
      if (h >= 8 && h <= 19) {
        hourly[h - 8] += o.total;
      }
    }

    final maxY = hourly.reduce((a, b) => a > b ? a : b);
    final labels = [
      '8a', '9', '10', '11', '12', '1p', '2', '3', '4', '5', '6', '7'
    ];

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1000 : maxY * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY == 0 ? 500 : maxY / 4,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.borderColor,
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Text(
                  labels[v.toInt()],
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textMuted),
                ),
                reservedSize: 20,
              ),
            ),
          ),
          barGroups: List.generate(
            12,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: hourly[i] == 0 ? 0 : hourly[i],
                  color: AppColors.gold,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY == 0 ? 1000 : maxY * 1.2,
                    color: AppColors.bgLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
