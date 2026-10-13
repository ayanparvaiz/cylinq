import 'package:cloud_firestore/cloud_firestore.dart';

import 'cylinder_status.dart';

/// One physical cylinder. Its document id is the serial printed on its QR label.
class Cylinder {
  const Cylinder({
    required this.serial,
    required this.typeId,
    required this.typeName,
    required this.status,
    required this.filled,
    this.holderId,
    this.holderName,
    this.areaId,
    this.lastGeo,
    this.lastEventAt,
  });

  final String serial;
  final String typeId;
  final String typeName;
  final CylinderStatus status;
  final bool filled;

  /// Staff uid when in a vehicle, customer id when with a customer.
  final String? holderId;
  final String? holderName;
  final String? areaId;
  final GeoPoint? lastGeo;
  final DateTime? lastEventAt;

  String get stateLabel => switch (status) {
    CylinderStatus.godown || CylinderStatus.vehicle =>
      '${status.label} · ${filled ? 'Full' : 'Empty'}',
    _ => status.label,
  };

  factory Cylinder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Cylinder(
      serial: doc.id,
      typeId: d['typeId'] as String? ?? '',
      typeName: d['typeName'] as String? ?? '',
      status: CylinderStatus.parse(d['status']),
      filled: d['filled'] as bool? ?? false,
      holderId: d['holderId'] as String?,
      holderName: d['holderName'] as String?,
      areaId: d['areaId'] as String?,
      lastGeo: d['lastGeo'] as GeoPoint?,
      lastEventAt: (d['lastEventAt'] as Timestamp?)?.toDate(),
    );
  }
}
