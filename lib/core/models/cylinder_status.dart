import 'package:flutter/material.dart';

import '../design/app_colors.dart';

/// Where a cylinder physically is. Whether it holds gas is tracked separately
/// as `filled`, because an empty can sit in a vehicle just as a full one can.
enum CylinderStatus {
  godown('Godown', Icons.warehouse_outlined),
  vehicle('In vehicle', Icons.local_shipping_outlined),
  customer('With customer', Icons.storefront_outlined),
  lost('Lost', Icons.report_gmailerrorred_outlined),
  retired('Retired', Icons.block_outlined);

  const CylinderStatus(this.label, this.icon);

  final String label;
  final IconData icon;

  static CylinderStatus parse(Object? value) => CylinderStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => CylinderStatus.godown,
  );

  Color color({required bool filled}) => switch (this) {
    CylinderStatus.godown => filled ? AppColors.full : AppColors.empty,
    CylinderStatus.vehicle => AppColors.vehicle,
    CylinderStatus.customer => AppColors.customer,
    CylinderStatus.lost => AppColors.lost,
    CylinderStatus.retired => AppColors.retired,
  };
}
