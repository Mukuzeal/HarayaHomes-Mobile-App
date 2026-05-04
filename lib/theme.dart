import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HarayaColors {
  static const Color primary = Color(0xFF5682B1);
  static const Color primaryLight = Color(0xFF739EC9);
  static const Color headerBg = Color(0xFFFFE8DB);
  static const Color background = Color(0xFFFFFFFF);
  static const Color sectionBg = Color(0xFFF6F9F6);
  static const Color textDark = Color(0xFF222831);
  static const Color textBody = Color(0xFF151111);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
}

ThemeData harayaTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: HarayaColors.primary,
      primary: HarayaColors.primary,
      secondary: HarayaColors.primaryLight,
      background: HarayaColors.background,
      error: HarayaColors.error,
    ),
    scaffoldBackgroundColor: HarayaColors.background,
    textTheme: GoogleFonts.poppinsTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: HarayaColors.headerBg,
      foregroundColor: HarayaColors.textDark,
      elevation: 4,
      shadowColor: Colors.black38,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: HarayaColors.textDark,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HarayaColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        elevation: 3,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: HarayaColors.primary,
        side: const BorderSide(color: HarayaColors.primary, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF5F8FF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCDD9E8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCDD9E8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HarayaColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HarayaColors.error),
      ),
      labelStyle: GoogleFonts.poppins(color: const Color(0xFF666666)),
      hintStyle: GoogleFonts.poppins(color: const Color(0xFFAAAAAA)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 4,
      shadowColor: const Color(0x22000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    useMaterial3: true,
  );
}
