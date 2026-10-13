import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/models/org.dart';
import '../pdf/label_pdf.dart';

/// Print dialog, or download/share the PDF, for a set of labels.
class LabelPreviewScreen extends StatelessWidget {
  const LabelPreviewScreen({super.key, required this.org, required this.items, required this.layout});

  final Org org;
  final List<LabelItem> items;
  final LabelLayout layout;

  static Future<void> open(BuildContext context, {required Org org, required List<LabelItem> items, required LabelLayout layout}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LabelPreviewScreen(org: org, items: items, layout: layout)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = items.first.serial, last = items.last.serial;
    final fileName = 'cylinq-labels-$first${items.length > 1 ? '-to-$last' : ''}.pdf';
    return Scaffold(
      appBar: AppBar(
        title: Text(items.length == 1 ? 'Label $first' : '${items.length} labels · $first → $last'),
      ),
      body: PdfPreview(
        build: (_) => LabelPdf.build(org: org, items: items, layout: layout),
        pdfFileName: fileName,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        loadingWidget: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
