import 'package:flutter/material.dart';

class KairoColors {
  static const background = Color(0xFF0B0F14);
  static const surface = Color(0xFF141A22);
  static const border = Color(0xFF243044);
  static const accent = Color(0xFF2563EB);
  static const driverBoost = Color(0xFF22C55E);
  static const customerFee = Color(0xFFF59E0B);
  static const textMuted = Color(0xFF8B9CB3);
}

ThemeData get kairoDarkTheme {
  const scheme = ColorScheme.dark(
    primary: KairoColors.accent,
    surface: KairoColors.surface,
    onSurface: Color(0xFFE8ECF1),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: KairoColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: KairoColors.surface,
      foregroundColor: Color(0xFFE8ECF1),
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: KairoColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: KairoColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KairoColors.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
  );
}

ThemeData get kairoLightTheme => kairoDarkTheme;
