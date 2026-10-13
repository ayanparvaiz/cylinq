import 'package:cylinq/core/models/cylinder.dart';
import 'package:cylinq/core/models/cylinder_status.dart';
import 'package:cylinq/features/moves/move_rules.dart';
import 'package:flutter_test/flutter_test.dart';

Cylinder cyl(CylinderStatus status, {bool filled = true, String? holderName}) => Cylinder(
  serial: 'GS-00001',
  typeId: 't',
  typeName: '14.2 kg',
  status: status,
  filled: filled,
  holderName: holderName,
);

void main() {
  test('the happy path raises no warnings', () {
    expect(checkMove(ScanMode.fill, cyl(CylinderStatus.godown, filled: false)).warning, isNull);
    expect(checkMove(ScanMode.load, cyl(CylinderStatus.godown)).warning, isNull);
    expect(checkMove(ScanMode.give, cyl(CylinderStatus.vehicle)).warning, isNull);
    expect(checkMove(ScanMode.take, cyl(CylinderStatus.customer)).warning, isNull);
    expect(checkMove(ScanMode.returned, cyl(CylinderStatus.vehicle, filled: false)).warning, isNull);
  });

  test('surprises are warnings, not blocks', () {
    final c = checkMove(ScanMode.load, cyl(CylinderStatus.godown, filled: false));
    expect(c.allowed, isTrue);
    expect(c.warning, 'Recorded as empty.');
    expect(checkMove(ScanMode.give, cyl(CylinderStatus.customer, holderName: 'Ma Tara Store')).warning,
        'Already with Ma Tara Store.');
  });

  test('retired cylinders are blocked', () {
    expect(checkMove(ScanMode.give, cyl(CylinderStatus.retired)).allowed, isFalse);
  });

  test('a lost cylinder turning up is flagged', () {
    expect(checkMove(ScanMode.take, cyl(CylinderStatus.lost)).warning, startsWith('Was marked lost.'));
  });

  test('targets: take makes it an empty in my vehicle, return keeps fill state', () {
    expect(ScanMode.take.target(cyl(CylinderStatus.customer)), (CylinderStatus.vehicle, false));
    expect(ScanMode.returned.target(cyl(CylinderStatus.vehicle, filled: false)), (CylinderStatus.godown, false));
    expect(ScanMode.returned.target(cyl(CylinderStatus.vehicle)), (CylinderStatus.godown, true));
  });
}
