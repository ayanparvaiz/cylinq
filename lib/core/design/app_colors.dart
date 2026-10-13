import 'package:flutter/material.dart';

/// CylinQ brand palette: a flame orange for action, a deep navy for structure.
abstract final class AppColors {
  static const flame = Color(0xFFE8590C);
  static const flameDeep = Color(0xFFC2410C);
  static const flameSoft = Color(0xFFFFE8DA);

  static const ink = Color(0xFF14213D);
  static const inkSoft = Color(0xFF3D4B66);
  static const mist = Color(0xFF8A94A6);

  static const cream = Color(0xFFFFF8F3);
  static const night = Color(0xFF0E1526);
  static const nightCard = Color(0xFF172036);

  // Cylinder states. Same hue in both themes so a glance at a chip reads the
  // same on the phone in the sun and on the office monitor.
  static const full = Color(0xFF2B9348);
  static const empty = Color(0xFF7C8798);
  static const vehicle = Color(0xFF1D6FD8);
  static const customer = Color(0xFFE8590C);
  static const lost = Color(0xFFD62828);
  static const retired = Color(0xFF4B5563);
}
