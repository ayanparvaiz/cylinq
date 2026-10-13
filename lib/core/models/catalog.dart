import 'package:cloud_firestore/cloud_firestore.dart';

/// A kind of cylinder the business sells, e.g. "14.2 kg Domestic".
class CylinderType {
  const CylinderType({
    required this.id,
    required this.name,
    required this.weightKg,
    required this.price,
  });

  final String id;
  final String name;
  final double weightKg;

  /// Default refill price in rupees. Staff can change it per sale.
  final num price;

  factory CylinderType.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return CylinderType(
      id: doc.id,
      name: d['name'] as String? ?? '',
      weightKg: (d['weightKg'] as num?)?.toDouble() ?? 0,
      price: d['price'] as num? ?? 0,
    );
  }
}

/// A delivery area. Sales are grouped by these on the dashboard.
class Area {
  const Area({required this.id, required this.name, this.pincode = ''});

  final String id;
  final String name;
  final String pincode;

  factory Area.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Area(
      id: doc.id,
      name: d['name'] as String? ?? '',
      pincode: d['pincode'] as String? ?? '',
    );
  }
}
