import 'package:flutter/material.dart';

class AppColors {
  // Primary Color: Deep Blood Red
  static const Color primary = Color(0xFFC62828);

  // Secondary: Soft Blood Red
  static const Color secondary = Color(0xFFEF5350);

  // Accent: Light Blood Red
  static const Color accent = Color(0xFFFFCDD2);

  // Background Light: White
  static const Color backgroundLight = Color(0xFFFFFFFF);

  // Background Dark: Dark Gray
  static const Color backgroundDark = Color(0xFF1A1A1A);

  // Text Light Mode
  static const Color textLight = Color(0xFF333333);

  // Text Dark Mode
  static const Color textDark = Color(0xFFEEEEEE);

  // Success
  static const Color success = Color(0xFF2E7D32);

  // Warning
  static const Color warning = Color(0xFFF57C00);

  // Divider
  static const Color divider = Color(0xFFE0E0E0);

  // Circle Icon Background
  static Color circleIconBg = Colors.red.withOpacity(0.1);

  /// Returns a distinct color for each blood group for easy differentiation.
  static Color getBloodGroupColor(String bloodGroup) {
    switch (bloodGroup.toUpperCase()) {
      case 'A+': return const Color(0xFF1976D2); // Blue
      case 'A-': return const Color(0xFF0288D1); // Light Blue
      case 'B+': return const Color(0xFF388E3C); // Green
      case 'B-': return const Color(0xFF689F38); // Light Green
      case 'O+': return const Color(0xFFE64A19); // Deep Orange
      case 'O-': return const Color(0xFFF57C00); // Orange
      case 'AB+': return const Color(0xFF7B1FA2); // Purple
      case 'AB-': return const Color(0xFF512DA8); // Deep Purple
      default: return primary;
    }
  }
}

class AppSpacing {
  static double horizontalPadding(BuildContext context) => MediaQuery.of(context).size.width * 0.05;
  static double verticalPadding(BuildContext context) => MediaQuery.of(context).size.height * 0.02;
}
