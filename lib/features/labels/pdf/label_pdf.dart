import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/models/org.dart';
import '../../../core/utils/qr_payload.dart';

class LabelItem {
  const LabelItem({required this.serial, required this.typeName});

  final String serial;
  final String typeName;
}

/// Paper the labels are printed on.
enum LabelLayout {
  /// The common "24 per sheet" A4 sticker paper: 3 × 8 labels of 70 × 37 mm.
  a4Sheet('A4 sticker sheet (24 per page)'),

  /// One 50 × 30 mm label per page, for thermal label printers.
  thermal('Thermal printer (50 × 30 mm)');

  const LabelLayout(this.label);
  final String label;
}

abstract final class LabelPdf {
  static Future<Uint8List> build({
    required Org org,
    required List<LabelItem> items,
    required LabelLayout layout,
  }) async {
    final theme = await _theme();
    final doc = pw.Document(title: '${org.name} cylinder labels', author: 'CylinQ', theme: theme);

    switch (layout) {
      case LabelLayout.a4Sheet:
        const cols = 3, rows = 8;
        const w = 70 * PdfPageFormat.mm, h = 37 * PdfPageFormat.mm;
        for (var start = 0; start < items.length; start += cols * rows) {
          final page = items.skip(start).take(cols * rows).toList();
          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4.copyWith(
                marginLeft: 0,
                marginRight: 0,
                marginTop: 0.5 * PdfPageFormat.mm,
                marginBottom: 0,
              ),
              build: (_) => pw.Column(
                children: [
                  for (var r = 0; r < rows; r++)
                    pw.Row(
                      children: [
                        for (var c = 0; c < cols; c++)
                          pw.SizedBox(
                            width: w,
                            height: h,
                            child: r * cols + c < page.length
                                ? _label(org, page[r * cols + c], qrSize: 27 * PdfPageFormat.mm)
                                : null,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          );
        }
      case LabelLayout.thermal:
        final format = const PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm);
        for (final item in items) {
          doc.addPage(
            pw.Page(
              pageFormat: format,
              build: (_) => _label(org, item, qrSize: 24 * PdfPageFormat.mm, compact: true),
            ),
          );
        }
    }
    return doc.save();
  }

  static pw.Widget _label(Org org, LabelItem item, {required double qrSize, bool compact = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(compact ? 1.5 * PdfPageFormat.mm : 3 * PdfPageFormat.mm),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium),
            data: QrPayload.forCylinder(org.id, item.serial),
            width: qrSize,
            height: qrSize,
            drawText: false,
          ),
          pw.SizedBox(width: 2 * PdfPageFormat.mm),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  org.name.toUpperCase(),
                  maxLines: 2,
                  style: pw.TextStyle(fontSize: compact ? 5.5 : 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
                pw.FittedBox(
                  child: pw.Text(item.serial, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 1 * PdfPageFormat.mm),
                pw.Text(item.typeName, maxLines: 1, style: pw.TextStyle(fontSize: compact ? 6 : 7)),
                if (org.phone.isNotEmpty && !compact) ...[
                  pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
                  pw.Text('If found, call ${org.phone}', maxLines: 1, style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Plus Jakarta Sans to match the app; built-in Helvetica when offline.
  static Future<pw.ThemeData> _theme() async {
    try {
      return pw.ThemeData.withFont(
        base: await PdfGoogleFonts.plusJakartaSansRegular(),
        bold: await PdfGoogleFonts.plusJakartaSansBold(),
      );
    } catch (_) {
      return pw.ThemeData.base();
    }
  }
}
