import 'package:flutter/material.dart';

@immutable
class TitansColors extends ThemeExtension<TitansColors> {
  final Color background;
  final Color overlay;
  final Color card;
  final Color elevatedSurface;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textFaint;
  final Color accent; // dourado / destaque
  final Color technical;
  final Color success;
  final Color alert;
  final Color beltWhite;
  final Color beltBlue;
  final Color beltPurple;
  final Color beltBrown;
  final Color beltBlack;

  const TitansColors({
    required this.background,
    required this.overlay,
    required this.card,
    required this.elevatedSurface,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.accent,
    required this.technical,
    required this.success,
    required this.alert,
    required this.beltWhite,
    required this.beltBlue,
    required this.beltPurple,
    required this.beltBrown,
    required this.beltBlack,
  });

  Color get surface => card;
  Color get subtleBorder => cardBorder;
  Color get action => accent;

  @override
  TitansColors copyWith({
    Color? background,
    Color? overlay,
    Color? card,
    Color? elevatedSurface,
    Color? cardBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textFaint,
    Color? accent,
    Color? technical,
    Color? success,
    Color? alert,
    Color? beltWhite,
    Color? beltBlue,
    Color? beltPurple,
    Color? beltBrown,
    Color? beltBlack,
  }) {
    return TitansColors(
      background: background ?? this.background,
      overlay: overlay ?? this.overlay,
      card: card ?? this.card,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      cardBorder: cardBorder ?? this.cardBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textFaint: textFaint ?? this.textFaint,
      accent: accent ?? this.accent,
      technical: technical ?? this.technical,
      success: success ?? this.success,
      alert: alert ?? this.alert,
      beltWhite: beltWhite ?? this.beltWhite,
      beltBlue: beltBlue ?? this.beltBlue,
      beltPurple: beltPurple ?? this.beltPurple,
      beltBrown: beltBrown ?? this.beltBrown,
      beltBlack: beltBlack ?? this.beltBlack,
    );
  }

  @override
  TitansColors lerp(ThemeExtension<TitansColors>? other, double t) {
    if (other is! TitansColors) return this;
    return TitansColors(
      background: Color.lerp(background, other.background, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      card: Color.lerp(card, other.card, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      technical: Color.lerp(technical, other.technical, t)!,
      success: Color.lerp(success, other.success, t)!,
      alert: Color.lerp(alert, other.alert, t)!,
      beltWhite: Color.lerp(beltWhite, other.beltWhite, t)!,
      beltBlue: Color.lerp(beltBlue, other.beltBlue, t)!,
      beltPurple: Color.lerp(beltPurple, other.beltPurple, t)!,
      beltBrown: Color.lerp(beltBrown, other.beltBrown, t)!,
      beltBlack: Color.lerp(beltBlack, other.beltBlack, t)!,
    );
  }
}

TitansColors titansColors(BuildContext context) =>
    Theme.of(context).extension<TitansColors>()!;

/// DARK
ThemeData buildTitansDarkTheme() {
  const ext = TitansColors(
    background: Color(0xFF070A0F),
    overlay: Color(0xD9000000),
    card: Color(0xE60B111A),
    elevatedSurface: Color(0xFF101826),
    cardBorder: Color(0x38FFFFFF),
    textPrimary: Color(0xFFF6F7FA),
    textSecondary: Color(0xC9D7DCE8),
    textFaint: Color(0x80D7DCE8),
    accent: Color(0xFFE9C46A),
    technical: Color(0xFF2D6BFF),
    success: Color(0xFF70E000),
    alert: Color(0xFFFF5C5C),
    beltWhite: Color(0xE6FFFFFF),
    beltBlue: Color(0xFF2D6BFF),
    beltPurple: Color(0xFFB026FF),
    beltBrown: Color(0xFF8D6E63),
    beltBlack: Color(0xFFE6E6E6),
  );

  final baseScheme = ColorScheme.fromSeed(
    seedColor: ext.accent,
    brightness: Brightness.dark,
  );

  final scheme = baseScheme.copyWith(
    primary: ext.accent,
    secondary: ext.technical,
    tertiary: ext.beltPurple,
    surface: ext.background,
    surfaceContainerHighest: ext.card,
    onSurface: ext.textPrimary,
    outline: ext.cardBorder,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: ext.background,
    extensions: const [ext],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ext.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 46),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ext.accent,
      foregroundColor: const Color(0xFF121212),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      minLeadingWidth: 36,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titleTextStyle: TextStyle(
        color: ext.textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
      subtitleTextStyle: TextStyle(color: ext.textSecondary, fontSize: 13),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      indicatorColor: ext.accent.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? ext.textPrimary : ext.textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? ext.accent : ext.textSecondary,
          size: selected ? 26 : 24,
        );
      }),
    ),
    cardTheme: CardThemeData(
      color: ext.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: ext.cardBorder),
      ),
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: ext.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ext.textPrimary,
      ),
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
    elevatedSurface: Color(0xFFFFFFFF),
    cardBorder: Color(0x1A0B0D10),
    textPrimary: Color(0xFF0B0D10),
    textSecondary: Color(0xB30B0D10),
    textFaint: Color(0x660B0D10),
    accent: Color(0xFFB8860B),
    technical: Color(0xFF2D6BFF),
    success: Color(0xFF2E7D32),
    alert: Color(0xFFC62828),
    beltWhite: Color(0xFFFFFFFF),
    beltBlue: Color(0xFF2D6BFF),
    beltPurple: Color(0xFF7B1FA2),
    beltBrown: Color(0xFF795548),
    beltBlack: Color(0xFF1F232B),
  );

  final baseScheme = ColorScheme.fromSeed(
    seedColor: ext.accent,
    brightness: Brightness.light,
  );

  final scheme = baseScheme.copyWith(
    primary: ext.accent,
    secondary: ext.technical,
    tertiary: ext.beltPurple,
    surface: ext.background,
    surfaceContainerHighest: ext.card,
    onSurface: ext.textPrimary,
    outline: ext.cardBorder,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: ext.background,
    extensions: const [ext],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ext.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 46),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ext.accent,
      foregroundColor: const Color(0xFF121212),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      minLeadingWidth: 36,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titleTextStyle: TextStyle(
        color: ext.textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
      subtitleTextStyle: TextStyle(color: ext.textSecondary, fontSize: 13),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      indicatorColor: ext.accent.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? ext.textPrimary : ext.textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? ext.accent : ext.textSecondary,
          size: selected ? 26 : 24,
        );
      }),
    ),
    cardTheme: CardThemeData(
      color: ext.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: ext.cardBorder),
      ),
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: ext.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ext.textPrimary,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: ext.textSecondary),
    ),
  );
}
