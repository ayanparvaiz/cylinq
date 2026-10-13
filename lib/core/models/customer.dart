import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.areaId,
    this.areaName = '',
    this.geo,
    this.holding = 0,
    this.totalQty = 0,
    this.lastSaleAt,
  });

  final String id;
  final String name;
  final String phone;
  final String address;
  final String? areaId;
  final String areaName;

  /// Where the shop or house is, taken from the phone's GPS on first delivery.
  final GeoPoint? geo;

  /// How many of our cylinders this customer has right now.
  final int holding;

  /// Cylinders sold to this customer, all time.
  final int totalQty;
  final DateTime? lastSaleAt;

  factory Customer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Customer(
      id: doc.id,
      name: d['name'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      address: d['address'] as String? ?? '',
      areaId: d['areaId'] as String?,
      areaName: d['areaName'] as String? ?? '',
      geo: d['geo'] as GeoPoint?,
      holding: (d['holding'] as num?)?.toInt() ?? 0,
      totalQty: (d['totalQty'] as num?)?.toInt() ?? 0,
      lastSaleAt: (d['lastSaleAt'] as Timestamp?)?.toDate(),
    );
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        phone.contains(q) ||
        areaName.toLowerCase().contains(q);
  }
}
