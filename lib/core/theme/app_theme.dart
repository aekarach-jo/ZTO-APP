import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primaryOrange = Color(0xFFE66A1F);
  static const Color darkText = Color(0xFF1C1C1C);
  static const Color lightBackground = Color(0xFFF7F7F9);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryOrange,
        primary: primaryOrange,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryOrange),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: darkText,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: darkText),
      ),
    );
  }
}

