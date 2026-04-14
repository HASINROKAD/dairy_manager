import 'package:flutter/material.dart';

import '../colors/app_color.dart';
import '../sizes/app_sizes.dart';

class AppTheme {
  const AppTheme._();

  static OutlineInputBorder _inputBorder(
    Color borderColor, {
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
      borderSide: BorderSide(color: borderColor, width: width),
    );
  }

  static InputDecorationTheme _inputDecorationTheme({
    required Color fillColor,
    required Color borderColor,
    required Color focusColor,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      border: _inputBorder(borderColor),
      enabledBorder: _inputBorder(borderColor),
      focusedBorder: _inputBorder(focusColor, width: 1.5),
    );
  }

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.lightPrimary,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      cardColor: AppColors.lightSurface,
      inputDecorationTheme: _inputDecorationTheme(
        fillColor: AppColors.lightSurface,
        borderColor: AppColors.lightBorder,
        focusColor: AppColors.lightPrimary,
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.darkPrimary,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      cardColor: AppColors.darkSurface,
      inputDecorationTheme: _inputDecorationTheme(
        fillColor: AppColors.darkSurface,
        borderColor: AppColors.darkBorder,
        focusColor: AppColors.darkPrimary,
      ),
    );
  }
}
