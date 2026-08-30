import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// StrokeGuard design system — "forest premium" green.
///
/// Inspired by top-tier health apps: deep-green hero surfaces, soft
/// green-tinted shadows, generous radii, and a strong type hierarchy
/// (Manrope for headlines, Inter for body).
class AppTheme {
  AppTheme._();

  // ── Brand greens ────────────────────────────────────────────────
  static const Color forest = Color(0xFF043D2B); // darkest hero tone
  static const Color deepGreen = Color(0xFF065F43);
  static const Color primaryGreen = Color(0xFF0E8A5F);
  static const Color brightGreen = Color(0xFF16A874);
  static const Color midGreen = Color(0xFF4CBB8F);
  static const Color softMint = Color(0xFFE4F4EA);
  static const Color mintSurface = Color(0xFFF3FAF5);

  // ── Ink (text) tokens ───────────────────────────────────────────
  static const Color inkPrimary = Color(0xFF0F241A);
  static const Color inkSecondary = Color(0xFF46604F);
  static const Color inkMuted = Color(0xFF7C917F);

  // ── Chart chrome ────────────────────────────────────────────────
  static const Color gridLine = Color(0xFFE3EFE6);

  // ── Status palette (risk levels) — always icon + label, never
  //    color alone. ─────────────────────────────────────────────────
  static const Color riskLow = Color(0xFF12A150);
  static const Color riskMedium = Color(0xFFE8A213);
  static const Color riskHigh = Color(0xFFD64545);

  // ── Gradients ───────────────────────────────────────────────────
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF054D36), Color(0xFF0E8A5F)],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E8A5F), Color(0xFF16A874)],
  );

  static const LinearGradient avatarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF16A874), Color(0xFF0B6B4A)],
  );

  // ── Shadows ─────────────────────────────────────────────────────
  /// Soft resting shadow for white cards.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x120B6B4A),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// Colored glow under prominent elements (buttons, logo).
  static List<BoxShadow> glow(Color color, {double alpha = .32}) => [
        BoxShadow(
          color: color.withValues(alpha: alpha),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  // ── Radii ───────────────────────────────────────────────────────
  static const double radiusCard = 20;
  static const double radiusField = 14;
  static const double radiusButton = 14;

  static ThemeData get light {
    final base = ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.light,
    );
    final scheme = base.copyWith(
      primary: primaryGreen,
      onPrimary: Colors.white,
      secondary: midGreen,
      surface: mintSurface,
      onSurface: inkPrimary,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: softMint,
      outline: const Color(0xFFC9DCD0),
      outlineVariant: const Color(0xFFDDEBE2),
      error: riskHigh,
    );

    // Manrope for the display/headline/title voice, Inter for body copy.
    final inter = GoogleFonts.interTextTheme();
    final manrope = GoogleFonts.manropeTextTheme();
    final textTheme = inter
        .copyWith(
          displayLarge: manrope.displayLarge
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
          displayMedium: manrope.displayMedium
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
          displaySmall: manrope.displaySmall
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5),
          headlineLarge: manrope.headlineLarge
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5),
          headlineMedium: manrope.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5),
          headlineSmall: manrope.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.25),
          titleLarge: manrope.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.25),
          titleMedium:
              manrope.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          titleSmall:
              manrope.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        )
        .apply(bodyColor: inkPrimary, displayColor: inkPrimary);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: mintSurface,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: mintSurface,
        foregroundColor: inkPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: Color(0xFFE3EFE6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: const BorderSide(color: Color(0xFFD5E6DA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: const BorderSide(color: Color(0xFFD5E6DA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: inkSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: inkMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: .2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          minimumSize: const Size(64, 52),
          side: const BorderSide(color: Color(0xFFB7D8C5), width: 1.4),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: .2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: softMint,
        labelStyle: textTheme.labelMedium?.copyWith(color: deepGreen),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        selectedIconTheme: const IconThemeData(color: deepGreen),
        unselectedIconTheme: const IconThemeData(color: inkMuted),
        selectedLabelTextStyle: textTheme.labelMedium!.copyWith(
          color: deepGreen,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle:
            textTheme.labelMedium!.copyWith(color: inkMuted),
        indicatorColor: softMint,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        height: 68,
        indicatorColor: softMint,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? deepGreen
                : inkMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected)
                ? deepGreen
                : inkMuted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE3EFE6),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: forest,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryGreen,
        linearTrackColor: softMint,
        circularTrackColor: softMint,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primaryGreen
              : const Color(0xFFCFE2D6),
        ),
        trackOutlineColor:
            const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primaryGreen
              : Colors.transparent,
        ),
        side: const BorderSide(color: Color(0xFFB7D8C5), width: 1.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        extendedTextStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: primaryGreen,
      ),
    );
  }
}
