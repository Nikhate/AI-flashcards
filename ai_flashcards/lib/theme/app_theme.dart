import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const bg = Color(0xFF0F0E17);
  static const cardBg = Color(0xFF1A1928);
  static const cardBorder = Color(0xFF2D2B45);
  static const muted = Color(0xFFA7A9BE);
  static const accent = Color(0xFF6C63FF);
  static const accentPink = Color(0xFFFF6584);
  static const success = Color(0xFF4ADE80);
  static const successBg = Color(0xFF12221A);
  static const successBorder = Color(0xFF1D6340);
  static const danger = Color(0xFFF87171);
  static const dangerBg = Color(0xFF22121A);
  static const dangerBorder = Color(0xFF63201D);

  static const gradient = LinearGradient(
    colors: [accent, accentPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accentPink,
          surface: AppColors.cardBg,
        ),
        dividerColor: AppColors.cardBorder,
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.accent,
          linearTrackColor: AppColors.cardBorder,
        ),
      );
}
