import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color secondaryColor = Color(0xFF8B5CF6);
  static const Color emergencyColor = Color(0xFFFF6B6B);
  static const Color backgroundColor = Color(0xFFFAFAFA);
  static const Color textColor = Color(0xFF1F2937);
  static const Color secondaryTextColor = Color(0xFF6B7280);
  static const Color successColor = Color(0xFF10B981);
  static const Color whiteColor = Color(0xFFFFFFFF);
  static const Color blackColor = Color(0xFF000000);
  static const Color grayColor = Color(0xFF9CA3AF);
  static const Color lightGrayColor = Color(0xFFF3F4F6);
  
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;
  
  static const double borderRadiusSm = 8.0;
  static const double borderRadiusMd = 12.0;
  static const double borderRadiusLg = 16.0;
  static const double borderRadiusXl = 24.0;
  static const double borderRadiusFull = 100.0;
  
  static const double elevationSm = 2.0;
  static const double elevationMd = 4.0;
  static const double elevationLg = 8.0;
  static const double elevationXl = 16.0;
  
  static TextStyle get headlineLarge => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 32.0,
        fontWeight: FontWeight.bold,
        color: textColor,
      );
      
  static TextStyle get headlineMedium => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 24.0,
        fontWeight: FontWeight.bold,
        color: textColor,
      );
      
  static TextStyle get headlineSmall => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 20.0,
        fontWeight: FontWeight.bold,
        color: textColor,
      );
      
  static TextStyle get bodyLarge => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16.0,
        fontWeight: FontWeight.normal,
        color: textColor,
      );
      
  static TextStyle get bodyMedium => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14.0,
        fontWeight: FontWeight.normal,
        color: textColor,
      );
      
  static TextStyle get bodySmall => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12.0,
        fontWeight: FontWeight.normal,
        color: secondaryTextColor,
      );
      
  static TextStyle get labelLarge => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
        color: whiteColor,
      );
      
  static TextStyle get labelMedium => const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        color: whiteColor,
      );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      error: emergencyColor,
      surface: whiteColor,
      onPrimary: whiteColor,
      onSecondary: whiteColor,
      onError: whiteColor,
      onSurface: textColor,
    ),
    textTheme: TextTheme(
      headlineLarge: headlineLarge,
      headlineMedium: headlineMedium,
      headlineSmall: headlineSmall,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
      labelMedium: labelMedium,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: whiteColor,
        textStyle: labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingMd),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadiusMd)),
        elevation: elevationSm,
      ),
    ),
    cardTheme: CardThemeData(
      color: whiteColor,
      elevation: elevationSm,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadiusLg)),
      margin: const EdgeInsets.all(spacingSm),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: whiteColor,
      foregroundColor: textColor,
      elevation: elevationSm,
      centerTitle: true,
      titleTextStyle: headlineSmall,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: whiteColor,
      selectedItemColor: primaryColor,
      unselectedItemColor: secondaryTextColor,
      elevation: elevationMd,
      type: BottomNavigationBarType.fixed,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: const Color(0xFF111827),
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      error: emergencyColor,
      surface: const Color(0xFF1F2937),
      onPrimary: whiteColor,
      onSecondary: whiteColor,
      onError: whiteColor,
      onSurface: whiteColor,
    ),
  );
}
