import 'package:flutter/material.dart';

class AppColors {
  final Color background;
  final Color overlay;
  final Color card;
  final Color elevatedSurface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textFaint;
  final Color accent;
  final Color technical;
  final Color success;
  final Color alert;
  final Color beltWhite;
  final Color beltBlue;
  final Color beltPurple;
  final Color beltBrown;
  final Color beltBlack;

  const AppColors({
    required this.background,
    required this.overlay,
    required this.card,
    Color? elevatedSurface,
    this.border = const Color(0x24FFFFFF),
    required this.textPrimary,
    required this.textSecondary,
    Color? textFaint,
    required this.accent,
    this.technical = const Color(0xFF2D6BFF),
    this.success = const Color(0xFF70E000),
    this.alert = const Color(0xFFFF5C5C),
    this.beltWhite = const Color(0xE6FFFFFF),
    this.beltBlue = const Color(0xFF2D6BFF),
    this.beltPurple = const Color(0xFFB026FF),
    this.beltBrown = const Color(0xFF8D6E63),
    this.beltBlack = const Color(0xFFE6E6E6),
  }) : elevatedSurface = elevatedSurface ?? card,
       textFaint = textFaint ?? textSecondary;
}

/// Tema escuro (default - luta, academia)
const darkColors = AppColors(
  background: Colors.black,
  overlay: Colors.black54,
  card: Color(0xFF1E1E1E),
  elevatedSurface: Color(0xFF101826),
  border: Color(0x38FFFFFF),
  textPrimary: Colors.white,
  textSecondary: Colors.white70,
  textFaint: Color(0x80D7DCE8),
  accent: Color(0xFFD4AF37), // dourado
);

/// Tema claro (futuro)
const lightColors = AppColors(
  background: Color(0xFFF4F4F4),
  overlay: Colors.white70,
  card: Colors.white,
  elevatedSurface: Colors.white,
  border: Color(0x1A0B0D10),
  textPrimary: Colors.black,
  textSecondary: Colors.black54,
  textFaint: Color(0x660B0D10),
  accent: Color(0xFFB8962E),
  technical: Color(0xFF2D6BFF),
  success: Color(0xFF2E7D32),
  alert: Color(0xFFC62828),
  beltWhite: Colors.white,
  beltPurple: Color(0xFF7B1FA2),
  beltBrown: Color(0xFF795548),
  beltBlack: Color(0xFF1F232B),
);
