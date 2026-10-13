import 'package:cylinq/core/models/org.dart';
import 'package:cylinq/features/labels/pdf/label_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const org = Org(
    id: 'org1',
    name: 'Shanti Gas Agency',
    ownerUid: 'u1',
    labelPrefix: 'SGA',
    nextSerial: 30,
    phone: '98300 00000',
  );
  final items = [
    for (var i = 1; i <= 25; i++) LabelItem(serial: org.serialFor(i), typeName: '14.2 kg Domestic'),
  ];

  for (final layout in LabelLayout.values) {
    test('builds a ${layout.name} PDF without network fonts', () async {
      final bytes = await LabelPdf.build(org: org, items: items, layout: layout);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(2000));
    });
  }

  test('serials are zero padded with the prefix', () {
    expect(org.serialFor(7), 'SGA-00007');
    expect(org.serialFor(123456), 'SGA-123456');
  });
}
