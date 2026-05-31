import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/auth_provider.dart';
import '../../services/order_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class ReportsScreen extends StatelessWidget {
  static const int _reportChartLimit = 800;

  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderSvc = OrderService();
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Reports & Analytics')),
      body: StreamBuilder<List<Order>>(
        stream: orderSvc.ordersStream(),
        initialData: const [],
        builder: (ctx, snap) {
          if (snap.hasError) {
            return const Center(
              child: Text('Unable to load reports.'),
            );
          }

          final allOrders = snap.data!;
          final paid =
              allOrders.where((o) => o.status == OrderStatus.paid).toList();

          final totalRev = paid.fold(0.0, (s, o) => s + o.total);
          final avgOrder = paid.isEmpty ? 0.0 : totalRev / paid.length;
          final displayOrders = paid.length > _reportChartLimit
              ? paid.take(_reportChartLimit).toList()
              : paid;
          final topItem = _getTopItem(displayOrders);

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
                      label: 'Avg Order Value', value: formatPHP(avgOrder)),
                  StatCard(label: 'Top Item', value: topItem),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Save Daily Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.espresso,
                      ),
                      onPressed: () async {
                        await _saveReportPdf(context, paid, isDaily: true);
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Save Total Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brown,
                      ),
                      onPressed: () async {
                        await _saveReportPdf(context, paid, isDaily: false);
                      },
                    ),
                  ],
                ),
              ),
              if (paid.length > _reportChartLimit)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: AppText(
                    'Showing analytics for the latest $_reportChartLimit paid orders for better performance.',
                    size: 12,
                    color: AppColors.textMuted,
                  ),
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
                    _TopItemsBars(orders: displayOrders),
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
                    _PaymentPieChart(orders: displayOrders),
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
                        Icon(Icons.bar_chart, size: 16, color: AppColors.gold),
                        SizedBox(width: 6),
                        AppText('Hourly Sales',
                            size: 14, weight: FontWeight.w600),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _HourlyBarChart(orders: displayOrders),
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
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Future<void> _saveReportPdf(BuildContext context, List<Order> paidOrders,
      {required bool isDaily}) async {
    final baristaName = context.read<AuthProvider>().user?.name ?? 'Unknown';
    final now = DateTime.now();
    final reportType = isDaily ? 'Daily' : 'Total';
    final title = '$reportType Sales Report';
    final filteredOrders = isDaily
        ? paidOrders.where((o) => _isSameDate(o.createdAt, now)).toList()
        : paidOrders;

    if (filteredOrders.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('No ${isDaily ? 'daily' : 'total'} paid orders to save.'),
          ),
        );
      }
      return;
    }

    // Show directory picker
    final selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select folder to save PDF',
      lockParentWindow: true,
    );

    if (selectedDirectory == null) {
      // User cancelled the picker
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF save cancelled')),
        );
      }
      return;
    }

    final fileName =
        '${_sanitizeFileName(reportType)}Report_${_sanitizeFileName(baristaName)}_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
    final outputFile = File('$selectedDirectory/$fileName');

    final totalRev =
        filteredOrders.fold(0.0, (double sum, Order o) => sum + o.total);
    final avgOrder =
        filteredOrders.isEmpty ? 0.0 : totalRev / filteredOrders.length;
    final topItem = _getTopItem(filteredOrders);
    final reportDate = DateFormat('MMM d, yyyy hh:mm a').format(now);

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              title,
              style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Barista: $baristaName',
              style: const pw.TextStyle(fontSize: 14)),
          pw.Text('Generated on: $reportDate',
              style: const pw.TextStyle(fontSize: 14)),
          pw.Text(
              'Report period: ${isDaily ? DateFormat('MMMM d, yyyy').format(now) : 'All time'}',
              style: const pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 16),
          pw.Text('Summary',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Bullet(text: 'Report type: $reportType'),
          pw.Bullet(text: 'Total paid orders: ${filteredOrders.length}'),
          pw.Bullet(text: 'Total revenue: ${formatPHP(totalRev)}'),
          pw.Bullet(text: 'Average order value: ${formatPHP(avgOrder)}'),
          pw.Bullet(text: 'Top item: $topItem'),
          pw.SizedBox(height: 16),
          pw.Text('Payment Breakdown',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _buildPaymentTable(filteredOrders),
          pw.SizedBox(height: 16),
          pw.Text('Top Selling Items',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _buildTopItemsTable(filteredOrders),
        ],
      ),
    );

    try {
      await outputFile.writeAsBytes(await pdf.save());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved: $fileName'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save PDF: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  pw.Widget _buildPaymentTable(List<Order> paidOrders) {
    final totals = <String, double>{};
    for (final order in paidOrders) {
      totals[order.paymentMethodLabel] =
          (totals[order.paymentMethodLabel] ?? 0) + order.total;
    }

    return pw.TableHelper.fromTextArray(
      headers: ['Payment Method', 'Amount'],
      data: totals.entries
          .map((entry) => [entry.key, formatPHP(entry.value)])
          .toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellHeight: 20,
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
    );
  }

  pw.Widget _buildTopItemsTable(List<Order> paidOrders) {
    final counts = <String, int>{};
    for (final order in paidOrders) {
      for (final item in order.items) {
        counts[item.name] = (counts[item.name] ?? 0) + item.qty;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.TableHelper.fromTextArray(
      headers: ['Item', 'Qty Sold'],
      data: sorted.map((entry) => [entry.key, entry.value.toString()]).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellHeight: 20,
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
    );
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
                child: AppText(e.key, size: 11, color: AppColors.brown2),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppColors.borderColor,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.gold),
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
    final methods = {'Cash': 0.0, 'GCash': 0.0, 'Card': 0.0, 'PayMaya': 0.0};
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

    final entries = methods.entries.where((e) => e.value > 0).toList();

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
      '8a',
      '9',
      '10',
      '11',
      '12',
      '1p',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7'
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
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Text(
                  labels[v.toInt()],
                  style:
                      const TextStyle(fontSize: 9, color: AppColors.textMuted),
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
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(3)),
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
