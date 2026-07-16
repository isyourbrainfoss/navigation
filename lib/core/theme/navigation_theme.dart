import 'package:flutter/material.dart';

/// Material 3 map-friendly palette (light + dark).
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

  /// Route line color (works on both light and dark basemaps).
  static const routeColor = Color(0xFF2563EB);
  static const routeOutline = Color(0xFFFFFFFF);

  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      primary: _darkPrimary,
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
    return _build(scheme, _darkBg);
  }

  static ThemeData light() {
    final scheme = ColorScheme.light(
      primary: _lightPrimary,
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
    return _build(scheme, _lightBg);
  }

  static ThemeData _build(ColorScheme scheme, Color scaffoldBg) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      // Consistent Linux / desktop metrics.
      platform: TargetPlatform.linux,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
