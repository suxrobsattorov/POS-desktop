import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptService {
  /// Chek PDF yaratish — to'liq format bilan
  Future<pw.Document> buildReceiptPdf({
    required String shopName,
    String shopAddress = '',
    String shopPhone = '',
    String receiptHeader = '',
    String receiptFooter = '',
    required String receiptNo,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    required double total,
    required double paid,
    required double change,
    required String paymentMethod,
    String currency = 'UZS',
    String? cashierName,
  }) async {
    final pdf = pw.Document();
    final ttf = await PdfGoogleFonts.notoSansRegular();
    final ttfBold = await PdfGoogleFonts.notoSansBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 5 * PdfPageFormat.mm,
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Separator yuqori ──
            pw.Center(
              child: pw.Text(
                '================================',
                style: pw.TextStyle(font: ttf, fontSize: 8),
              ),
            ),
            pw.SizedBox(height: 2),

            // ── Do'kon nomi ──
            pw.Center(
              child: pw.Text(
                shopName,
                style: pw.TextStyle(font: ttfBold, fontSize: 12),
              ),
            ),

            // ── Manzil ──
            if (shopAddress.isNotEmpty) ...[
              pw.SizedBox(height: 1),
              pw.Center(
                child: pw.Text(
                  shopAddress,
                  style: pw.TextStyle(font: ttf, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],

            // ── Telefon ──
            if (shopPhone.isNotEmpty) ...[
              pw.SizedBox(height: 1),
              pw.Center(
                child: pw.Text(
                  'Tel: $shopPhone',
                  style: pw.TextStyle(font: ttf, fontSize: 8),
                ),
              ),
            ],

            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text(
                '================================',
                style: pw.TextStyle(font: ttf, fontSize: 8),
              ),
            ),

            // ── Header matni ──
            if (receiptHeader.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  receiptHeader,
                  style: pw.TextStyle(font: ttf, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  '--------------------------------',
                  style: pw.TextStyle(font: ttf, fontSize: 8),
                ),
              ),
            ],

            pw.SizedBox(height: 4),

            // ── Chek ma'lumotlari ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Chek:', style: pw.TextStyle(font: ttf, fontSize: 8)),
                pw.Text('#$receiptNo',
                    style: pw.TextStyle(font: ttfBold, fontSize: 8)),
              ],
            ),
            if (cashierName != null && cashierName.isNotEmpty) ...[
              pw.SizedBox(height: 1),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Kassir:', style: pw.TextStyle(font: ttf, fontSize: 8)),
                  pw.Text(cashierName,
                      style: pw.TextStyle(font: ttf, fontSize: 8)),
                ],
              ),
            ],
            pw.SizedBox(height: 1),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Sana:', style: pw.TextStyle(font: ttf, fontSize: 8)),
                pw.Text(_formatDate(date),
                    style: pw.TextStyle(font: ttf, fontSize: 8)),
              ],
            ),

            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                '--------------------------------',
                style: pw.TextStyle(font: ttf, fontSize: 8),
              ),
            ),
            pw.SizedBox(height: 4),

            // ── Mahsulotlar ──
            ...items.map((item) {
              final name = item['name']?.toString() ?? '';
              final price = (item['price'] as num?)?.toDouble() ?? 0;
              final qty = item['qty'] ?? 1;
              final itemTotal = (item['total'] as num?)?.toDouble() ?? 0;
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(name, style: pw.TextStyle(font: ttf, fontSize: 9)),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '  ${_fmtNum(price)} x $qty',
                          style: pw.TextStyle(font: ttf, fontSize: 8),
                        ),
                        pw.Text(
                          '${_fmtNum(itemTotal)} $currency',
                          style: pw.TextStyle(font: ttfBold, fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                '--------------------------------',
                style: pw.TextStyle(font: ttf, fontSize: 8),
              ),
            ),
            pw.SizedBox(height: 4),

            // ── Jami ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Jami:',
                    style: pw.TextStyle(font: ttfBold, fontSize: 10)),
                pw.Text('${_fmtNum(total)} $currency',
                    style: pw.TextStyle(font: ttfBold, fontSize: 10)),
              ],
            ),

            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                '================================',
                style: pw.TextStyle(font: ttf, fontSize: 8),
              ),
            ),
            pw.SizedBox(height: 3),

            // ── To'lov ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('$paymentMethod:',
                    style: pw.TextStyle(font: ttf, fontSize: 9)),
                pw.Text('${_fmtNum(paid)} $currency',
                    style: pw.TextStyle(font: ttf, fontSize: 9)),
              ],
            ),

            if (change > 0) ...[
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Qaytim:',
                      style: pw.TextStyle(font: ttf, fontSize: 9)),
                  pw.Text('${_fmtNum(change)} $currency',
                      style: pw.TextStyle(font: ttf, fontSize: 9)),
                ],
              ),
            ],

            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                '================================',
                style: pw.TextStyle(font: ttf, fontSize: 8),
              ),
            ),
            pw.SizedBox(height: 4),

            // ── Footer matni ──
            pw.Center(
              child: pw.Text(
                receiptFooter.isNotEmpty
                    ? receiptFooter
                    : 'Xarid uchun rahmat!',
                style: pw.TextStyle(font: ttf, fontSize: 9),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text(
                '================================',
                style: pw.TextStyle(font: ttf, fontSize: 8),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf;
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _fmtNum(double val) {
    return val
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
  }

  Future<bool> printReceipt(pw.Document pdf) async {
    try {
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Alias — HistoryScreen dan chaqiriladi
  Future<bool> printPdf(pw.Document pdf) => printReceipt(pdf);

  Future<String?> savePdfToFile(pw.Document pdf, String receiptNo) async {
    try {
      final bytes = await pdf.save();
      final fileName = 'chek_$receiptNo.pdf';

      String? path;
      try {
        path = await FilePicker.platform.saveFile(
          dialogTitle: 'Chekni saqlash joyini tanlang',
          fileName: fileName,
        );
      } catch (_) {}

      if (path != null) {
        if (!path.endsWith('.pdf')) path = '$path.pdf';
        await File(path).writeAsBytes(bytes);
        return path;
      }

      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final fallbackPath = '${dir.path}/$fileName';
      await File(fallbackPath).writeAsBytes(bytes);
      return fallbackPath;
    } catch (_) {
      return null;
    }
  }

  /// Show receipt action dialog
  static Future<ReceiptAction?> showReceiptDialog(
      BuildContext context, bool printerEnabled, bool pdfEnabled) async {
    return showDialog<ReceiptAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Chek', style: TextStyle(color: Colors.white)),
        content: const Text('Chek bilan nima qilmoqchisiz?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          if (printerEnabled)
            TextButton.icon(
              icon: const Icon(Icons.print, color: Colors.blue),
              label: const Text('Chiqarish',
                  style: TextStyle(color: Colors.blue)),
              onPressed: () => Navigator.pop(ctx, ReceiptAction.print),
            ),
          if (pdfEnabled)
            TextButton.icon(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.orange),
              label: const Text('PDF saqlash',
                  style: TextStyle(color: Colors.orange)),
              onPressed: () => Navigator.pop(ctx, ReceiptAction.savePdf),
            ),
          TextButton(
            child: const Text('Keyinchalik',
                style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx, ReceiptAction.skip),
          ),
        ],
      ),
    );
  }
}

enum ReceiptAction { print, savePdf, skip }
