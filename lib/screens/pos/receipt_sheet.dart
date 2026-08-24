// ignore_for_file: prefer_const_constructors

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class ReceiptSheet extends StatelessWidget {
  final Order order;

  const ReceiptSheet({super.key, required this.order});

  Future<Uint8List> _buildReceiptPdf(Order order) async {
    final pdf = pw.Document();
    final receiptDate = DateFormat('MMM d, yyyy • hh:mm a').format(order.createdAt);
    final items = order.items
        .map((item) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('${item.name} (${item.cupSize}) × ${item.qty}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                if (item.sugarLevel.trim().isNotEmpty)
                  pw.Text('Sugar: ${item.sugarLevel}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                pw.Text('Price: ${formatPHP(item.price)}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                pw.Text('Subtotal: ${formatPHP(item.price * item.qty)}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                pw.SizedBox(height: 4),
              ],
            ))
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.roll80,
        build: (ctx) => [
          pw.Center(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('Dubai Coffee', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Official Receipt', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Order #${order.orderNumber.toString().padLeft(3, '0')}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text(receiptDate, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
          pw.Text('Customer: ${order.customerName.isNotEmpty ? order.customerName : 'Walk-in'}', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Text('Cashier: ${order.cashierName.isNotEmpty ? order.cashierName : 'Unknown'}', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Text('Prepared By: ${order.preparedBy.isNotEmpty ? order.preparedBy : order.cashierName.isNotEmpty ? order.cashierName : 'Unknown'}', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Text('Order Type: ${order.orderTypeLabel}', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 6),
          if (order.orderNotes.trim().isNotEmpty)
            pw.Text('Order Notes: ${order.orderNotes}', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Text('Order Status: ${order.statusLabel}', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Text('Payment: ${order.paymentMethodLabel}', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.SizedBox(height: 6),
          ...items,
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.SizedBox(height: 8),
          if (order.status == OrderStatus.voided && order.voidReason != null && order.voidReason!.isNotEmpty)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('VOIDED', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                pw.Text('Reason: ${order.voidReason}', style: pw.TextStyle(fontSize: 10, color: PdfColors.red)),
                pw.SizedBox(height: 8),
              ],
            ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Subtotal', style: pw.TextStyle(fontSize: 11)),
              pw.Text(formatPHP(order.subtotal), style: pw.TextStyle(fontSize: 11)),
            ],
          ),
          if (order.discount > 0)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(order.discountLabel, style: pw.TextStyle(fontSize: 11)),
                pw.Text('-${formatPHP(order.discount)}', style: pw.TextStyle(fontSize: 11)),
              ],
            ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(formatPHP(order.total), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Tendered', style: pw.TextStyle(fontSize: 11)),
              pw.Text(formatPHP(order.tendered), style: pw.TextStyle(fontSize: 11)),
            ],
          ),
          if (order.change > 0)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Change', style: pw.TextStyle(fontSize: 11)),
                pw.Text(formatPHP(order.change), style: pw.TextStyle(fontSize: 11)),
              ],
            ),
          pw.SizedBox(height: 14),
          pw.Text('Thank you for visiting Dubai Coffee!', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ],
      ),
    );
    return pdf.save();
  }

  Future<void> _printReceipt(BuildContext context, Order order) async {
    final bytes = await _buildReceiptPdf(order);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<void> _shareReceipt(BuildContext context, Order order) async {
    final bytes = await _buildReceiptPdf(order);
    await Printing.sharePdf(bytes: bytes, filename: 'receipt_${order.orderNumber.toString().padLeft(3, '0')}.pdf');
  }

  Future<void> _exportReceipt(BuildContext context, Order order) async {
    final filename = 'Receipt_${order.orderNumber.toString().padLeft(3, '0')}.pdf';
    final bytes = await _buildReceiptPdf(order);
    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}${Platform.pathSeparator}$filename';
    final file = File(savePath);
    await file.writeAsBytes(bytes);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Receipt saved: ${file.path}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dubai Coffee',
                        style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.goldDark)),
                    const AppText('Official Receipt',
                        size: 11, color: AppColors.textMuted),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                tooltip: 'Close',
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Order meta
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText(
                  'Order #${order.orderNumber.toString().padLeft(3, '0')}',
                  size: 11,
                  color: AppColors.textMuted),
              AppText(
                  DateFormat('MMM d, yyyy • hh:mm a')
                      .format(order.createdAt),
                  size: 11,
                  color: AppColors.textMuted),
            ],
          ),

          if (order.status == OrderStatus.voided && order.voidReason != null && order.voidReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8EBEB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText('Void reason', size: 11, weight: FontWeight.w600),
                    const SizedBox(height: 4),
                    AppText(order.voidReason!, size: 12, color: AppColors.red),
                  ],
                ),
              ),
            ),

          // Customer & Staff Info
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    AppText(order.customerName.isNotEmpty ? order.customerName : 'Walk-in',
                        size: 13, weight: FontWeight.w600),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const AppText('Cashier:', size: 11, color: AppColors.textMuted, weight: FontWeight.w500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppText(order.cashierName.isNotEmpty ? order.cashierName : 'Unknown',
                          size: 11, weight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const AppText('Prepared By:', size: 11, color: AppColors.textMuted, weight: FontWeight.w500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppText(order.preparedBy.isNotEmpty ? order.preparedBy : order.cashierName,
                          size: 11, weight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const AppText('Order Type:', size: 11, color: AppColors.textMuted, weight: FontWeight.w500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppText(order.orderTypeLabel,
                          size: 11, weight: FontWeight.w600),
                    ),
                  ],
                ),
                if (order.orderNotes.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText('Notes:', size: 11, color: AppColors.textMuted, weight: FontWeight.w500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppText(order.orderNotes,
                            size: 11, weight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderColor),

          // Items
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: order.items.length,
              itemBuilder: (_, i) {
                final item = order.items[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText('${item.name} (${item.cupSize}) × ${item.qty}', size: 13, weight: FontWeight.w800, color: AppColors.espresso),
                      if (item.sugarLevel.trim().isNotEmpty)
                        AppText('Sugar: ${item.sugarLevel}', size: 11, color: AppColors.textMuted),
                      AppText('Price: ${formatPHP(item.price)}', size: 11, color: AppColors.textMuted),
                      AppText('Subtotal: ${formatPHP(item.price * item.qty)}', size: 11, color: AppColors.textMuted),
                    ],
                  ),
                );
              },
            ),
          ),

          const Divider(height: 12, color: AppColors.borderColor),

          DividerRow(
              left: 'Subtotal',
              right: formatPHP(order.subtotal)),
          if (order.discount > 0)
            DividerRow(
                left: order.discountLabel,
                right: '−${formatPHP(order.discount)}',
                isDiscount: true),
          DividerRow(
              left: 'Order Type', right: order.orderTypeLabel),
          DividerRow(
              left: 'Sugar', right: order.sugarLevel),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: DashedLine(),
          ),

          DividerRow(
              left: 'Total',
              right: formatPHP(order.total),
              isTotal: true),
          DividerRow(
              left: 'Payment (${order.paymentMethodLabel})',
              right: formatPHP(order.tendered)),

          if (order.change > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3DE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppText('Change: ',
                      size: 13, color: AppColors.green),
                  AppText(formatPHP(order.change),
                      size: 18,
                      weight: FontWeight.w700,
                      color: AppColors.green),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          const AppText('Thank you for visiting Dubai Coffee!',
              size: 11, color: AppColors.textMuted, align: TextAlign.center),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('Print'),
                  onPressed: () => _printReceipt(context, order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.espresso,
                    foregroundColor: AppColors.goldLight,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  onPressed: () => _shareReceipt(context, order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brown,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export PDF'),
              onPressed: () => _exportReceipt(context, order),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.goldDark,
                foregroundColor: AppColors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('New Order'),
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.espresso,
                foregroundColor: AppColors.goldLight,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
      ),
    );
  }
}

class DashedLine extends StatelessWidget {
  const DashedLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        30,
        (_) => Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: AppColors.borderColor,
          ),
        ),
      ),
    );
  }
}
