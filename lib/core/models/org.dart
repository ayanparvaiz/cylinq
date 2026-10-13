import 'package:cloud_firestore/cloud_firestore.dart';

/// A gas business. Everything else lives under `orgs/{id}`.
class Org {
  const Org({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.labelPrefix,
    required this.nextSerial,
    this.phone = '',
    this.address = '',
  });

  final String id;
  final String name;
  final String ownerUid;

  /// Printed before every serial, e.g. `GS` → `GS-00042`.
  final String labelPrefix;

  /// The number the next generated label will get.
  final int nextSerial;
  final String phone;
  final String address;

  factory Org.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Org(
      id: doc.id,
      name: d['name'] as String? ?? '',
      ownerUid: d['ownerUid'] as String? ?? '',
      labelPrefix: d['labelPrefix'] as String? ?? 'CQ',
      nextSerial: (d['nextSerial'] as num?)?.toInt() ?? 1,
      phone: d['phone'] as String? ?? '',
      address: d['address'] as String? ?? '',
    );
  }

  String serialFor(int n) => '$labelPrefix-${n.toString().padLeft(5, '0')}';
}
