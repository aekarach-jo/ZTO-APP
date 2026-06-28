import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color brandBlue = Color(0xFF1D78DF);
  static const Color brandBlueDark = Color(0xFF0E58B9);
  static const Color brandBlueLight = Color(0xFF54B7FF);
  static const Color softBlue = Color(0xFFEAF5FF);
  static const Color borderBlue = Color(0xFFD4E7FF);
  static const Color darkText = Color(0xFF14304B);
  static const Color lightBackground = Color(0xFFF4FAFF);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandBlue,
        primary: brandBlue,
        brightness: Brightness.light,
        secondary: brandBlueLight,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: darkText,
        surfaceTintColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7FBFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandBlue),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF9FC9F7),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandBlueDark,
          side: const BorderSide(color: borderBlue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brandBlue,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: darkText, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: darkText),
      ),
    );
  }
}
