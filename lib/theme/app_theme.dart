import 'package:flutter/material.dart';

/// Design tokens for Jolshiri Smart City.
///
/// Palette is drawn from the subject itself: Jolshiri is an Army-run
/// cantonment township built around parkland, a lake, and a golf course.
/// The identity leans on parade-ground green and brass insignia gold
/// rather than a generic tech-blue palette, with a warm paper background
/// standing in for the site's plan drawings.
class AppColors {
  AppColors._();

  static const Color parade = Color(0xFF1F3D2E); // primary — deep cantonment green
  static const Color paradeDark = Color(0xFF15291F);
  static const Color brass = Color(0xFFB8892E); // accent — insignia gold
  static const Color lake = Color(0xFF2F6B6F); // secondary accent — the Jolshiri lake
  static const Color paper = Color(0xFFF6F3EA); // background — plan-drawing cream
  static const Color paperDim = Color(0xFFEDE8D9);
  static const Color ink = Color(0xFF232620); // primary text
  static const Color inkFaint = Color(0xFF6B6F63);
  static const Color brick = Color(0xFFA5312A); // SOS / alerts — muted brick, not neon
  static const Color line = Color(0xFFD8D2BF); // hairline dividers
}

class AppRadii {
  AppRadii._();
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

    final textTheme = base.textTheme
        .copyWith(
          displaySmall: const TextStyle(
            fontFamily: 'serif',
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: AppColors.ink,
            height: 1.15,
          ),
          headlineMedium: const TextStyle(
            fontFamily: 'serif',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            height: 1.2,
          ),
          headlineSmall: const TextStyle(
            fontFamily: 'serif',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          titleLarge: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: 0.1,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
          bodyLarge: const TextStyle(fontSize: 15, color: AppColors.ink, height: 1.4),
          bodyMedium: const TextStyle(fontSize: 13.5, color: AppColors.inkFaint, height: 1.4),
          labelLarge: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
          labelSmall: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: AppColors.inkFaint,
          ),
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.parade,
        secondary: AppColors.brass,
        surface: Colors.white,
        error: AppColors.brick,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.ink,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'serif',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: const BorderSide(color: AppColors.line),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.parade,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.parade,
          side: const BorderSide(color: AppColors.parade, width: 1.4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.parade),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.parade, width: 1.6),
        ),
        hintStyle: const TextStyle(color: AppColors.inkFaint),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.paperDim,
        selectedColor: AppColors.parade,
        labelStyle: const TextStyle(color: AppColors.ink, fontSize: 12.5, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.parade,
        unselectedItemColor: AppColors.inkFaint,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brick,
        foregroundColor: Colors.white,
      ),
    );
  }
}
