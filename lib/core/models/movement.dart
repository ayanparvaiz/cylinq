import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'cylinder_status.dart';

/// Every way a cylinder can move. The admin-only ones are enforced by rules too.
enum MoveType {
  register('Registered', Icons.qr_code_2, adminOnly: true),
  fill('Filled', Icons.local_fire_department_outlined),
  load('Loaded', Icons.upload_outlined),
  deliver('Delivered', Icons.storefront_outlined),
  collect('Empty collected', Icons.download_outlined),
  returned('Returned to godown', Icons.warehouse_outlined),
  lost('Marked lost', Icons.report_gmailerrorred_outlined, adminOnly: true),
  found('Found', Icons.search, adminOnly: true),
  retire('Retired', Icons.block_outlined, adminOnly: true),
  adjust('Corrected', Icons.edit_outlined, adminOnly: true);

  const MoveType(this.label, this.icon, {this.adminOnly = false});

  final String label;
  final IconData icon;
  final bool adminOnly;

  /// Name stored in Firestore. `return` is a Dart keyword, hence `returned`.
  String get wire => this == MoveType.returned ? 'return' : name;

  static MoveType parse(Object? value) => value == 'return'
      ? MoveType.returned
      : MoveType.values.firstWhere(
          (t) => t.name == value,
          orElse: () => MoveType.adjust,
        );
}

/// `orgs/{orgId}/events/{id}`: one immutable line in a cylinder's history.
class CylinderEvent {
  const CylinderEvent({
    required this.id,
    required this.type,
    required this.cylinderId,
    required this.to,
    required this.filled,
    required this.byName,
    this.customerName,
    this.geo,
    this.at,
  });

  final String id;
  final MoveType type;
  final String cylinderId;
  final CylinderStatus to;
  final bool filled;
  final String byName;
  final String? customerName;
  final GeoPoint? geo;
  final DateTime? at;

  factory CylinderEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return CylinderEvent(
      id: doc.id,
      type: MoveType.parse(d['type']),
      cylinderId: d['cylinderId'] as String? ?? '',
      to: CylinderStatus.parse(d['to']),
      filled: d['filled'] as bool? ?? false,
      byName: d['byName'] as String? ?? '',
      customerName: d['customerName'] as String?,
      geo: d['geo'] as GeoPoint?,
      at: (d['at'] as Timestamp?)?.toDate(),
    );
  }
}
