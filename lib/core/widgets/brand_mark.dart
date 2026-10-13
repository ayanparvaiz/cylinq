import 'package:flutter/material.dart';

import '../design/app_colors.dart';

/// The CylinQ mark: a flame in a rounded square, with the word mark beside it.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.showName = true, this.onDark = false});

  final double size;
  final bool showName;

  /// Set on the navy sidebar so the word mark turns white.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final nameColor = onDark ? Colors.white : Theme.of(context).textTheme.titleLarge?.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF7A1A), AppColors.flameDeep],
            ),
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Icon(Icons.local_fire_department_rounded, color: Colors.white, size: size * 0.62),
        ),
        if (showName) ...[
          SizedBox(width: size * 0.3),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Cylin'),
                TextSpan(text: 'Q', style: TextStyle(color: AppColors.flame)),
              ],
            ),
            style: TextStyle(
              fontSize: size * 0.58,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: nameColor,
            ),
          ),
        ],
      ],
    );
  }
}
