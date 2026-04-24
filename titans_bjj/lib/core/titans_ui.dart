import 'package:flutter/material.dart';

class TitansUI {
  static const radius = 18.0;

  static const bg = Color(0xFF070A0F);
  static const card = Color(0xFF0B111A);
  static const card2 = Color(0xFF080D14);

  static const stroke = Color(0x24FFFFFF);

  static const neonRed = Color(0xFFFF2D2D);
  static const neonPurple = Color(0xFFB026FF);
  static const neonBlue = Color(0xFF2D6BFF);
  static const neonGold = Color(0xFFE9C46A);

  static Color beltColor(String belt) {
    switch (belt) {
      case 'white':
        return Colors.white.withValues(alpha: 0.9);
      case 'blue':
        return neonBlue;
      case 'purple':
        return neonPurple;
      case 'brown':
        return const Color(0xFF8D6E63);
      case 'black':
        return const Color(0xFFE6E6E6);
      default:
        return Colors.white.withValues(alpha: 0.9);
    }
  }
}
