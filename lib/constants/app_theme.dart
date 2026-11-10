import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primaryTeal,
      scaffoldBackgroundColor: AppColors.lightCreamBackground,
      colorScheme: ColorScheme.light(
        primary: AppColors.primaryTeal,
        onPrimary: AppColors.white,
        primaryContainer: AppColors.primaryTealLight,
        onPrimaryContainer: AppColors.primaryTealDark,
        secondary: AppColors.warmBeige,
        onSecondary: AppColors.textDark,
        secondaryContainer: AppColors.warmBeigeLight,
        tertiary: AppColors.terracottaBrown,
        onTertiary: AppColors.white,
        tertiaryContainer: AppColors.terracottaLight,
        surface: AppColors.white,
        onSurface: AppColors.textDark,
        outline: AppColors.cardBorder,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          color: AppColors.textDark,
          fontWeight: FontWeight.w800,
        ),
        headlineLarge: textTheme.headlineLarge?.copyWith(
          color: AppColors.textDark,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: textTheme.titleSmall?.copyWith(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: AppColors.textBody,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: AppColors.textBody,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightCreamBackground,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryTeal,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryTealDark,
          side: const BorderSide(color: AppColors.primaryTeal, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.primaryTeal,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}
