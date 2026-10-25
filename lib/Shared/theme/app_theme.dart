import 'package:flutter/material.dart';

import 'canopy_tokens.dart';
import '../../theme/canopy_tokens.dart' show CanopyPalette;

// Re-exported so every file that already imports app_theme.dart gets the
// design tokens (CanopyColor / CanopyRadius / CanopySpace / CanopyIcon /
// CanopyShadow / CanopyType / CanopyTouch) with no new import. See
// canopy_tokens.dart for the rules on using them.
export 'canopy_tokens.dart';

/// Brand colours and the assembled [ThemeData] for both brightnesses.
///
/// The colour constants below are kept as the names 127 files already import,
/// but they are now aliases of [CanopyColor] rather than independent
/// definitions — there is exactly one place a brand colour is declared.
/// Prefer the semantic [CanopyColor] names in new code: `CanopyColor.ink` says
/// what it's for, `AppTheme.darkGreen` only says what it looks like.
class AppTheme {
  // Extracted from Canopy logo
  static const Color primary = CanopyColor.primary; // Forest green
  static const Color secondary = CanopyColor.primaryDim; // Medium green
  static const Color accent = CanopyColor.accent; // Teal
  static const Color tertiary = CanopyColor.gold; // Gold
  static const Color lightGreen = CanopyColor.primarySoft; // Light green
  static const Color darkGreen = Color(0xFF1F5539); // Dark forest green

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      surface: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      canvasColor: Colors.white,
      fontFamily: 'Roboto',
      extensions: const [CanopyPalette.light],
      textTheme: _textTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: darkGreen,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightGreen.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIconColor: accent,
        suffixIconColor: accent,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: primary.withOpacity(0.1),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightGreen.withOpacity(0.15),
        labelStyle:
            const TextStyle(color: darkGreen, fontWeight: FontWeight.w600),
        side: BorderSide(color: primary.withOpacity(0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tertiary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        circularTrackColor: primary.withOpacity(0.2),
      ),
      dividerTheme: DividerThemeData(
        color: darkGreen.withOpacity(0.15),
        thickness: 1,
        space: 16,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: darkGreen.withOpacity(0.4),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: lightGreen.withOpacity(0.3),
        elevation: 8,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: darkGreen),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
      ),
    );
    return _applyStructure(base, Brightness.light);
  }

  /// The structural half of the theme — surfaces, radii, borders — applied to
  /// BOTH brightnesses from the same tokens.
  ///
  /// This used to be `CanopyUi.theme(base)`, called only at the end of
  /// [light]. That meant light mode silently got CanopyUi's surfaces, radii
  /// and outlined cards (overriding what [light] had just set two lines
  /// earlier, including `scaffoldBackgroundColor`), while [dark] never passed
  /// through it at all — so the two brightnesses disagreed about what a card
  /// even is. Both now run through here.
  static ThemeData _applyStructure(ThemeData base, Brightness brightness) {
    final canvas = CanopyColor.canvasOf(brightness);
    final surface = CanopyColor.surfaceOf(brightness);
    final ink = CanopyColor.inkOf(brightness);
    final outline = CanopyColor.outlineOf(brightness);

    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      dividerColor: outline,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // Outlined, not shadowed. See CanopyShadow's doc comment.
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: CanopyRadius.all(CanopyRadius.md),
          side: BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CanopySpace.lg,
          vertical: CanopySpace.md + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: CanopyRadius.all(CanopyRadius.sm),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: CanopyRadius.all(CanopyRadius.sm),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: CanopyRadius.all(CanopyRadius.sm),
          borderSide: const BorderSide(color: CanopyColor.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: CanopyRadius.all(CanopyRadius.sm),
          borderSide: const BorderSide(color: CanopyColor.danger),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: CanopyRadius.all(CanopyRadius.xs),
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: CanopyRadius.all(CanopyRadius.md),
        ),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: CanopyRadius.top(CanopyRadius.lg),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outline,
        thickness: 1,
        space: CanopySpace.lg,
      ),
    );
  }

  static ThemeData dark() {
    // Ends with the same _applyStructure pass as light() — see its comment.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: lightGreen,
      secondary: accent,
      tertiary: tertiary,
      surface: const Color(0xFF0A1F14),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0A1F14), // Deep forest green
      canvasColor: const Color(0xFF0A1F14),
      fontFamily: 'Roboto',
      extensions: const [CanopyPalette.dark],
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF0F2A1A),
        surfaceTintColor: Colors.transparent,
        foregroundColor: lightGreen,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightGreen, width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFF0F2A1A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIconColor: accent,
        suffixIconColor: accent,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Color(0xFF143525),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black45,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: accent.withOpacity(0.2),
        labelStyle: TextStyle(color: lightGreen, fontWeight: FontWeight.w500),
        side: BorderSide(color: accent.withOpacity(0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tertiary,
        foregroundColor: darkGreen,
        elevation: 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightGreen,
          side: BorderSide(color: lightGreen, width: 1.5),
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: lightGreen,
        circularTrackColor: accent.withOpacity(0.3),
      ),
      dividerTheme: DividerThemeData(
        color: accent.withOpacity(0.2),
        thickness: 1,
        space: 16,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0F2A1A),
        selectedItemColor: tertiary,
        unselectedItemColor: accent.withOpacity(0.5),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Color(0xFF0F2A1A),
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withOpacity(0.3),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Color(0xFF143525),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: Color(0xFF0F2A1A),
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Color(0xFF143525),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: Color(0xFF0F2A1A),
        surfaceTintColor: Colors.transparent,
        elevation: 8,
      ),
    );
    return _applyStructure(base, Brightness.dark);
  }

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true).textTheme
        : ThemeData.light(useMaterial3: true).textTheme;

    final color = brightness == Brightness.dark ? lightGreen : darkGreen;

    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
