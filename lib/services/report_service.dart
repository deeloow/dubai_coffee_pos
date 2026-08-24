import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../models/models.dart';
import 'inventory_service.dart';
import 'order_service.dart';

class ReportService {
  Future<Box?> _ensureHistoryBox() async {
    try {
      if (Hive.isBoxOpen('reports_history')) {
        return Hive.box('reports_history');
      }
      return await Hive.openBox('reports_history');
    } catch (error) {
      debugPrint('ReportService._ensureHistoryBox fallback due to $error');
      return null;
    }
  }

  Future<Box> _ensureSettingsBox() async {
    if (Hive.isBoxOpen('settings')) {
      return Hive.box('settings');
    }
    return Hive.openBox('settings');
  }

  static final StreamController<DateTime> _reportDateController = StreamController<DateTime>.broadcast();
  static final StreamController<DateTime> _reportMonthController = StreamController<DateTime>.broadcast();

  static const String _currentReportDateKey = 'reporting_business_date';
  static const String _currentReportMonthKey = 'reporting_business_month';
  static const String _lastResetKey = 'last_report_reset';
  static const String _lastMonthlyResetKey = 'last_monthly_report_reset';

  Future<DateTime> currentReportDate() async {
    try {
      final settings = await _ensureSettingsBox();
      final raw = settings.get(_currentReportDateKey) as String?;
      if (raw != null) {
        final parsed = DateTime.tryParse(raw) ?? DateTime.now();
        debugPrint('ReportService: currentReportDate returning parsed=$parsed');
        return parsed;
      }
      final now = DateTime.now();
      final reportDate = DateTime(now.year, now.month, now.day);
      await _safePut(_currentReportDateKey, reportDate.toIso8601String());
      return reportDate;
    } catch (error) {
      debugPrint('ReportService: currentReportDate fallback due to $error');
      return DateTime.now();
    }
  }

  Future<DateTime> currentReportMonth() async {
    try {
      final settings = await _ensureSettingsBox();
      final raw = settings.get(_currentReportMonthKey) as String?;
      debugPrint('ReportService: currentReportMonth raw=$raw');
      final now = DateTime.now();

      if (raw == null) {
        final reportMonth = DateTime(now.year, now.month);
        debugPrint('ReportService: currentReportMonth initializing month=$reportMonth');
        final settings = await _ensureSettingsBox();
        debugPrint('ReportService: currentReportMonth settings.isOpen=${settings.isOpen}');
        await _safePut(_currentReportMonthKey, reportMonth.toIso8601String());
        debugPrint('ReportService: currentReportMonth after put');
        return reportMonth;
      }

      final stored = DateTime.tryParse(raw) ?? DateTime(now.year, now.month);
      debugPrint('ReportService: currentReportMonth stored=$stored now=$now');

      // If the stored month is ahead of the current system month, preserve it.
      if (stored.isAfter(DateTime(now.year, now.month))) {
        debugPrint('ReportService: currentReportMonth stored in future, returning stored=$stored');
        return stored;
      }

      // If the system moved to a newer month while the app wasn't running,
      // perform automatic archival for each missing month and start a fresh
      // reporting period for the current month.
      if (stored.year != now.year || stored.month != now.month) {
        debugPrint('ReportService: currentReportMonth transitioning from=$stored to=$now');
        await _autoTransitionMonths(from: stored, to: DateTime(now.year, now.month));
        final reportMonth = DateTime(now.year, now.month);
        final settings = await _ensureSettingsBox();
        await settings.put(_currentReportMonthKey, reportMonth.toIso8601String());
        _reportMonthController.add(reportMonth);
        debugPrint('ReportService: currentReportMonth transition done reportMonth=$reportMonth');
        return reportMonth;
      }

      debugPrint('ReportService: currentReportMonth returning stored=$stored');
      return stored;
    } catch (error) {
      debugPrint('ReportService: currentReportMonth fallback due to $error');
      return DateTime.now();
    }
  }

  Future<void> _autoTransitionMonths({required DateTime from, required DateTime to}) async {
    // Archive each month between `from` (inclusive) and `to` (exclusive).
    var cursor = DateTime(from.year, from.month);
    final target = DateTime(to.year, to.month);
    final orderSvc = OrderService();

    while (cursor.isBefore(target)) {
      // Collect paid/completed orders for this month (not archived yet)
      final allOrders = await orderSvc.fetchOrders(includeArchived: false);
      final monthOrders = allOrders.where((o) =>
          o.createdAt.year == cursor.year && o.createdAt.month == cursor.month &&
          (o.status == OrderStatus.paid || o.status == OrderStatus.completed)).toList();

      final now = DateTime.now();
      final totalRev = monthOrders.fold(0.0, (sum, o) => sum + o.total);
      final dineInOrders = monthOrders.where((o) => o.orderType == OrderType.dineIn).toList();
      final takeOutOrders = monthOrders.where((o) => o.orderType == OrderType.takeOut).toList();

      final receiptData = monthOrders.map((o) => o.toMap()).toList(growable: false);

      // Record an archive for the month (store metadata only; avoid PDF generation during auto-transition)
      final archive = DailyReportArchive(
        id: 'archive_monthly_auto_${cursor.year}${cursor.month.toString().padLeft(2, '0')}_${DateTime.now().millisecondsSinceEpoch}',
        reportType: ReportType.monthly,
        label: 'Monthly Archive ${DateFormat('MMMM yyyy').format(cursor)}',
        generatedAt: now,
        reportDate: DateTime(cursor.year, cursor.month),
        orderCount: monthOrders.length,
        totalRevenue: totalRev,
        receiptCount: monthOrders.length,
        dineInOrderCount: dineInOrders.length,
        takeOutOrderCount: takeOutOrders.length,
        dineInRevenue: dineInOrders.fold(0.0, (s, o) => s + o.total),
        takeOutRevenue: takeOutOrders.fold(0.0, (s, o) => s + o.total),
        receiptData: receiptData,
      );
      final history = await _ensureHistoryBox();
      if (history == null) {
        return;
      }
      await history.put(archive.id, archive.toMap());

      // Advance cursor to next month
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    // After archiving missing months, perform the monthly reset to clear
    // monthly settings and mark the last monthly reset timestamp.
    await resetMonthlyPeriod(resetAt: DateTime(to.year, to.month, 1));
  }

  Stream<DateTime> reportDateStream() async* {
    yield await currentReportDate();
    yield* _reportDateController.stream;
  }

  Stream<DateTime> reportMonthStream() async* {
    yield await currentReportMonth();
    yield* _reportMonthController.stream;
  }

  Future<void> recordArchive(DailyReportArchive archive) async {
    final history = await _ensureHistoryBox();
    if (history == null) {
      return;
    }
    // Persist archive metadata first
    await history.put(archive.id, archive.toMap());

    // Attempt to generate a PDF snapshot for the archive and update record
    try {
      final pdfPath = await _generatePdfForArchive(archive);
      if (pdfPath != null) {
        final updated = Map<String, dynamic>.from(archive.toMap())..['filePath'] = pdfPath;
        await history.put(archive.id, updated);
      }
    } catch (_) {
      // Non-fatal: PDF generation failure should not block archive saving
    }
  }

  Future<void> resetDailyPeriod({required DateTime resetAt}) async {
    debugPrint('ReportService.resetDailyPeriod: start resetAt=$resetAt');
    // Daily reset is intentionally isolated from the monthly reset path.
    // We archive the completed day, clear only daily report state, and reset
    // the cup inventory to the standard day-start values without touching the
    // monthly report counters or monthly business month.
    final nextDayStart = DateTime(resetAt.year, resetAt.month, resetAt.day + 1);
    debugPrint('ReportService.resetDailyPeriod: archiving before $nextDayStart');
    await OrderService().archiveOrdersBefore(nextDayStart);
    debugPrint('ReportService.resetDailyPeriod: archive done');
    await _clearDailySettings();
    debugPrint('ReportService.resetDailyPeriod: cleared daily settings');

    final inventoryService = InventoryService();
    debugPrint('ReportService.resetDailyPeriod: seeding inventory if empty');
    await inventoryService.seedInventoryIfEmpty();
    debugPrint('ReportService.resetDailyPeriod: seeded inventory');

    final inventoryItems = await inventoryService.fetchAllInventory();
    debugPrint('ReportService.resetDailyPeriod: fetched ${inventoryItems.length} inventory items');
    final resetInventory = inventoryItems.map((item) {
      final normalizedName = item.name.trim().toLowerCase();
      if (normalizedName == 'cups 12oz') {
        return item.copyWith(quantity: 100.0, servedQuantity: 0.0);
      }
      if (normalizedName == 'cups 16oz') {
        return item.copyWith(quantity: 100.0, servedQuantity: 0.0);
      }
      return item;
    }).toList();

    for (final item in resetInventory) {
      debugPrint('ReportService.resetDailyPeriod: resetting inventory item ${item.name}');
      await inventoryService.updateItem(item);
    }

    // Initialize daily stats to zeros so consumers don't encounter nulls
    await _safePut('daily_total_revenue', 0.0);
    await _safePut('daily_order_count', 0);
    await _safePut('daily_hourly_sales', <String, double>{});
    await _safePut('daily_analytics', <String, dynamic>{});
    await _safePut('daily_dashboard_stats', <String, dynamic>{});
    debugPrint('ReportService.resetDailyPeriod: settings initialized');

    await markReset(resetAt);
    debugPrint('ReportService.resetDailyPeriod: markReset completed');
  }

  Future<void> resetDailyReport({required DateTime resetAt}) async {
    await resetDailyPeriod(resetAt: resetAt);
  }

  Future<void> resetMonthlyPeriod({required DateTime resetAt}) async {
    // Monthly reset is intentionally separate from the daily reset path.
    // It only clears the monthly report state and advances the monthly business
    // month without touching the current daily report or inventory.
    await _clearMonthlySettings();
    await markMonthlyReset(resetAt);
  }

  Future<void> resetMonthlyReport({required DateTime resetAt}) async {
    await resetMonthlyPeriod(resetAt: resetAt);
  }

  Future<void> applyRemoteReset(DateTime resetAt) async {
    await resetDailyPeriod(resetAt: resetAt);
  }

  Future<void> applyRemoteMonthlyReset(DateTime resetAt) async {
    await resetMonthlyPeriod(resetAt: resetAt);
  }

  Future<void> applyRemoteDailyState(DateTime resetAt) async {
    final currentDate = await currentReportDate();
    final remoteDate = DateTime(resetAt.year, resetAt.month, resetAt.day);
    if (remoteDate.isAtSameMomentAs(currentDate)) {
      return;
    }

    // Daily reports are now reset only through the explicit admin action.
    // Ignore incoming date-based state syncs so peers do not silently clear
    // the current day's sales and analytics.
    debugPrint(
      'ReportService.applyRemoteDailyState: ignoring remote date sync from $remoteDate while current report date is $currentDate',
    );
  }

  Future<void> applyRemoteMonthlyState(DateTime resetAt) async {
    final currentMonth = await currentReportMonth();
    final remoteMonth = DateTime(resetAt.year, resetAt.month);
    if (remoteMonth.isAtSameMomentAs(currentMonth)) {
      return;
    }
    await markMonthlyReset(resetAt);
  }

  Future<void> _clearDailySettings() async {
    await _safeDelete('daily_total_revenue');
    await _safeDelete('daily_order_count');
    await _safeDelete('daily_hourly_sales');
    await _safeDelete('daily_analytics');
    await _safeDelete('daily_dashboard_stats');
  }

  Future<void> _clearMonthlySettings() async {
    await _safeDelete('monthly_total_revenue');
    await _safeDelete('monthly_order_count');
    await _safeDelete('monthly_hourly_sales');
    await _safeDelete('monthly_analytics');
    await _safeDelete('monthly_dashboard_stats');
  }

  Future<List<DailyReportArchive>> fetchArchives({ReportType? type}) async {
    try {
      final history = await _ensureHistoryBox();
      if (history == null) {
        return [];
      }
      return history.values
          .map((item) => DailyReportArchive.fromMap(Map<String, dynamic>.from(item as Map)))
          .where((archive) => type == null || archive.reportType == type)
          .toList()
        ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    } catch (error) {
      debugPrint('ReportService.fetchArchives fallback due to $error');
      return [];
    }
  }

  Future<void> deleteArchive(String archiveId) async {
    try {
      final history = await _ensureHistoryBox();
      if (history == null) {
        return;
      }
      final archive = await history.get(archiveId);
      if (archive == null) {
        return;
      }

      final archiveMap = Map<String, dynamic>.from(archive as Map);
      final filePath = archiveMap['filePath']?.toString();
      if (filePath != null && filePath.isNotEmpty) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('ReportService.deleteArchive: failed to delete file $filePath: $e');
        }
      }

      await history.delete(archiveId);
    } catch (error) {
      debugPrint('ReportService.deleteArchive fallback due to $error');
    }
  }

  Future<void> markReset(DateTime resetAt) async {
    await _safePut(_lastResetKey, resetAt.toIso8601String());
    final reportDate = DateTime(resetAt.year, resetAt.month, resetAt.day);
    await _safePut(_currentReportDateKey, reportDate.toIso8601String());
    _reportDateController.add(reportDate);
  }

  Future<void> markMonthlyReset(DateTime resetAt) async {
    await _safePut(_lastMonthlyResetKey, resetAt.toIso8601String());
    final reportMonth = DateTime(resetAt.year, resetAt.month);
    await _safePut(_currentReportMonthKey, reportMonth.toIso8601String());
    _reportMonthController.add(reportMonth);
  }

  // Helpers that guard Hive operations with a short timeout so widget tests
  // or environments where Hive isn't fully initialized don't hang the test
  // runner. Failures are logged but non-fatal.
  Future<void> _safePut(String key, dynamic value) async {
    try {
      final settings = await _ensureSettingsBox();
      final future = settings.put(key, value);
      if (Platform.environment['FLUTTER_TEST'] == 'true') {
        await future;
      } else {
        await future.timeout(const Duration(seconds: 1));
      }
    } catch (e) {
      debugPrint('ReportService._safePut failed for $key: $e');
    }
  }

  Future<void> _safeDelete(String key) async {
    try {
      final settings = await _ensureSettingsBox();
      final future = settings.delete(key);
      if (Platform.environment['FLUTTER_TEST'] == 'true') {
        await future;
      } else {
        await future.timeout(const Duration(seconds: 1));
      }
    } catch (e) {
      debugPrint('ReportService._safeDelete failed for $key: $e');
    }
  }

  Future<String?> _generatePdfForArchive(DailyReportArchive archive) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) {
            return [
              pw.Header(level: 0, child: pw.Text(archive.label)),
              pw.Paragraph(text: 'Report date: ${archive.reportDate.toIso8601String()}'),
              pw.Paragraph(text: 'Generated at: ${archive.generatedAt.toIso8601String()}'),
              pw.Paragraph(text: 'Orders: ${archive.orderCount}'),
              pw.Paragraph(text: 'Total revenue: ${archive.totalRevenue.toStringAsFixed(2)}'),
              pw.SizedBox(height: 12),
              if (archive.receiptData != null && archive.receiptData!.isNotEmpty)
                pw.Column(
                  children: archive.receiptData!.map((r) {
                    final orderNumber = r['orderNumber']?.toString() ?? '';
                    final total = r['total']?.toString() ?? '';
                    final created = r['createdAt']?.toString() ?? '';
                    return pw.Paragraph(text: 'Order #$orderNumber — ₱$total — $created');
                  }).toList(),
                ),
            ];
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final safeTs = archive.generatedAt.toIso8601String().replaceAll(':', '-');
      final file = File('${dir.path}/${archive.id}_report_$safeTs.pdf');
      await file.writeAsBytes(await pdf.save());
      return file.path;
    } catch (e) {
      return null;
    }
  }

  Future<String?> lastResetAt() async {
    final settings = await _ensureSettingsBox();
    return settings.get(_lastResetKey) as String?;
  }

  Future<String?> lastMonthlyResetAt() async {
    final settings = await _ensureSettingsBox();
    return settings.get(_lastMonthlyResetKey) as String?;
  }
}
