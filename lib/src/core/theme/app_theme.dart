import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color bronze = Color(0xFFC89A5E);
  static const Color gold = Color(0xFFE8C98D);
  static const Color deepBrown = Color(0xFF2B1E16);
  static const Color parchment = Color(0xFFF8F2E8);
  static const Color mutedText = Color(0xFF6A5D4F);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: bronze,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: parchment,
    );

    final textTheme = GoogleFonts.cormorantGaramondTextTheme(base.textTheme)
        .copyWith(
          bodyLarge: GoogleFonts.montserrat(
            fontSize: 16,
            height: 1.4,
            color: deepBrown,
          ),
          bodyMedium: GoogleFonts.montserrat(
            fontSize: 14,
            height: 1.4,
            color: deepBrown,
          ),
          titleLarge: GoogleFonts.cormorantGaramond(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: deepBrown,
          ),
          titleMedium: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: deepBrown,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: deepBrown,
        titleTextStyle: GoogleFonts.cormorantGaramond(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: deepBrown,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE4D5C0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE4D5C0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: bronze, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: deepBrown,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFECE0D0)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFFF1E3CF),
        selectedColor: gold,
        labelStyle: GoogleFonts.montserrat(color: deepBrown),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE6D7C5)),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: bronze),
      iconTheme: const IconThemeData(color: deepBrown),
    );
  }
}
