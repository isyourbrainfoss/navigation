import 'package:flutter/material.dart';

import '../constants.dart';

/// Material 3 map-friendly palette (light, dark, night-driving).
abstract final class NavigationTheme {
  static const _darkBg = Color(0xFF0D1117);
  static const _darkSurface = Color(0xFF161B22);
  static const _darkCard = Color(0xFF21262D);
  static const _darkPrimary = Color(0xFF58A6FF);
  static const _darkSecondary = Color(0xFF3FB950);
  static const _darkTertiary = Color(0xFFF0883E);
  static const _darkOnSurface = Color(0xFFE6EDF3);
  static const _darkOutline = Color(0xFF484F58);

  static const _lightBg = Color(0xFFF6F8FA);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightPrimary = Color(0xFF0969DA);
  static const _lightSecondary = Color(0xFF1A7F37);
  static const _lightTertiary = Color(0xFFBF4B00);
  static const _lightOnSurface = Color(0xFF1F2328);
  static const _lightOutline = Color(0xFFD0D7DE);

  static const _nightBg = Color(0xFF050506);
  static const _nightSurface = Color(0xFF101114);
  static const _nightCard = Color(0xFF1A1C20);
  static const _nightPrimary = Color(0xFFFFB020);
  static const _nightSecondary = Color(0xFF5B8CFF);
  static const _nightOnSurface = Color(0xFFFFE7C2);

  static const routeColor = Color(0xFF3377FF);
  static const routeOutline = Color(0xFFFFFFFF);
  static const routeCasingNight = Color(0xE60B0B0C);
  static const routeTraveled = Color(0xFF64748B);
  static const routeNight = Color(0xFFFFC14A);

  static ThemeData dark({bool highContrast = false, bool largeHud = true}) {
    final scheme = ColorScheme.dark(
      primary: highContrast ? const Color(0xFF79B8FF) : _darkPrimary,
      secondary: _darkSecondary,
      tertiary: _darkTertiary,
      surface: _darkSurface,
      onSurface: _darkOnSurface,
      onPrimary: _darkBg,
      outline: _darkOutline,
      surfaceContainerHighest: _darkCard,
      surfaceContainerHigh: _darkCard,
      surfaceContainer: _darkSurface,
      error: const Color(0xFFF85149),
    );
    return _build(scheme, _darkBg, largeHud: largeHud, highContrast: highContrast);
  }

  static ThemeData light({bool highContrast = false, bool largeHud = true}) {
    final scheme = ColorScheme.light(
      primary: highContrast ? const Color(0xFF003F8F) : _lightPrimary,
      secondary: _lightSecondary,
      tertiary: _lightTertiary,
      surface: _lightSurface,
      onSurface: _lightOnSurface,
      onPrimary: Colors.white,
      outline: _lightOutline,
      surfaceContainerHighest: const Color(0xFFEEF2F6),
      surfaceContainerHigh: const Color(0xFFF3F5F7),
      surfaceContainer: _lightSurface,
      error: const Color(0xFFCF222E),
    );
    return _build(scheme, _lightBg, largeHud: largeHud, highContrast: highContrast);
  }

  static ThemeData nightDriving({bool highContrast = false, bool largeHud = true}) {
    final scheme = ColorScheme.dark(
      primary: _nightPrimary,
      secondary: _nightSecondary,
      tertiary: const Color(0xFFFF8A3D),
      surface: _nightSurface,
      onSurface: _nightOnSurface,
      onPrimary: _nightBg,
      outline: const Color(0xFF3A3428),
      surfaceContainerHighest: _nightCard,
      surfaceContainerHigh: _nightCard,
      surfaceContainer: _nightSurface,
      error: const Color(0xFFFF6B6B),
    );
    return _build(scheme, _nightBg, largeHud: largeHud, highContrast: highContrast);
  }

  static ThemeData _build(
    ColorScheme scheme,
    Color scaffoldBg, {
    required bool largeHud,
    required bool highContrast,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    final text = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: largeHud ? 40 : 32,
        letterSpacing: -0.8,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: largeHud ? 28 : 22,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    );
    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg.withValues(alpha: 0.92),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppConstants.minTouchDp),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppConstants.minTouchDp),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppConstants.minTouchDp, AppConstants.minTouchDp),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: highContrast
              ? BorderSide(color: scheme.outline)
              : BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      sliderTheme: SliderThemeData(
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        trackHeight: 6,
      ),
    );
  }
}
