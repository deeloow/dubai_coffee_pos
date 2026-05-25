import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color gold = Color(0xFFC9922A);
  static const Color goldLight = Color(0xFFF5D78E);
  static const Color goldDark = Color(0xFF8B6010);
  static const Color espresso = Color(0xFF2C1A0E);
  static const Color brown = Color(0xFF5C3317);
  static const Color brown2 = Color(0xFF7A4A20);
  static const Color cream = Color(0xFFFBF5E6);
  static const Color sand = Color(0xFFEFD9A8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color red = Color(0xFFD85A30);
  static const Color green = Color(0xFF3B6D11);
  static const Color darkBrown = Color(0xFF3D2614);
  static const Color borderColor = Color(0xFFD5C4A0);
  static const Color textMuted = Color(0xFFA9937A);
  static const Color textBrown = Color(0xFF7A6A52);
  static const Color bgLight = Color(0xFFF7F2E8);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.gold,
        primary: AppColors.gold,
        secondary: AppColors.espresso,
        surface: AppColors.white,
        background: AppColors.cream,
      ),
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: GoogleFonts.dmSansTextTheme().copyWith(
        displayLarge: GoogleFonts.dmSans(
            color: AppColors.espresso, fontWeight: FontWeight.bold),
        bodyMedium:
            GoogleFonts.dmSans(color: AppColors.espresso, fontSize: 13),
        bodySmall:
            GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.espresso,
        foregroundColor: AppColors.goldLight,
        titleTextStyle: GoogleFonts.dmSans(
          color: AppColors.goldLight,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.goldLight),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelStyle:
            GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 13),
        hintStyle:
            GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.espresso,
          foregroundColor: AppColors.goldLight,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle:
              GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.borderColor, width: 0.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.espresso,
        selectedItemColor: AppColors.goldLight,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgLight,
        selectedColor: AppColors.gold,
        labelStyle: GoogleFonts.dmSans(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dividerColor: AppColors.borderColor,
    );
  }
}
