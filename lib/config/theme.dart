import 'package:flutter/material.dart';

class AppThemes {
  /// Colors from Tailwind CSS
  ///
  /// https://tailwindcss.com/docs/customizing-colors

  static const int _primaryColor = 0xFF15151B;
  static const int _secondaryColor = 0xFF2E2E2E;
  static const MaterialColor primarySwatch =
      MaterialColor(_primaryColor, <int, Color>{
    50: Color(0xFFECEDFD),
    100: Color(0xFFD0D1FB),
    200: Color(0xFFB1B3F8),
    300: Color(_secondaryColor),
    400: Color(0xFF7A7DF3),
    500: Color(_primaryColor),
    600: Color(0xFF5B5EEF),
    700: Color(0xFF5153ED),
    800: Color(0xFF4749EB),
    900: Color(0xFF3538E7),
  });

  static const int _textColor = 0xFF6B7280;
  static const MaterialColor textSwatch =
      MaterialColor(_textColor, <int, Color>{
    50: Color(0xFFF9FAFB),
    100: Color(0xFFF3F4F6),
    200: Color(0xFFE5E7EB),
    300: Color(0xFFD1D5DB),
    400: Color(0xFF9CA3AF),
    500: Color(_textColor),
    600: Color(0xFF4B5563),
    700: Color(0xFF374151),
    800: Color(0xFF1F2937),
    900: Color(0xFF111827),
  });

  static final lightTheme = ThemeData(
    primaryColorLight: const Color(_secondaryColor),
    brightness: Brightness.light,
    scaffoldBackgroundColor: textSwatch.shade100,
    colorSchemeSeed: const Color(0xFF46414E),
    cardColor: const Color(0xFF46414E),
    dividerColor: const Color(0x1C000000),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF2E2E2E),
      unselectedLabelStyle: TextStyle(
        color: Color(0xFFEFEFEF),
      ),
      selectedLabelStyle: TextStyle(
        color: Color(0xFFEFEFEF),
      ),
    ),
    // drawerTheme: DrawerThemeData(
    //   backgroundColor: Colors.black,
    //   scrimColor: Colors.black38,
    // ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: textSwatch.shade700,
        fontWeight: FontWeight.w300,
      ),
      displayMedium: TextStyle(
        color: textSwatch.shade600,
      ),
      displaySmall: TextStyle(
        color: textSwatch.shade700,
      ),
      headlineMedium: TextStyle(
        color: textSwatch.shade700,
      ),
      headlineSmall: TextStyle(
        color: textSwatch.shade600,
      ),
      titleLarge: TextStyle(
        color: textSwatch.shade700,
      ),
      titleMedium: TextStyle(
        color: textSwatch.shade700,
      ),
      titleSmall: TextStyle(
        color: textSwatch.shade600,
      ),
      bodyLarge: TextStyle(
        color: textSwatch.shade700,
      ),
      bodyMedium: TextStyle(
        color: textSwatch.shade500,
      ),
      labelLarge: TextStyle(
        color: textSwatch.shade500,
      ),
      bodySmall: TextStyle(
        color: textSwatch.shade500,
      ),
      labelSmall: TextStyle(
        color: textSwatch.shade500,
      ),
    ),
    bottomAppBarTheme: const BottomAppBarThemeData(color: Colors.white),
    colorScheme: ColorScheme.fromSwatch(primarySwatch: primarySwatch)
        .copyWith(background: textSwatch.shade100),
  );

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF24242a),
    cardColor: const Color(0xFF2f2f34),
    dividerColor: const Color(0x1CFFFFFF),
    iconTheme: const IconThemeData(color: Colors.white),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Color(0xFF24242a),
      // scrimColor: Colors.white,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: textSwatch.shade200,
        fontWeight: FontWeight.w300,
      ),
      displayMedium: TextStyle(
        color: textSwatch.shade300,
      ),
      displaySmall: TextStyle(
        color: textSwatch.shade200,
      ),
      headlineMedium: TextStyle(
        color: textSwatch.shade200,
      ),
      headlineSmall: TextStyle(
        color: textSwatch.shade300,
      ),
      titleLarge: TextStyle(
        color: textSwatch.shade200,
      ),
      titleMedium: TextStyle(
        color: textSwatch.shade200,
      ),
      titleSmall: TextStyle(
        color: textSwatch.shade300,
      ),
      bodyLarge: TextStyle(
        color: textSwatch.shade300,
      ),
      bodyMedium: TextStyle(
        color: textSwatch.shade200,
      ),
      labelLarge: TextStyle(
        color: textSwatch.shade400,
      ),
      bodySmall: TextStyle(
        color: textSwatch.shade400,
      ),
      labelSmall: TextStyle(
        color: textSwatch.shade400,
      ),
    ),
    bottomAppBarTheme: const BottomAppBarThemeData(color: Color(0xFF35353a)),
  );
}
