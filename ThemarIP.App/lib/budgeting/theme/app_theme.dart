import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the Budgeting feature.
class AppColors {
  const AppColors._();

  static const Color scaffoldBackground = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1B1633);
  static const Color mutedText = Color(0xFF76729A);
  static const Color divider = Color(0xFFE4E2F2);

  static const Color primaryPurple = Color(0xFF7B2FF7);
  static const Color primaryPurpleSoft = Color(0xFFF0E8FE);
  static const Color primaryPurpleDisabled = Color(0xFFCDBBF3);
  static const Color donutTrack = Color(0xFFEDE6FC);
  static const Color rolloverRingAccent = Color(0xFFC9A9FB);

  static const Color mint = Color(0xFF3FBFA8);
  static const Color pink = Color(0xFFE8628F);
  static const Color chipGrey = Color(0xFFF4F3FA);
  static const Color switchInactiveTrack = Color(0xFFCFCBE6);
}

class BudgetingTheme {
  const BudgetingTheme._();

  static ThemeData get lightTheme {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryPurple,
      brightness: Brightness.light,
      primary: AppColors.primaryPurple,
      surface: AppColors.cardBackground,
    );

    final baseTextTheme = GoogleFonts.nunitoTextTheme(
      ThemeData.light().textTheme,
    ).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: AppColors.scaffoldBackground,
      dividerColor: AppColors.divider,
      textTheme: baseTextTheme.copyWith(
        headlineMedium: GoogleFonts.nunito(
          fontSize: 28,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.28,
          color: AppColors.ink,
        ),
        titleLarge: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
        titleMedium: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
        bodyLarge: GoogleFonts.nunito(
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w600,
          color: AppColors.mutedText,
        ),
        bodyMedium: GoogleFonts.nunito(
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: AppColors.mutedText,
        ),
        labelLarge: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.cardBackground,
        ),
        labelSmall: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.mutedText,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          disabledBackgroundColor: AppColors.primaryPurpleDisabled,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 54),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryPurple,
          minimumSize: const Size(48, 48),
          textStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryPurple;
          }
          return AppColors.switchInactiveTrack;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
