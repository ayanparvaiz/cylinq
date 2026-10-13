import 'package:cylinq/core/utils/qr_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips a label URL', () {
    final url = QrPayload.forCylinder('org42', 'GS-00007');
    final code = QrPayload.parse(url)!;
    expect(code.orgId, 'org42');
    expect(code.serial, 'GS-00007');
    expect(code.belongsTo('org42'), isTrue);
    expect(code.belongsTo('other'), isFalse);
  });

  test('accepts a hand-typed serial in any case', () {
    final code = QrPayload.parse(' gs-00007 ')!;
    expect(code.serial, 'GS-00007');
    expect(code.orgId, isNull);
    expect(code.belongsTo('anything'), isTrue);
  });

  test('ignores unrelated QR codes', () {
    expect(QrPayload.parse('upi://pay?pa=shop@upi'), isNull);
    expect(QrPayload.parse('https://example.com/menu'), isNull);
    expect(QrPayload.parse('hello world'), isNull);
    expect(QrPayload.parse(''), isNull);
  });
}
