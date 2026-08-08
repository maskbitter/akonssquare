import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static final ValueNotifier<String> appThemeNotifier = ValueNotifier<String>("Default Theme");

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedTheme = prefs.getString('app_theme');
    
    // Migration for renamed theme
    if (savedTheme == "App Theme(Normal)") {
      savedTheme = "Default Theme";
      await prefs.setString('app_theme', savedTheme);
    }
    
    appThemeNotifier.value = "Default Theme"; 
  }

  static Future<void> setTheme(String themeName) async {
    appThemeNotifier.value = "Default Theme"; 
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', "Default Theme");
  }

  static ThemeData getThemeByName(String themeName) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.light,
    ).copyWith(
      primary: Colors.indigo.shade800,
      onPrimary: Colors.white,
      primaryContainer: Colors.indigo.shade50,
      onPrimaryContainer: Colors.indigo.shade900,
      secondary: Colors.cyan.shade800,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE0F7FA), // Soft Cyan
      onSecondaryContainer: Colors.cyan.shade900,
      tertiary: const Color(0xFF2E7D32), // Success Green (Add, Update, OK, Apply)
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFE8F5E9), 
      onTertiaryContainer: const Color(0xFF1B5E20),
      error: const Color(0xFFD32F2F), // Standard Red (Remove, Close, Cancel)
      onError: Colors.white,
      errorContainer: const Color(0xFFFFEBEE), 
      onErrorContainer: const Color(0xFFB71C1C),
      surface: Colors.white,
      onSurface: Colors.indigo.shade900,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF8F9FF),
      surfaceContainer: const Color(0xFFF0F2FF),
      surfaceContainerHigh: const Color(0xFFE8EAFC),
      surfaceContainerHighest: const Color(0xFFE0E2F9),
      outline: const Color(0xFFD0D3F0),
      outlineVariant: const Color(0xFFE8EAFC),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLow,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 18, 
          fontWeight: FontWeight.bold, 
          color: colorScheme.onSurface
        ),
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: colorScheme.onSurface),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        bodyLarge: TextStyle(fontSize: 15, color: colorScheme.onSurface),
        bodyMedium: TextStyle(fontSize: 13, color: colorScheme.onSurface),
        bodySmall: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
