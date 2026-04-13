import 'package:flutter/material.dart';

@immutable
class TitansColors extends ThemeExtension<TitansColors> {

  final Color background;
  final Color overlay;
  final Color card;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent; // dourado / destaque

  const TitansColors({
    required this.background,
    required this.overlay,
    required this.card,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  @override
  TitansColors copyWith({
    Color? background,
    Color? overlay,
    Color? card,
    Color? cardBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
  }) {
    return TitansColors(
      background: background ?? this.background,
      overlay: overlay ?? this.overlay,
      card: card ?? this.card,
      cardBorder: cardBorder ?? this.cardBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
    );
  }

  @override
  TitansColors lerp(ThemeExtension<TitansColors>? other, double t) {
    if (other is! TitansColors) return this;
    return TitansColors(
      background: Color.lerp(background, other.background, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

TitansColors titansColors(BuildContext context) =>
    Theme.of(context).extension<TitansColors>()!;

/// DARK
ThemeData buildTitansDarkTheme() {
  const ext = TitansColors(
    background: Color(0xFF0B0D10),
    overlay: Color(0xB3000000),
    card: Color(0xCC12161D),
    cardBorder: Color(0x332B3240),
    textPrimary: Color(0xFFF2F3F5),
    textSecondary: Color(0xB3F2F3F5),
    accent: Color(0xFFF5C84C),
  );


  final scheme = ColorScheme.fromSeed(
    seedColor: ext.accent,
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: ext.background,
    extensions: const [ext],
    appBarTheme:  AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ext.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: ext.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: ext.cardBorder),
      ),
    ),
    textTheme:  TextTheme(
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ext.textPrimary),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ext.textPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: ext.textSecondary),
    ),
  );
}

/// LIGHT
ThemeData buildTitansLightTheme() {
  const ext = TitansColors(
    background: Color(0xFFF5F6F8),
    overlay: Color(0x66FFFFFF),
    card: Color(0xEFFFFFFF),
    cardBorder: Color(0x1A0B0D10),
    textPrimary: Color(0xFF0B0D10),
    textSecondary: Color(0xB30B0D10),
    accent: Color(0xFFB8860B), // dourado mais “sóbrio” no claro
  );

  final scheme = ColorScheme.fromSeed(
    seedColor: ext.accent,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: ext.background,
    extensions: const [ext],
    appBarTheme:  AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ext.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: ext.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: ext.cardBorder),
      ),
    ),
    textTheme:  TextTheme(
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ext.textPrimary),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ext.textPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: ext.textSecondary),
    ),
  );
}
