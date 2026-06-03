import 'package:flutter/material.dart';

/// Application-wide theme and color constants with premium aesthetics.
class AppTheme {
  AppTheme._();

  // ── Brand Colors (Vibrant Neons) ─────────────────────────────
  static const Color primary = Color(0xFF3B82F6); // Electric Blue
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF2563EB);
  static const Color accent = Color(0xFF00F0FF); // Neon Cyan
  static const Color accentWarm = Color(0xFFFF007A); // Neon Pink

  // ── Gradients ────────────────────────────────────────────────
  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
    ],
  );

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0B1121), // Deep Midnight
      Color(0xFF060913), // Almost Black
    ],
  );

  // ── Palette (Backgrounds & Surfaces) ─────────────────────────
  static const Color bgDark = Color(0xFF0B1121);
  static const Color bgCard = Color(0xFF151C2C);
  static const Color bgCardHover = Color(0xFF1E2638);
  static const Color bgSurface = Color(0xFF1E293B);
  static const Color bgInput = Color(0xFF111827);
  static const Color border = Color(0xFF2A3447);
  static const Color borderLight = Color(0xFF3F4D63);

  // ── Text Colors ───────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // ── Status Colors ─────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // ── Semantic Tag Colors ───────────────────────────────────────
  static const Color tagProperty = Color(0xFF3B82F6);
  static const Color tagLocality = Color(0xFF8B5CF6);
  static const Color tagMarketplace = Color(0xFF10B981);
  static const Color tagSecondary = Color(0xFFF59E0B);

  // ── Radius ────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;

  // ── Shadows (Glass & Glow) ────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];
      
  static List<BoxShadow> get glowShadow => [
        BoxShadow(
          color: primary.withOpacity(0.3),
          blurRadius: 15,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get dropdownShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 30,
          offset: const Offset(0, 15),
        ),
      ];

  // ── ThemeData ─────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: bgCard,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgInput,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 16),
        prefixIconColor: textMuted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          elevation: 4,
          shadowColor: primary.withOpacity(0.5),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bgSurface,
        selectedColor: primary.withOpacity(0.2),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        side: const BorderSide(color: border),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
    );
  }
}
