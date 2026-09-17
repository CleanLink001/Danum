import 'package:flutter/material.dart';

class AppTheme {
  // Deep Ocean Dark Palette
  static const Color scaffoldDark = Color(0xFF0B1329); // Midnight Ocean Navy
  static const Color cardBgDark = Color(0xFF132238);   // Ocean Slate Blue Card
  static const Color primaryDark = Color(0xFF38BDF8);  // Electric Sky Hydro Blue
  static const Color accentCyanDark = Color(0xFF22D3EE);
  static const Color textMainDark = Color(0xFFF8FAFC);
  static const Color textMutedDark = Color(0xFF94A3B8);

  // Soft Water Light Palette (Refreshing Ice Aqua Blue)
  static const Color scaffoldLight = Color(0xFFE0F2FE); // Soft Water Ice Blue (Replaces stark white)
  static const Color cardBgLight = Colors.white;         // Pure White Cards
  static const Color primaryLight = Color(0xFF0284C7);   // Hydro Ocean Blue
  static const Color accentCyanLight = Color(0xFF06B6D4);
  static const Color textMainLight = Color(0xFF0F172A);  // Crisp Dark Water Navy
  static const Color textMutedLight = Color(0xFF475569); // Slate Blue Subtitle

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: scaffoldLight,
      primaryColor: primaryLight,
      colorScheme: const ColorScheme.light(
        primary: primaryLight,
        secondary: accentCyanLight,
        surface: cardBgLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldLight,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textMainLight),
        titleTextStyle: TextStyle(
          color: textMainLight,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBgLight,
        elevation: 2,
        shadowColor: primaryLight.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFBAE6FD), width: 1),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: textMainLight, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        bodyLarge: TextStyle(color: textMainLight),
        bodyMedium: TextStyle(color: textMutedLight),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryLight,
        unselectedItemColor: Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffoldDark,
      primaryColor: primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryDark,
        secondary: accentCyanDark,
        surface: cardBgDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textMainDark),
        titleTextStyle: TextStyle(
          color: textMainDark,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBgDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: textMainDark, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        bodyLarge: TextStyle(color: textMainDark),
        bodyMedium: TextStyle(color: textMutedDark),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: scaffoldDark,
        selectedItemColor: primaryDark,
        unselectedItemColor: Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
