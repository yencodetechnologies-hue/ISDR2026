import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color risecolor = Color(0xFF0B4FC2);
  // Color Palette
  static const Color primaryColor = Color(0xFF13275D); // Royal Navy Blue #13275D
  static const Color secondaryColor = Color(0xFF10B981); // Green
  static const Color accentColor = Color(0xFF111827); // Black
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color backgroundColor = Color(0xFFF9FAFB); // Light Grey
  static const Color textColor = Color(0xFF111827); // Dark Grey
  static const Color dividerColor = Color(0xFFE5E7EB); // Grey

  /// Register Visitor / Security / Admin AppBar — Deep Navy Blue #13275D gradient.
  static LinearGradient get brandHeaderGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF13275D),
          Color(0xFF1E3A8A),
        ],
      );

  /// Light hero cards (e.g. Security Control Center).
  static LinearGradient get brandSoftSurfaceGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryColor.withAlpha(25),
          secondaryColor.withAlpha(20),
        ],
      );

  /// Success CTA — emerald → teal.
  static LinearGradient get brandSecondaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          secondaryColor,
          const Color(0xFF059669),
          primaryColor.withOpacityCompat(0.35),
        ],
      );

  /// Destructive CTA — red → deep rose.
  static LinearGradient get brandErrorGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          errorColor,
          Color(0xFFDC2626),
          Color(0xFFB91C1C),
        ],
      );

  /// Accent CTA (QR scan, highlights) — Royal Navy → Black.
  static LinearGradient get brandAccentGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF13275D),
          Color(0xFF111827),
        ],
      );

  static const double elevatedButtonRadius = 14;

  static ButtonStyle _gradientElevatedStyle({
    required LinearGradient enabledGradient,
    required Color shadowTint,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    double borderRadius = elevatedButtonRadius,
  }) {
    return ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white,
      backgroundColor: Colors.transparent,
      disabledBackgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      padding: padding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ).copyWith(
      backgroundBuilder: (context, states, child) {
        final disabled = states.contains(WidgetState.disabled);
        final radius = BorderRadius.circular(borderRadius);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: disabled ? null : enabledGradient,
            color: disabled ? Colors.grey.shade400 : null,
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: shadowTint.withOpacityCompat(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: child,
        );
      },
    );
  }

  /// Primary CTA — navy → green tint ([brandHeaderGradient]).
  static ButtonStyle get primaryElevatedStyle => _gradientElevatedStyle(
        enabledGradient: brandHeaderGradient,
        shadowTint: primaryColor,
      );

  /// Success / secondary actions (green dual-tone).
  static ButtonStyle get secondaryElevatedStyle => _gradientElevatedStyle(
        enabledGradient: brandSecondaryGradient,
        shadowTint: secondaryColor,
      );

  /// Destructive actions (delete, remove).
  static ButtonStyle get errorElevatedStyle => _gradientElevatedStyle(
        enabledGradient: brandErrorGradient,
        shadowTint: errorColor,
      );

  /// Highlight actions (scan QR, quick actions).
  static ButtonStyle get accentElevatedStyle => _gradientElevatedStyle(
        enabledGradient: brandAccentGradient,
        shadowTint: accentColor,
      );

  /// Compact toolbar / inline elevated buttons (10px radius).
  static ButtonStyle get primaryElevatedCompactStyle => _gradientElevatedStyle(
        enabledGradient: brandHeaderGradient,
        shadowTint: primaryColor,
        borderRadius: 10,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      );

  static ButtonStyle get secondaryElevatedCompactStyle =>
      _gradientElevatedStyle(
        enabledGradient: brandSecondaryGradient,
        shadowTint: secondaryColor,
        borderRadius: 10,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      );

  static ButtonStyle get accentElevatedCompactStyle => _gradientElevatedStyle(
        enabledGradient: brandAccentGradient,
        shadowTint: accentColor,
        borderRadius: 10,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      );

  /// Full-width primary CTA — use inside [SizedBox] with `width: double.infinity`.
  static ButtonStyle primaryElevatedFullWidth({double minHeight = 50}) =>
      primaryElevatedStyle.copyWith(
        minimumSize: WidgetStateProperty.all(Size(double.infinity, minHeight)),
      );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        toolbarTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white,
        shadowColor: Colors.black.withOpacityCompat(0.1),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: GoogleFonts.inter(fontSize: 14, color: textColor),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: textColor.withOpacityCompat(0.5)),
        helperStyle: GoogleFonts.inter(fontSize: 12, color: textColor.withOpacityCompat(0.6)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: primaryElevatedStyle,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: textColor,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: textColor,
        ),
      ),
    );
  }
}

// Extension to provide compatibility for opacity operations
extension ColorWithOpacityCompat on Color {
  Color withOpacityCompat(double opacity) {
    return withAlpha((opacity * 255).round());
  }
}
