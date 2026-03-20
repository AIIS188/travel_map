import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF667EEA);
  static const Color primaryDark = Color(0xFF764BA2);
  static const Color accent = Color(0xFFFF6B9D);
  static const Color green = Color(0xFF34D399);
  static const Color amber = Color(0xFFFBBF24);
  static const Color purple = Color(0xFF7C3AED);
  static const Color lightBlue = Color(0xFF7DD3FC);
  static const Color bg = Color(0xFF1A1A2E);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        fontFamily: 'sans-serif',
      );
}
