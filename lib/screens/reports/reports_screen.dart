import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../models/models.dart';
import '../../services/auth_provider.dart';
import '../../services/local_order_socket_provider.dart';
import '../../services/order_service.dart';
import '../../services/report_pdf_utils.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import 'report_chart_utils.dart';

class ReportsScreen extends StatefulWidget {
  final ReportType? initialReportType;
  final DateTime? initialReportDate;
  final DateTime? initialReportMonth;
  final Stream<List<Order>>? ordersStreamOverride;
  const ReportsScreen({
    super.key,
    this.initialReportType,
    this.initialReportDate,
    this.initialReportMonth,
    this.ordersStreamOverride,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  OrderService? _orderSvc;
  ReportService? _reportSvc;

  ReportService get _reportSvcLoc => _reportSvc ??= ReportService();
  DateTime _reportDate = DateTime.now();
  DateTime _reportMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _viewingMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _selectedMonthDay = DateTime.now().day;
  late Future<void> _loadFuture;
  late ReportType _selectedReportType;
  StreamSubscription<DateTime>? _reportDateSub;
  StreamSubscription<DateTime>? _reportMonthSub;
  final _archiveListKey = GlobalKey<_ArchivedReportsListState>();

  @override
  void initState() {
    super.initState();
    _selectedReportType = widget.initialReportType ?? ReportType.daily;
    if (widget.initialReportDate != null) {
      _reportDate = widget.initialReportDate!;
    }
    if (widget.initialReportMonth != null) {
      _reportMonth = widget.initialReportMonth!;
      _viewingMonth = widget.initialReportMonth!;
      _syncSelectedMonthDay();
    }
    _loadFuture = _loadReportPeriods();
    _loadFuture.whenComplete(() {
      if (!mounted) return;
      if (widget.initialReportDate == null &&
          widget.initialReportMonth == null) {
        _reportDateSub ??= _reportSvcLoc.reportDateStream().listen((date) {
          if (mounted) {
            setState(() => _reportDate = date);
          }
        });
        _reportMonthSub ??= _reportSvcLoc.reportMonthStream().listen((month) {
          if (mounted) {
            setState(() {
              _reportMonth = month;
              _viewingMonth = month;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _reportDateSub?.cancel();
    _reportMonthSub?.cancel();
    super.dispose();
  }

  Future<void> _loadReportPeriods() async {
    if (widget.initialReportDate != null && widget.initialReportMonth != null) {
      return;
    }

    try {
      _reportDate = await _reportSvcLoc.currentReportDate();
      _reportMonth = await _reportSvcLoc.currentReportMonth();
      _viewingMonth = _reportMonth;
      _syncSelectedMonthDay();
    } catch (e, st) {
      debugPrint('ReportsScreen: loadReportPeriods failed $e\n$st');
      _reportDate = DateTime.now();
      _reportMonth = DateTime(DateTime.now().year, DateTime.now().month);
      _viewingMonth = _reportMonth;
      _syncSelectedMonthDay();
    }
  }

  void _syncSelectedMonthDay() {
    final month = _viewingMonth;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    if (_selectedMonthDay > daysInMonth) {
      final today = DateTime.now();
      if (today.year == month.year && today.month == month.month) {
        _selectedMonthDay = today.day;
      } else {
        _selectedMonthDay = 1;
      }
    }
  }

  List<Order> _filterOrdersByReportType(
      List<Order> orders, ReportType reportType) {
    if (reportType == ReportType.daily) {
      final date = _reportDate;
      return orders.where((o) => _isSameDate(o.createdAt, date)).toList();
    }
    final month = _viewingMonth;
    return orders
        .where((o) =>
            o.createdAt.year == month.year && o.createdAt.month == month.month)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveLayout.of(context);
    final isLandscape = responsive.isLandscape;
    final ordersStream = widget.ordersStreamOverride ??
        (Platform.environment['FLUTTER_TEST'] == 'true'
            ? Stream<List<Order>>.value(const [])
            : (_orderSvc ??= OrderService()).ordersStream(
                includeArchived: _selectedReportType == ReportType.monthly,
              ));

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Reports & Analytics')),
      body: StreamBuilder<List<Order>>(
        stream: ordersStream,
        initialData: const [],
        builder: (context, snapshot) {
          final orders = snapshot.data ?? [];
          final reportOrders =
              _filterOrdersByReportType(orders, _selectedReportType);
          final completedOrders = reportOrders
              .where((o) =>
                  o.status == OrderStatus.paid ||
                  o.status == OrderStatus.completed)
              .toList();
          final voidedOrders = reportOrders
              .where((o) => o.status == OrderStatus.voided)
              .toList();
          final totalRevenue = completedOrders.fold(0.0, (sum, order) => sum + order.total);
          final averageOrderValue = completedOrders.isEmpty
              ? 0.0
              : totalRevenue / completedOrders.length;
          final topItem = _getTopItem(completedOrders);
          final reportLabel =
              _selectedReportType == ReportType.daily ? 'Daily' : 'Monthly';
          final reportDateLabel = _selectedReportType == ReportType.daily
              ? DateFormat('MMMM d, yyyy').format(_reportDate)
              : DateFormat('MMMM yyyy').format(_viewingMonth);

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isLandscape ? 12 : 16, vertical: isLandscape ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionCard(
                  child: Padding(
                    padding: EdgeInsets.all(isLandscape ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Daily Report',
                                    style: TextStyle(color: AppColors.black)),
                                selected:
                                    _selectedReportType == ReportType.daily,
                                onSelected: (_) => setState(() =>
                                    _selectedReportType = ReportType.daily),
                                labelStyle:
                                    const TextStyle(color: AppColors.black),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Monthly Report',
                                    style: TextStyle(color: AppColors.black)),
                                selected:
                                    _selectedReportType == ReportType.monthly,
                                onSelected: (_) => setState(() =>
                                    _selectedReportType = ReportType.monthly),
                                labelStyle:
                                    const TextStyle(color: AppColors.black),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isLandscape ? 10 : 16),
                        AppText('$reportLabel Analytics',
                            size: 18, weight: FontWeight.w700),
                        const SizedBox(height: 4),
                        AppText(reportDateLabel,
                            size: 12, color: AppColors.textMuted),
                        SizedBox(height: isLandscape ? 10 : 16),
                        if (_selectedReportType == ReportType.monthly)
                          Row(
                            children: [
                              DropdownButton<int>(
                                key: const Key('monthlyMonthDropdown'),
                                value: _viewingMonth.month,
                                items: List.generate(12, (i) => i + 1)
                                    .map((m) => DropdownMenuItem(
                                          value: m,
                                          child: Text(DateFormat('MMMM')
                                              .format(DateTime(0, m))),
                                        ))
                                    .toList(),
                                onChanged: (m) {
                                  if (m == null) return;
                                  setState(() {
                                    _viewingMonth =
                                        DateTime(_viewingMonth.year, m);
                                  });
                                  _syncSelectedMonthDay();
                                },
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<int>(
                                key: const Key('monthlyYearDropdown'),
                                value: _viewingMonth.year,
                                items: List.generate(
                                        6, (i) => DateTime.now().year - 5 + i)
                                    .map((y) => DropdownMenuItem(
                                          value: y,
                                          child: Text('$y'),
                                        ))
                                    .toList(),
                                onChanged: (y) {
                                  if (y == null) return;
                                  setState(() {
                                    _viewingMonth =
                                        DateTime(y, _viewingMonth.month);
                                  });
                                  _syncSelectedMonthDay();
                                },
                              ),
                            ],
                          ),
                        SizedBox(height: isLandscape ? 10 : 20),
                        if (isLandscape)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              SizedBox(
                                width: responsive.isTablet ? 180 : 160,
                                child: StatCard(
                                  label: 'Revenue',
                                  value: formatPHP(totalRevenue),
                                  gold: true,
                                  delta: reportLabel,
                                  compact: true,
                                ),
                              ),
                              SizedBox(
                                width: responsive.isTablet ? 180 : 160,
                                child: StatCard(
                                  label: 'Orders',
                                  value: '${completedOrders.length}',
                                  delta: 'completed',
                                  compact: true,
                                ),
                              ),
                              SizedBox(
                                width: responsive.isTablet ? 180 : 160,
                                child: StatCard(
                                  label: 'Avg Order',
                                  value: formatPHP(averageOrderValue),
                                  compact: true,
                                ),
                              ),
                              SizedBox(
                                width: responsive.isTablet ? 180 : 160,
                                child: StatCard(
                                  label: 'Top Item',
                                  value: topItem,
                                  compact: true,
                                ),
                              ),
                            ],
                          )
                        else
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.45,
                            children: [
                              StatCard(
                                label: 'Revenue',
                                value: formatPHP(totalRevenue),
                                gold: true,
                                delta: reportLabel,
                              ),
                              StatCard(
                                label: 'Orders',
                                value: '${completedOrders.length}',
                                delta: 'completed',
                              ),
                              StatCard(
                                label: 'Avg Order',
                                value: formatPHP(averageOrderValue),
                              ),
                              StatCard(
                                label: 'Top Item',
                                value: topItem,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: isLandscape ? 8 : 12),
                _buildPanelSection(
                  'Reset & Export',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          if (_selectedReportType == ReportType.daily)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('Reset Daily Report'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.red,
                                foregroundColor: AppColors.white,
                              ),
                              onPressed: () => _confirmResetDailyReport(
                                  context, completedOrders),
                            ),
                          if (_selectedReportType == ReportType.monthly)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('Reset Monthly Report'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.red,
                                foregroundColor: AppColors.white,
                              ),
                              onPressed: () => _confirmResetMonthlyReport(
                                  context, completedOrders),
                            ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf),
                            label: Text(_selectedReportType == ReportType.daily
                                ? 'Export Daily PDF'
                                : 'Export Monthly PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.espresso,
                              foregroundColor: AppColors.goldLight,
                            ),
                            onPressed: () => _saveReportPdf(
                              context,
                              completedOrders,
                              reportType: _selectedReportType,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AppText(
                        _selectedReportType == ReportType.daily
                            ? 'Daily report resets start a new reporting period while preserving archived records.'
                            : 'Monthly reporting stays linked to the selected month and year.',
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isLandscape ? 6 : 8),
                if (isLandscape)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: responsive.isTablet ? 320 : 260,
                        child: _buildPanelSection(
                          '$reportLabel Sales Summary',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                'Completed orders: ${completedOrders.length}',
                                key: const Key('reportsCompletedOrders'),
                                size: 12,
                              ),
                              const SizedBox(height: 6),
                              AppText('Voided orders: ${voidedOrders.length}',
                                  size: 12),
                              const SizedBox(height: 6),
                              AppText('Revenue: ${formatPHP(totalRevenue)}', size: 12),
                              const SizedBox(height: 6),
                              AppText(
                                  'Average order value: ${formatPHP(averageOrderValue)}',
                                  size: 12),
                              const SizedBox(height: 6),
                              AppText('Top item: $topItem', size: 12),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: responsive.isTablet ? 320 : 260,
                        child: _buildPanelSection(
                          '$reportLabel Analytics',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText('Order Summary', size: 13, weight: FontWeight.w600),
                              const SizedBox(height: 8),
                              _buildOrderTrendSummary(completedOrders, voidedOrders),
                              const SizedBox(height: 12),
                              AppText('Daily Sales Trend', size: 13, weight: FontWeight.w600),
                              const SizedBox(height: 8),
                              _dailySalesTrend(orders: completedOrders),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  _buildPanelSection(
                    '$reportLabel Sales Summary',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'Completed orders: ${completedOrders.length}',
                          key: const Key('reportsCompletedOrders'),
                          size: 12,
                        ),
                        const SizedBox(height: 6),
                        AppText('Voided orders: ${voidedOrders.length}',
                            size: 12),
                        const SizedBox(height: 6),
                        AppText('Revenue: ${formatPHP(totalRevenue)}', size: 12),
                        const SizedBox(height: 6),
                        AppText(
                            'Average order value: ${formatPHP(averageOrderValue)}',
                            size: 12),
                        const SizedBox(height: 6),
                        AppText('Top item: $topItem', size: 12),
                      ],
                    ),
                  ),
                SizedBox(height: isLandscape ? 6 : 8),
                SizedBox(height: isLandscape ? 6 : 8),
                _buildPanelSection(
                  'Dine-In & Take-Out Statistics',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                          'Dine-In orders: ${completedOrders.where((o) => o.orderType == OrderType.dineIn).length}',
                          size: 12),
                      const SizedBox(height: 6),
                      AppText(
                          'Take-Out orders: ${completedOrders.where((o) => o.orderType == OrderType.takeOut).length}',
                          size: 12),
                      const SizedBox(height: 6),
                      AppText(
                          'Dine-In revenue: ${formatPHP(completedOrders.where((o) => o.orderType == OrderType.dineIn).fold(0.0, (sum, order) => sum + order.total))}',
                          size: 12),
                      const SizedBox(height: 6),
                      AppText(
                          'Take-Out revenue: ${formatPHP(completedOrders.where((o) => o.orderType == OrderType.takeOut).fold(0.0, (sum, order) => sum + order.total))}',
                          size: 12),
                    ],
                  ),
                ),
                SizedBox(height: isLandscape ? 6 : 8),
                _buildPanelSection(
                  'Payment Method Breakdown',
                  _PaymentPieChart(orders: completedOrders),
                ),
                SizedBox(height: isLandscape ? 6 : 8),
                _buildPanelSection(
                  'Top Selling Items',
                  _buildBestSellingList(completedOrders),
                ),
                SizedBox(height: isLandscape ? 6 : 8),
                if (_selectedReportType == ReportType.monthly)
                  _buildPanelSection(
                    'Daily Sales Graph',
                    _buildMonthlyDailySalesPanel(
                      orders: reportOrders,
                      month: _viewingMonth,
                    ),
                  )
                else
                  _buildPanelSection(
                    'Daily Statistics',
                    _HourlyBarChart(orders: completedOrders),
                  ),
                SizedBox(height: isLandscape ? 6 : 8),
                _buildPanelSection(
                  'Archive Reports & History',
                  _ArchivedReportsList(
                    key: _archiveListKey,
                    onDownload: (archive) => _downloadArchivedReport(context, archive),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthlyDailySalesPanel(
      {required List<Order> orders, required DateTime month}) {
    final dayTotals = <double>[];
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    for (var day = 1; day <= daysInMonth; day++) {
      final dayOrders = orders
          .where((order) =>
              order.createdAt.year == month.year &&
              order.createdAt.month == month.month &&
              order.createdAt.day == day)
          .toList();
      dayTotals.add(dayOrders.fold(0.0, (sum, order) => sum + order.total));
    }

    final maxValue =
        dayTotals.isEmpty ? 1.0 : dayTotals.reduce((a, b) => a > b ? a : b);
    final selectedDay = _selectedMonthDay;
    final selectedDate = DateTime(month.year, month.month, selectedDay);
    final selectedOrders = orders
        .where((order) =>
            order.createdAt.year == selectedDate.year &&
            order.createdAt.month == selectedDate.month &&
            order.createdAt.day == selectedDate.day)
        .toList();
    final selectedCompleted = selectedOrders
        .where((order) =>
            order.status == OrderStatus.paid ||
            order.status == OrderStatus.completed)
        .toList();
    final selectedVoided = selectedOrders
        .where((order) => order.status == OrderStatus.voided)
        .toList();
    final selectedRevenue =
        selectedCompleted.fold(0.0, (sum, order) => sum + order.total);
    final selectedAverage = selectedCompleted.isEmpty
        ? 0.0
        : selectedRevenue / selectedCompleted.length;
    final selectedDineIn = selectedCompleted
        .where((order) => order.orderType == OrderType.dineIn)
        .length;
    final selectedTakeOut = selectedCompleted
        .where((order) => order.orderType == OrderType.takeOut)
        .length;

    final counts = <String, int>{};
    for (final order in selectedCompleted) {
      for (final item in order.items) {
        counts[item.name] = (counts[item.name] ?? 0) + item.qty;
      }
    }
    final topItems = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topItemName = topItems.isEmpty ? '—' : topItems.first.key;

    final paymentBreakdown = <String, double>{};
    for (final order in selectedCompleted) {
      paymentBreakdown[order.paymentMethodLabel] =
          (paymentBreakdown[order.paymentMethodLabel] ?? 0.0) + order.total;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final chartHeight = (constraints.maxWidth > 740 ? 280 : 220)
                .clamp(180.0, 320.0)
                .toDouble();
            return SizedBox(
              height: chartHeight,
              child: BarChart(
                BarChartData(
                  maxY: maxValue == 0 ? 1000.0 : maxValue * 1.2,
                  barTouchData: BarTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.spot == null) {
                        return;
                      }
                      final touchedIndex = response.spot!.touchedBarGroupIndex;
                      if (touchedIndex >= 0 && mounted) {
                        setState(() => _selectedMonthDay = touchedIndex + 1);
                      }
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval:
                            maxValue == 0 ? 500.0 : (maxValue / 3).toDouble(),
                        getTitlesWidget: (value, _) => Text(
                          value == 0 ? '₱0' : formatPHP(value.toDouble()),
                          style: const TextStyle(
                              fontSize: 9, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          final day = index + 1;
                          final showLabel =
                              day == 1 || day == daysInMonth || day % 5 == 0;
                          if (!showLabel) {
                            return const SizedBox.shrink();
                          }
                          return Text('$day',
                              style: const TextStyle(
                                  fontSize: 9, color: AppColors.textMuted));
                        },
                        reservedSize: 20,
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.borderColor,
                      strokeWidth: 0.5,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(daysInMonth, (index) {
                    final value = dayTotals[index];
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          color: index + 1 == selectedDay
                              ? AppColors.goldDark
                              : AppColors.gold,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxValue == 0 ? 1000.0 : maxValue * 1.2,
                            color: AppColors.bgLight,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderColor, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                  'Selected Day: ${DateFormat('MMM d').format(selectedDate)}',
                  size: 13,
                  weight: FontWeight.w600),
              const SizedBox(height: 8),
              AppText('Revenue: ${formatPHP(selectedRevenue)}', size: 12),
              AppText('Orders: ${selectedCompleted.length}', size: 12),
              AppText('Average Order Value: ${formatPHP(selectedAverage)}',
                  size: 12),
              AppText('Dine-In Orders: $selectedDineIn', size: 12),
              AppText('Take-Out Orders: $selectedTakeOut', size: 12),
              AppText('Voided Orders: ${selectedVoided.length}', size: 12),
              AppText('Top Item: $topItemName', size: 12),
              const SizedBox(height: 6),
              AppText('Payment Breakdown', size: 12, weight: FontWeight.w600),
              const SizedBox(height: 4),
              if (paymentBreakdown.isEmpty)
                const AppText('No payment data',
                    size: 12, color: AppColors.textMuted)
              else
                Column(
                  children: paymentBreakdown.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(child: AppText(entry.key, size: 11)),
                          AppText(formatPHP(entry.value),
                              size: 11, weight: FontWeight.w600),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPanelSection(String title, Widget child) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(title, size: 14, weight: FontWeight.w600),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _dailySalesTrend({required List<Order> orders}) {
    if (orders.isEmpty) {
      return const AppText('No sales activity yet.',
          size: 12, color: AppColors.textMuted);
    }

    final dayTotals = <String, double>{};
    for (final order in orders) {
      final dayLabel = DateFormat('MMM d').format(order.createdAt.toLocal());
      dayTotals[dayLabel] = (dayTotals[dayLabel] ?? 0.0) + order.total;
    }

    final sorted = dayTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sorted.take(6).map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(child: AppText(entry.key, size: 12)),
              AppText(formatPHP(entry.value),
                  size: 12, weight: FontWeight.w600),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOrderTrendSummary(
      List<Order> completedOrders, List<Order> voidedOrders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText('Completed orders: ${completedOrders.length}', size: 12),
        const SizedBox(height: 6),
        AppText('Voided orders: ${voidedOrders.length}', size: 12),
        const SizedBox(height: 6),
        AppText('Peak sales hour: ${_getPeakHourLabel(completedOrders)}',
            size: 12),
        const SizedBox(height: 6),
        AppText(
            'Avg revenue per order: ${formatPHP(completedOrders.isEmpty ? 0 : completedOrders.fold(0.0, (sum, o) => sum + o.total) / completedOrders.length)}',
            size: 12),
      ],
    );
  }

  Widget _buildBestSellingList(List<Order> completedOrders) {
    final counts = <String, int>{};
    for (final order in completedOrders) {
      for (final item in order.items) {
        counts[item.name] = (counts[item.name] ?? 0) + item.qty;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) {
      return const AppText('No sales data yet.',
          size: 12, color: AppColors.textMuted);
    }
    return Column(
      children: sorted.take(5).map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: AppText(entry.key, size: 12)),
              AppText('${entry.value} sold', size: 12, weight: FontWeight.w600),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getPeakHourLabel(List<Order> orders) {
    final hourly = List.filled(24, 0.0);
    for (final order in orders) {
      final hour = order.createdAt.toLocal().hour;
      hourly[hour] += order.total;
    }
    if (hourly.every((value) => value == 0)) {
      return 'No sales yet';
    }
    final maxHour = hourly
        .indexWhere((value) => value == hourly.reduce((a, b) => a > b ? a : b));
    final displayHour = maxHour % 12 == 0 ? 12 : maxHour % 12;
    final suffix = maxHour < 12 ? 'AM' : 'PM';
    return '$displayHour$suffix';
  }

  Future<void> _confirmResetDailyReport(
      BuildContext context, List<Order> paidOrders) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: DialogHeader(
          title: 'Reset Daily Report',
          onClose: () => Navigator.pop(dialogContext, false),
        ),
        content: const Text(
            'Are you sure you want to reset today\'s report? This will start a new reporting period while preserving archived records.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset Monthly Report'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final totalRev = paidOrders.fold(0.0, (sum, order) => sum + order.total);
    final receiptData =
        paidOrders.map((order) => order.toMap()).toList(growable: false);
    final dineInOrders =
        paidOrders.where((o) => o.orderType == OrderType.dineIn).toList();
    final takeOutOrders =
        paidOrders.where((o) => o.orderType == OrderType.takeOut).toList();
    final dineInRevenue =
        dineInOrders.fold(0.0, (sum, order) => sum + order.total);
    final takeOutRevenue =
        takeOutOrders.fold(0.0, (sum, order) => sum + order.total);

    await _reportSvcLoc.recordArchive(DailyReportArchive(
      id: 'archive_${DateFormat('yyyyMMdd_HHmmss').format(now)}',
      reportType: ReportType.daily,
      label: 'Daily Report Reset Snapshot',
      generatedAt: now,
      reportDate: DateTime(now.year, now.month, now.day),
      orderCount: paidOrders.length,
      totalRevenue: totalRev,
      receiptCount: paidOrders.length,
      dineInOrderCount: dineInOrders.length,
      takeOutOrderCount: takeOutOrders.length,
      dineInRevenue: dineInRevenue,
      takeOutRevenue: takeOutRevenue,
      receiptData: receiptData,
    ));
    await _reportSvcLoc.resetDailyReport(resetAt: now);
    await _archiveListKey.currentState?._refreshArchives();

    if (!context.mounted) return;
    final socketProvider = context.read<LocalOrderSocketProvider>();
    if (socketProvider.isConnected) {
      await socketProvider.sendReportReset(now);
      await socketProvider.syncInventoryToPeers();
    }

    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Daily report reset completed.')),
      );
    }
  }

  Future<void> _confirmResetMonthlyReport(
      BuildContext context, List<Order> paidOrders) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: DialogHeader(
          title: 'Reset Monthly Report',
          onClose: () => Navigator.pop(dialogContext, false),
        ),
        content: const Text(
          'Only the monthly report in the Reports section will be reset. Daily Analytics, Total Sales, History receipts, and inventory will not be affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final totalRev = paidOrders.fold(0.0, (sum, order) => sum + order.total);
    final receiptData =
        paidOrders.map((order) => order.toMap()).toList(growable: false);
    final dineInOrders =
        paidOrders.where((o) => o.orderType == OrderType.dineIn).toList();
    final takeOutOrders =
        paidOrders.where((o) => o.orderType == OrderType.takeOut).toList();
    final dineInRevenue =
        dineInOrders.fold(0.0, (sum, order) => sum + order.total);
    final takeOutRevenue =
        takeOutOrders.fold(0.0, (sum, order) => sum + order.total);

    await _reportSvcLoc.recordArchive(DailyReportArchive(
      id: 'archive_monthly_${DateFormat('yyyyMM').format(now)}_${DateFormat('yyyyMMdd_HHmmss').format(now)}',
      reportType: ReportType.monthly,
      label: 'Monthly Report Reset Snapshot',
      generatedAt: now,
      reportDate: DateTime(now.year, now.month),
      orderCount: paidOrders.length,
      totalRevenue: totalRev,
      receiptCount: paidOrders.length,
      dineInOrderCount: dineInOrders.length,
      takeOutOrderCount: takeOutOrders.length,
      dineInRevenue: dineInRevenue,
      takeOutRevenue: takeOutRevenue,
      receiptData: receiptData,
    ));
    await _reportSvcLoc.resetMonthlyReport(resetAt: DateTime(now.year, now.month, 1));
    await _archiveListKey.currentState?._refreshArchives();

    if (!context.mounted) return;
    final socketProvider = context.read<LocalOrderSocketProvider>();
    if (socketProvider.isConnected) {
      await socketProvider.sendMonthlyReportReset(DateTime(now.year, now.month, 1));
    }

    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Monthly report reset completed.')),
      );
    }
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
      {ReportType? reportType}) async {
    final reportSvc = ReportService();
    final now = DateTime.now();
    final reportBusinessDate = await reportSvc.currentReportDate();
    final reportBusinessMonth = _selectedReportType == ReportType.monthly
        ? _viewingMonth
        : await reportSvc.currentReportMonth();
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final baristaName = context.read<AuthProvider>().user?.name ?? 'Unknown';
    final reportLabel = reportType == ReportType.daily
        ? 'Daily'
        : reportType == ReportType.monthly
            ? 'Monthly'
            : 'Total';
    final title = '$reportLabel Sales Report';
    final filteredOrders = reportType == ReportType.daily
        ? paidOrders
            .where((o) => _isSameDate(o.createdAt, reportBusinessDate))
            .toList()
        : reportType == ReportType.monthly
            ? paidOrders
                .where((o) =>
                    o.createdAt.year == reportBusinessMonth.year &&
                    o.createdAt.month == reportBusinessMonth.month)
                .toList()
            : paidOrders;

    if (filteredOrders.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No ${reportLabel.toLowerCase()} paid orders to save.'),
        ),
      );
      return;
    }

    // Request storage permission before opening the picker.
    if (!await _ensureStoragePermission(context)) {
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
        '${_sanitizeFileName(reportLabel)}Report_${_sanitizeFileName(baristaName)}_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
    final outputFile = File('$selectedDirectory/$fileName');

    final totalRev = filteredOrders.fold(0.0, (double sum, Order o) => sum + o.total);
    final receiptList = filteredOrders
        .where((o) =>
            o.status == OrderStatus.paid || o.status == OrderStatus.completed)
        .toList();
    final reportSummary = buildReportSummary(filteredOrders);
    final avgOrder =
        filteredOrders.isEmpty ? 0.0 : totalRev / filteredOrders.length;
    final dineInOrders =
        filteredOrders.where((o) => o.orderType == OrderType.dineIn).toList();
    final takeOutOrders =
        filteredOrders.where((o) => o.orderType == OrderType.takeOut).toList();
    final dineInRevenue =
        dineInOrders.fold(0.0, (double sum, Order o) => sum + o.total);
    final takeOutRevenue =
        takeOutOrders.fold(0.0, (double sum, Order o) => sum + o.total);
    final dineInPct = filteredOrders.isEmpty
        ? 0.0
        : dineInOrders.length / filteredOrders.length * 100;
    final takeOutPct = filteredOrders.isEmpty
        ? 0.0
        : takeOutOrders.length / filteredOrders.length * 100;
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
          pw.Text(
              sanitizePdfText('Barista: $baristaName'),
              style: const pw.TextStyle(fontSize: 14)),
          pw.Text(
              sanitizePdfText('Generated on: $reportDate'),
              style: const pw.TextStyle(fontSize: 14)),
          pw.Text(
              sanitizePdfText(reportType == ReportType.daily
                  ? 'Business date: ${DateFormat('MMMM d, yyyy').format(reportBusinessDate)}'
                  : reportType == ReportType.monthly
                      ? 'Selected month: ${DateFormat('MMMM yyyy').format(reportBusinessMonth)}'
                      : 'Report period: All time'),
              style: const pw.TextStyle(fontSize: 14)),
          pw.Text(
              sanitizePdfText('Report period: ${reportType == ReportType.daily ? DateFormat('MMMM d, yyyy').format(reportBusinessDate) : reportType == ReportType.monthly ? DateFormat('MMMM yyyy').format(reportBusinessMonth) : 'All time'}'),
              style: const pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 16),
          pw.Text('Summary',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Bullet(text: sanitizePdfText('Report type: $reportLabel')),
          pw.Bullet(text: sanitizePdfText('Total sales orders: ${filteredOrders.length}')),
          pw.Bullet(text: sanitizePdfText('Total revenue: ${formatPdfCurrency(totalRev)}')),
          pw.Bullet(text: sanitizePdfText('Average order value: ${formatPdfCurrency(avgOrder)}')),
          pw.Bullet(text: sanitizePdfText('Top item: $topItem')),
          pw.SizedBox(height: 16),
          pw.Text('Order Type Summary',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Bullet(text: sanitizePdfText('Total Dine-In orders: ${dineInOrders.length}')),
          pw.Bullet(text: sanitizePdfText('Total Take-Out orders: ${takeOutOrders.length}')),
          pw.Bullet(text: sanitizePdfText('Dine-In revenue: ${formatPdfCurrency(dineInRevenue)}')),
          pw.Bullet(text: sanitizePdfText('Take-Out revenue: ${formatPdfCurrency(takeOutRevenue)}')),
          pw.Bullet(
              text: sanitizePdfText('Dine-In percentage: ${dineInPct.toStringAsFixed(1)}%')),
          pw.Bullet(
              text: sanitizePdfText('Take-Out percentage: ${takeOutPct.toStringAsFixed(1)}%')),
          pw.SizedBox(height: 16),
          pw.Text('Payment Breakdown',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _buildPaymentTable(filteredOrders),
          pw.SizedBox(height: 16),
          pw.Text('Sales Summary',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Bullet(text: sanitizePdfText('Total orders: ${reportSummary.totalOrders}')),
          pw.Bullet(text: sanitizePdfText('Total drinks sold: ${reportSummary.totalDrinksSold}')),
          pw.Bullet(text: sanitizePdfText('Total sales: ${formatPdfCurrency(reportSummary.totalSales)}')),
          pw.SizedBox(height: 8),
          pw.Text('Payment method totals',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ...reportSummary.paymentTotals.entries.map((entry) => pw.Bullet(
                text: sanitizePdfText('${entry.key}: ${formatPdfCurrency(entry.value)}'),
              )),
          pw.SizedBox(height: 16),
          pw.Text('Cup Usage Summary',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Bullet(text: sanitizePdfText('12oz cups used: ${reportSummary.cups12oz}')),
          pw.Bullet(text: sanitizePdfText('16oz cups used: ${reportSummary.cups16oz}')),
          pw.SizedBox(height: 16),
          pw.Text('Drink Sales Summary',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          ...reportSummary.drinkSales.entries.map((entry) => pw.Bullet(
                text: sanitizePdfText('${entry.key}: ${entry.value}'),
              )),
          pw.SizedBox(height: 16),
          if (reportType == ReportType.monthly) ...[
            pw.Text('Daily Sales Graph',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _buildMonthlyPdfDailySalesChart(
                filteredOrders, reportBusinessMonth),
            pw.SizedBox(height: 16),
          ],
          pw.Text('Top Selling Items',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _buildTopItemsTable(filteredOrders),
          pw.SizedBox(height: 16),
          pw.Text('Receipt Archive',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(sanitizePdfText('Total receipts in this report: ${receiptList.length}'),
              style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 8),
          ...receiptList.map((order) => _buildReceiptEntry(order)),
        ],
      ),
    );

    try {
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(await pdf.save());
      await reportSvc.recordArchive(DailyReportArchive(
        id: outputFile.path,
        reportType: reportType ?? ReportType.daily,
        label: '$title ${DateFormat('yyyy-MM-dd').format(now)}',
        generatedAt: DateTime.now(),
        reportDate: now,
        orderCount: filteredOrders.length,
        totalRevenue: totalRev,
        receiptCount: receiptList.length,
        dineInOrderCount: dineInOrders.length,
        takeOutOrderCount: takeOutOrders.length,
        dineInRevenue: dineInRevenue,
        takeOutRevenue: takeOutRevenue,
        filePath: outputFile.path,
      ));
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

  Future<void> _downloadArchivedReport(
      BuildContext context, DailyReportArchive archive) async {
    if (!await _ensureStoragePermission(context)) {
      return;
    }

    final selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select folder to save PDF',
      lockParentWindow: true,
    );

    if (selectedDirectory == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF save cancelled')),
        );
      }
      return;
    }

    final bytes = await _buildArchivePdfBytes(archive);
    if (bytes == null || bytes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate the archive PDF.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
      return;
    }

    final fileName =
        '${_sanitizeFileName(archive.label)}_${DateFormat('yyyyMMdd_HHmmss').format(archive.generatedAt)}.pdf';
    final outputFile = File('$selectedDirectory/$fileName');
    await outputFile.writeAsBytes(bytes);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved: $fileName')),
      );
    }
  }

  Future<Uint8List?> _buildArchivePdfBytes(DailyReportArchive archive) async {
    final orders = (archive.receiptData ?? [])
        .map((entry) => Order.fromMap(Map<String, dynamic>.from(entry as Map)))
        .toList(growable: false);
    final summary = buildReportSummary(orders);
    final paymentEntries = summary.paymentTotals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final drinkEntries = summary.drinkSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final reportLabel = archive.reportType == ReportType.monthly
        ? 'Monthly'
        : 'Daily';
    final reportDateLabel = archive.reportType == ReportType.monthly
        ? DateFormat('MMMM yyyy').format(archive.reportDate)
        : DateFormat('MMMM d, yyyy').format(archive.reportDate);

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              sanitizePdfText(archive.label),
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            sanitizePdfText('Report type: $reportLabel Report'),
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.Text(
            sanitizePdfText('Report period: $reportDateLabel'),
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.Text(
            sanitizePdfText('Generated on: ${DateFormat('MMM d, yyyy • hh:mm a').format(archive.generatedAt)}'),
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Text('Summary',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Bullet(text: sanitizePdfText('Total orders: ${summary.totalOrders}')),
          pw.Bullet(text: sanitizePdfText('Total drinks sold: ${summary.totalDrinksSold}')),
          pw.Bullet(text: sanitizePdfText('Total sales: ${formatPdfCurrency(summary.totalSales)}')),
          pw.Bullet(text: sanitizePdfText('12oz cups used: ${summary.cups12oz}')),
          pw.Bullet(text: sanitizePdfText('16oz cups used: ${summary.cups16oz}')),
          pw.SizedBox(height: 12),
          pw.Text('Payment Summary',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          ...paymentEntries.map((entry) => pw.Bullet(
                text: sanitizePdfText('${entry.key}: ${formatPdfCurrency(entry.value)}'),
              )),
          pw.SizedBox(height: 12),
          pw.Text('Drink Sales Summary',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          ...drinkEntries.map((entry) => pw.Bullet(
                text: sanitizePdfText('${entry.key}: ${entry.value}'),
              )),
          pw.SizedBox(height: 12),
          pw.Text('Order Details',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          ...orders.map((order) => pw.Paragraph(
                text: sanitizePdfText(
                  'Order #${order.orderNumber.toString().padLeft(3, '0')} • ${DateFormat('MMM d, yyyy • hh:mm a').format(order.createdAt)} • ${formatPdfCurrency(order.total)}',
                ),
              )),
        ],
      ),
    );
    return pdf.save();
  }

  Future<bool> _ensureStoragePermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final managedStatus = await Permission.manageExternalStorage.status;
    final storageStatus = await Permission.storage.status;
    if (managedStatus.isGranted || storageStatus.isGranted) {
      return true;
    }

    var status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Storage permission is permanently denied. Please enable it in settings.',
            ),
            backgroundColor: AppColors.red,
          ),
        );
      }
      await openAppSettings();
      return false;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Storage permission is required to save the PDF.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
    return false;
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
          .map((entry) => [sanitizePdfText(entry.key), formatPdfCurrency(entry.value).replaceFirst('₱', '')])
          .toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellHeight: 20,
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
    );
  }

  pw.Widget _buildReceiptEntry(Order order) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(sanitizePdfText("Order #${order.orderNumber.toString().padLeft(3, '0')}"),
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
              sanitizePdfText("Date/Time: ${DateFormat('MMM d, yyyy • hh:mm a').format(order.createdAt)}"),
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Text(
              sanitizePdfText("Customer: ${order.customerName.isNotEmpty ? order.customerName : 'Walk-in'}"),
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(
              sanitizePdfText('Cashier: ${order.cashierName.isNotEmpty ? order.cashierName : 'Unknown'}'),
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(
              sanitizePdfText('Prepared By: ${order.preparedBy.isNotEmpty ? order.preparedBy : order.cashierName}'),
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(sanitizePdfText('Order Type: ${order.orderTypeLabel}'),
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(sanitizePdfText('Payment Method: ${order.paymentMethodLabel}'),
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(sanitizePdfText('Total: ${formatPdfCurrency(order.total)}'),
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Text(sanitizePdfText('Items:'),
              style:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ...order.items.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(sanitizePdfText('${item.name} x ${item.qty}'),
                    style: const pw.TextStyle(fontSize: 10)),
              )),
        ],
      ),
    );
  }

  pw.Widget _buildMonthlyPdfDailySalesChart(
      List<Order> orders, DateTime month) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final values = <double>[];
    for (var day = 1; day <= daysInMonth; day++) {
      final dayOrders = orders
          .where((order) =>
              order.createdAt.year == month.year &&
              order.createdAt.month == month.month &&
              order.createdAt.day == day &&
              (order.status == OrderStatus.paid ||
                  order.status == OrderStatus.completed))
          .toList();
      values.add(dayOrders.fold(0.0, (sum, order) => sum + order.total));
    }

    final maxValue =
        values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final bars = <pw.Widget>[];
    for (var i = 0; i < values.length; i++) {
      final day = i + 1;
      final height = maxValue == 0 ? 0.0 : (values[i] / maxValue) * 90;
      final showLabel = day == 1 || day == daysInMonth || day % 5 == 0;
      bars.add(
        pw.Column(
          children: [
            pw.SizedBox(height: 90 - height),
            pw.Container(
              width: 7,
              height: height,
              decoration: pw.BoxDecoration(color: PdfColors.amber700),
            ),
            pw.SizedBox(height: 6),
            if (showLabel)
              pw.Text(day.toString(), style: const pw.TextStyle(fontSize: 8))
            else
              pw.SizedBox(height: 8),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            children: [
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: bars,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
              'Revenue values are shown for each day of the selected month.',
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
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

class _ArchivedReportsList extends StatefulWidget {
  final ValueChanged<DailyReportArchive>? onDownload;

  const _ArchivedReportsList({super.key, this.onDownload});

  @override
  State<_ArchivedReportsList> createState() => _ArchivedReportsListState();
}

class _ArchivedReportsListState extends State<_ArchivedReportsList> {
  ReportService? _reportSvc;
  ReportService get _reportSvcLoc => _reportSvc ??= ReportService();
  ReportType? _filterType;
  Future<List<DailyReportArchive>>? _archivesFuture;

  @override
  void initState() {
    super.initState();
    _archivesFuture = _reportSvcLoc.fetchArchives(type: _filterType);
  }

  Future<void> _refreshArchives() async {
    setState(() {
      _archivesFuture = _reportSvcLoc.fetchArchives(type: _filterType);
    });
    await _archivesFuture!;
  }

  Future<void> _confirmDeleteArchive(BuildContext context, DailyReportArchive archive) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: DialogHeader(
          title: 'Delete Archive Report',
          onClose: () => Navigator.pop(dialogContext, false),
        ),
        content: const Text(
          'Are you sure you want to permanently delete this archived report?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _reportSvcLoc.deleteArchive(archive.id);
    await _refreshArchives();

    if (!mounted) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Archive report deleted successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      return const AppText('No archived reports yet.',
          size: 12, color: AppColors.textMuted);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              labelStyle: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
              selected: _filterType == null,
              onSelected: (_) => setState(() => _filterType = null),
            ),
            ChoiceChip(
              label: const Text('Daily'),
              labelStyle: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
              selected: _filterType == ReportType.daily,
              onSelected: (_) => setState(() => _filterType = ReportType.daily),
            ),
            ChoiceChip(
              label: const Text('Monthly'),
              labelStyle: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
              selected: _filterType == ReportType.monthly,
              onSelected: (_) =>
                  setState(() => _filterType = ReportType.monthly),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<DailyReportArchive>>(
          future: _archivesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const AppText('Loading archived reports…',
                  size: 12, color: AppColors.textMuted);
            }
            final archives = snapshot.data ?? const <DailyReportArchive>[];
            if (archives.isEmpty) {
              return const AppText('No archived reports yet.',
                  size: 12, color: AppColors.textMuted);
            }

            return Column(
              children: archives
                  .map((archive) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.bgLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(archive.label,
                                      size: 12, weight: FontWeight.w600),
                                  const SizedBox(height: 4),
                                  AppText('Type: ${archive.reportType.name}',
                                      size: 11, color: AppColors.textMuted),
                                  AppText(
                                      'Report date: ${DateFormat('MMM d, yyyy').format(archive.reportDate)}',
                                      size: 11,
                                      color: AppColors.textMuted),
                                  AppText(
                                      'Orders: ${archive.orderCount} • Revenue: ${formatPHP(archive.totalRevenue)}',
                                      size: 11,
                                      color: AppColors.textMuted),
                                  AppText(
                                      'Dine-In: ${archive.dineInOrderCount} • Take-Out: ${archive.takeOutOrderCount}',
                                      size: 11,
                                      color: AppColors.textMuted),
                                  AppText(
                                      'Dine-In Rev: ${formatPHP(archive.dineInRevenue)} • Take-Out Rev: ${formatPHP(archive.takeOutRevenue)}',
                                      size: 11,
                                      color: AppColors.textMuted),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.onDownload != null)
                                  IconButton(
                                    onPressed: () => widget.onDownload!(archive),
                                    icon: const Icon(Icons.download_outlined,
                                        size: 16, color: AppColors.goldDark),
                                    tooltip: 'Download report PDF',
                                  ),
                                IconButton(
                                  onPressed: () => _confirmDeleteArchive(context, archive),
                                  icon: const Icon(Icons.delete_outline,
                                      size: 16, color: AppColors.red),
                                  tooltip: 'Delete archive report',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = (constraints.maxWidth > 660 ? 180 : 140)
            .clamp(140.0, 220.0)
            .toDouble();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                height: chartHeight,
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
      },
    );
  }
}

class _HourlyBarChart extends StatelessWidget {
  final List<Order> orders;

  const _HourlyBarChart({required this.orders});

  @override
  Widget build(BuildContext context) {
    final hourly = ReportChartUtils.buildHourlyRevenueSeries(orders);
    final hasData = hourly.any((value) => value > 0);

    final maxY = hourly.reduce((a, b) => a > b ? a : b);
    final labels = List.generate(24, (index) {
      final hour = index % 12;
      final suffix = index < 12 ? 'a' : 'p';
      final displayHour = hour == 0 ? 12 : hour;
      return '$displayHour$suffix';
    });

    if (!hasData) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor, width: 0.5),
          ),
          child: const AppText(
            'No sales data available for today.',
            size: 12,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = (constraints.maxWidth > 660 ? 220 : 180)
            .clamp(160.0, 260.0)
            .toDouble();
        return SizedBox(
          height: chartHeight,
          child: BarChart(
            BarChartData(
              maxY: maxY == 0 ? 1000.0 : maxY * 1.2,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY == 0 ? 500.0 : maxY / 4,
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
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textMuted),
                    ),
                    reservedSize: 20,
                  ),
                ),
              ),
              barGroups: List.generate(
                24,
                (i) => BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: hourly[i] == 0 ? 0.0 : hourly[i].toDouble(),
                      color: AppColors.gold,
                      width: 12,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(3)),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY == 0 ? 1000.0 : maxY.toDouble() * 1.2,
                        color: AppColors.bgLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
