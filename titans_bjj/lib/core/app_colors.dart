import 'package:flutter/material.dart';

class AppColors {
  final Color background;
  final Color overlay;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  const AppColors({
    required this.background,
    required this.overlay,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });
}

/// Tema escuro (default – luta, academia)
const darkColors = AppColors(
  background: Colors.black,
  overlay: Colors.black54,
  card: Color(0xFF1E1E1E),
  textPrimary: Colors.white,
  textSecondary: Colors.white70,
  accent: Color(0xFFD4AF37), // dourado
);

/// Tema claro (futuro)
const lightColors = AppColors(
  background: Color(0xFFF4F4F4),
  overlay: Colors.white70,
  card: Colors.white,
  textPrimary: Colors.black,
  textSecondary: Colors.black54,
  accent: Color(0xFFB8962E),
);
