import 'package:flutter/material.dart';

/// Shared visual language for Canopy's content-heavy screens.
///
/// The palette is intentionally quiet: records, stories, and operational
/// status remain the strongest elements on a page.
abstract final class CanopyUi {
  static const Color canvas = Color(0xFFF6F3EC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF0EEE7);
  static const Color sage = Color(0xFFEAF1EB);
  static const Color ink = Color(0xFF173728);
  static const Color inkMuted = Color(0xFF607067);
  static const Color primary = Color(0xFF2D7A4F);
  static const Color teal = Color(0xFF3B8A7A);
  static const Color gold = Color(0xFFC4A961);
  static const Color danger = Color(0xFFA33E3E);
  static const Color outline = Color(0xFFDDE2DC);

  static const double pageGutter = 18;
  static const double sectionGap = 24;
  static const double heroRadius = 24;
  static const double cardRadius = 18;
  static const double controlRadius = 14;
  static const double minimumTarget = 48;

  static ThemeData theme(ThemeData base) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: surface,
    ).copyWith(
      primary: primary,
      secondary: teal,
      tertiary: gold,
      onSurface: ink,
      outline: outline,
      error: danger,
    );

    return base.copyWith(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      dividerColor: outline,
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
          side: BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(controlRadius)),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(controlRadius)),
          borderSide: BorderSide(color: outline),
        ),
      ),
    );
  }
}
