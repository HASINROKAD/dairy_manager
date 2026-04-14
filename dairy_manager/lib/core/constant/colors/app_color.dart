import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color lightPrimary = Color(0xFF1565C0);
  static const Color lightSecondary = Color(0xFF00897B);
  static const Color lightBackground = Color(0xFFF6F8FB);
  static const Color lightSurface = Colors.white;
  static const Color lightTextPrimary = Color(0xFF102A43);
  static const Color lightTextSecondary = Color(0xFF486581);
  static const Color lightBorder = Color(0xFFD9E2EC);

  static const Color darkPrimary = Color(0xFF90CAF9);
  static const Color darkSecondary = Color(0xFF80CBC4);
  static const Color darkBackground = Color(0xFF0F1720);
  static const Color darkSurface = Color(0xFF1C2530);
  static const Color darkTextPrimary = Color(0xFFE7EDF4);
  static const Color darkTextSecondary = Color(0xFFAAB7C4);
  static const Color darkBorder = Color(0xFF2F3B47);

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);
  static const Color danger = Color(0xFFD32F2F);

  static Color surface(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color background(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackground : lightBackground;

  static Color border(Brightness brightness) =>
      brightness == Brightness.dark ? darkBorder : lightBorder;

  static Color textPrimary(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;

  static Color textSecondary(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;
}
