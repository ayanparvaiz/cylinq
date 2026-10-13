import 'package:flutter/material.dart';

import '../models/cylinder.dart';

/// Coloured pill showing where a cylinder is and whether it is full.
class StatusChip extends StatelessWidget {
  const StatusChip(this.cylinder, {super.key, this.dense = false});

  final Cylinder cylinder;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = cylinder.status.color(filled: cylinder.filled);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cylinder.status.icon, size: dense ? 13 : 15, color: color),
          const SizedBox(width: 5),
          Text(
            cylinder.stateLabel,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: dense ? 11.5 : 12.5),
          ),
        ],
      ),
    );
  }
}
