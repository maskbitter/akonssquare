import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeManager {
  static final ValueNotifier<String> appThemeNotifier = ValueNotifier<String>("Random Color Theme");
  static final ValueNotifier<String> appFontNotifier = ValueNotifier<String>("Poppins");
  static final ValueNotifier<Color> appOutlineBgNotifier = ValueNotifier<Color>(const Color(0xFFFAF9F6)); // Default Off-white
  static Color _sessionSeedColor = Colors.indigo;
  static List<Color> sessionColorPool = [];
  
  // MASTER BACKGROUND FOR OUTLINE THEME (Can be updated via code or UI)
  static Color get outlineBackground => appOutlineBgNotifier.value;

  static final List<Color> _niceSeeds = [
    const Color(0xFF2C3E50), // Midnight Blue
    const Color(0xFF16A085), // Green Sea
    const Color(0xFF8E44AD), // Wisteria
    const Color(0xFF2980B9), // Belize Hole
    const Color(0xFFD35400), // Pumpkin
    const Color(0xFFC0392B), // Pomegranate
    const Color(0xFF27AE60), // Nephritis
    const Color(0xFFF39C12), // Orange
    const Color(0xFFE67E22), // Carrot
    const Color(0xFF7F8C8D), // Asbestos
    Colors.indigo,
    Colors.teal,
    Colors.deepPurple,
    Colors.blueGrey,
    Colors.brown,
    Colors.deepOrange,
    Colors.blue,
    Colors.cyan,
    Colors.pink,
    Colors.purple,
    Colors.orange,
    Colors.amber,
  ];

  static List<String> get supportedFonts => [
    "Poppins",
    "Inter",
    "Montserrat",
    "Urbanist",
    "Plus Jakarta Sans",
    "Roboto",
    "Crimson Pro",
    "Hind Siliguri (Bangla)",
  ];

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedTheme = prefs.getString('app_theme');
    String? savedFont = prefs.getString('app_font');
    int? savedOutlineBg = prefs.getInt('app_outline_bg');
    
    // Choose random pool for this session
    var pool = List<Color>.from(_niceSeeds)..shuffle();
    _sessionSeedColor = pool.first;
    sessionColorPool = pool;

    appThemeNotifier.value = savedTheme ?? "Random Color Theme"; 
    appFontNotifier.value = savedFont ?? "Poppins";
    if (savedOutlineBg != null) {
      appOutlineBgNotifier.value = Color(savedOutlineBg);
    }
  }

  static Future<void> setTheme(String themeName) async {
    appThemeNotifier.value = themeName; 
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', themeName);
  }

  static Future<void> setFont(String fontName) async {
    appFontNotifier.value = fontName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_font', fontName);
  }

  static Future<void> setOutlineBgColor(Color color) async {
    appOutlineBgNotifier.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_outline_bg', color.value);
  }

  static Color getCardColor(int index, {double alpha = 1.0, bool isSubCard = false}) {
    if (appThemeNotifier.value == "Outline Theme") {
      return _sessionSeedColor.withValues(alpha: alpha);
    }
    if (appThemeNotifier.value == "Black & White Theme") {
      return (isSubCard ? Colors.grey.shade700 : Colors.black).withValues(alpha: alpha);
    }
    if (appThemeNotifier.value == "Normal Theme") {
      if (isSubCard) {
        final List<Color> colors = [
          Colors.blueGrey.shade700, 
          Colors.deepPurple.shade700, 
          Colors.teal.shade700,
          Colors.red.shade700,
          Colors.blue.shade700,
        ];
        return colors[index % colors.length].withValues(alpha: alpha);
      }
      final List<Color> colors = [Colors.indigo.shade800, Colors.cyan.shade800, const Color(0xFF2E7D32)];
      return colors[index % colors.length].withValues(alpha: alpha);
    }
    if (sessionColorPool.isEmpty) return _sessionSeedColor.withValues(alpha: alpha);
    return sessionColorPool[index % sessionColorPool.length].withValues(alpha: alpha);
  }

  static Color getCardContainerColor(int index, {double alpha = 1.0, bool isSubCard = false}) {
    if (appThemeNotifier.value == "Outline Theme") {
      return outlineBackground;
    }
    if (appThemeNotifier.value == "Black & White Theme") {
      return (isSubCard ? Colors.grey.shade200 : Colors.white).withValues(alpha: alpha);
    }
    if (appThemeNotifier.value == "Normal Theme") {
      if (isSubCard) {
        final List<Color> colors = [
          const Color(0xFFECEFF1), // BlueGrey 50
          const Color(0xFFF3E5F5), // DeepPurple 50
          const Color(0xFFE0F2F1), // Teal 50
          const Color(0xFFFFEBEE), // Red 50
          const Color(0xFFE3F2FD), // Blue 50
        ];
        return colors[index % colors.length].withValues(alpha: alpha);
      }
      final List<Color> colors = [Colors.indigo.shade50, const Color(0xFFE0F7FA), const Color(0xFFE8F5E9)];
      return colors[index % colors.length].withValues(alpha: alpha);
    }
    if (sessionColorPool.isEmpty) return _sessionSeedColor.withValues(alpha: 0.1);
    Color seed = sessionColorPool[index % sessionColorPool.length];
    return ColorScheme.fromSeed(seedColor: seed).primaryContainer.withValues(alpha: alpha);
  }

  static Color getCardOnContainerColor(int index, {bool isSubCard = false}) {
    if (appThemeNotifier.value == "Outline Theme") {
      return Colors.black;
    }
    if (appThemeNotifier.value == "Black & White Theme") {
      return isSubCard ? Colors.black : Colors.black;
    }
    if (appThemeNotifier.value == "Normal Theme") {
      if (isSubCard) {
        final List<Color> colors = [
          Colors.blueGrey.shade900, 
          Colors.deepPurple.shade900, 
          Colors.teal.shade900,
          const Color(0xFFB71C1C), // Red 900
          const Color(0xFF0D47A1), // Blue 900
        ];
        return colors[index % colors.length];
      }
      final List<Color> colors = [Colors.indigo.shade900, Colors.cyan.shade900, const Color(0xFF1B5E20)];
      return colors[index % colors.length];
    }
    if (sessionColorPool.isEmpty) return Colors.black;
    Color seed = sessionColorPool[index % sessionColorPool.length];
    return ColorScheme.fromSeed(seedColor: seed).onPrimaryContainer;
  }

  static Color getContrastColor(Color background) {
    // Calculates relative luminance to decide between white and black text
    return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  static ThemeData getThemeByName(String themeName, {String? fontName}) {
    final activeFont = fontName ?? appFontNotifier.value;
    
    ColorScheme colorScheme;
    if (themeName == "Outline Theme") {
      colorScheme = ColorScheme.fromSeed(
        seedColor: _sessionSeedColor,
        brightness: Brightness.light,
      ).copyWith(
        primary: _sessionSeedColor,
        onPrimary: Colors.black, 
        secondary: _sessionSeedColor,
        onSecondary: Colors.black,
        tertiary: _sessionSeedColor,
        onTertiary: Colors.black,
        error: _sessionSeedColor,
        onError: Colors.black,
        outline: _sessionSeedColor,
        surface: outlineBackground,
        onSurface: Colors.black,
        primaryContainer: outlineBackground,
        onPrimaryContainer: Colors.black,
        secondaryContainer: outlineBackground,
        onSecondaryContainer: Colors.black,
        tertiaryContainer: outlineBackground,
        onTertiaryContainer: Colors.black,
        errorContainer: outlineBackground,
        onErrorContainer: Colors.black,
        surfaceContainerLow: outlineBackground,
        surfaceContainerLowest: outlineBackground,
        surfaceContainer: outlineBackground,
        surfaceContainerHigh: outlineBackground,
        surfaceContainerHighest: outlineBackground,
        outlineVariant: _sessionSeedColor,
        shadow: Colors.transparent,
        scrim: Colors.transparent,
      );
    } else if (themeName == "Black & White Theme") {
      colorScheme = const ColorScheme.light(
        primary: Colors.black,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE0E0E0), // grey 300
        onPrimaryContainer: Colors.black,
        secondary: Color(0xFF424242), // grey 800
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFF5F5F5), // grey 100
        onSecondaryContainer: Colors.black,
        tertiary: Color(0xFF616161), // grey 700
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xFFEEEEEE), // grey 200
        onTertiaryContainer: Colors.black,
        error: Colors.black,
        onError: Colors.white,
        errorContainer: Color(0xFFBDBDBD), // grey 400
        onErrorContainer: Colors.black,
        surface: Colors.white,
        onSurface: Colors.black,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: Color(0xFFF5F5F5),
        surfaceContainer: Color(0xFFEEEEEE),
        surfaceContainerHigh: Color(0xFFE0E0E0),
        surfaceContainerHighest: Color(0xFFBDBDBD),
        outline: Color(0xFF757575), // grey 600
        outlineVariant: Color(0xFFEEEEEE),
        inverseSurface: Colors.black,
        onInverseSurface: Colors.white,
        inversePrimary: Color(0xFFBDBDBD),
      );
    } else if (themeName == "Normal Theme") {
      colorScheme = ColorScheme.fromSeed(
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
        tertiary: const Color(0xFF2E7D32), // Success Green
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFFE8F5E9), 
        onTertiaryContainer: const Color(0xFF1B5E20),
        error: const Color(0xFFD32F2F), // Standard Red
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
        inverseSurface: Colors.indigo.shade900,
        onInverseSurface: Colors.indigo.shade50,
        inversePrimary: Colors.indigo.shade200,
        scrim: Colors.black,
        shadow: Colors.black,
      );
    } else {
      colorScheme = ColorScheme.fromSeed(
        seedColor: _sessionSeedColor,
        brightness: Brightness.light,
      );
    }

    final TextTheme baseTextTheme = _getTextTheme(activeFont, colorScheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: themeName == "Outline Theme" ? outlineBackground : colorScheme.surfaceContainerLow,
      textTheme: baseTextTheme,
      extensions: [
        AppColors(
          success: themeName == "Black & White Theme" ? Colors.black : const Color(0xFF2E7D32),
          onSuccess: outlineBackground,
          warning: themeName == "Black & White Theme" ? const Color(0xFF424242) : const Color(0xFFF57C00),
          onWarning: outlineBackground,
          info: themeName == "Black & White Theme" ? const Color(0xFF616161) : const Color(0xFF0288D1),
          onInfo: outlineBackground,
          active: themeName == "Black & White Theme" ? Colors.black : const Color(0xFF4CAF50),
          inactive: const Color(0xFF9E9E9E),
          pending: themeName == "Black & White Theme" ? const Color(0xFF757575) : const Color(0xFFFFA000),
          gold: themeName == "Black & White Theme" ? const Color(0xFF424242) : const Color(0xFFFFD700),
          silver: const Color(0xFFC0C0C0),
          bronze: themeName == "Black & White Theme" ? const Color(0xFF757575) : const Color(0xFFCD7F32),
          premium: themeName == "Black & White Theme" ? Colors.black : const Color(0xFF673AB7),
          verified: themeName == "Black & White Theme" ? Colors.black : const Color(0xFF2196F3),
          electric: themeName == "Normal Theme" ? const Color(0xFFE65100) : (themeName == "Black & White Theme" ? Colors.black : colorScheme.secondary),
        ),
      ],
      cardTheme: CardThemeData(
        color: themeName == "Outline Theme" ? outlineBackground : colorScheme.surface,
        elevation: themeName == "Outline Theme" ? 0 : 1,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: themeName == "Outline Theme" 
              ? BorderSide(color: colorScheme.primary, width: 1.5) 
              : BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: themeName == "Outline Theme" ? 0 : 2,
          backgroundColor: themeName == "Outline Theme" ? outlineBackground : null,
          foregroundColor: themeName == "Outline Theme" ? colorScheme.primary : null,
          side: themeName == "Outline Theme" ? BorderSide(color: colorScheme.primary, width: 1.5) : null,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: themeName == "Outline Theme" ? 0 : 2,
          side: BorderSide(color: colorScheme.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: themeName == "Outline Theme" ? outlineBackground : colorScheme.surfaceContainerHighest.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: themeName == "Outline Theme" ? BorderSide(color: colorScheme.primary, width: 1.5) : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: themeName == "Outline Theme" ? BorderSide(color: colorScheme.primary, width: 1) : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: themeName == "Outline Theme" ? outlineBackground : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), 
          side: themeName == "Outline Theme" ? BorderSide(color: colorScheme.primary, width: 1.5) : BorderSide.none,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: baseTextTheme.titleLarge,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: themeName == "Outline Theme" ? Colors.black : colorScheme.primary,
        unselectedLabelColor: themeName == "Outline Theme" ? Colors.black : colorScheme.onSurface.withOpacity(0.6),
        indicatorColor: themeName == "Outline Theme" ? Colors.black : colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: themeName == "Outline Theme" ? outlineBackground : colorScheme.primary,
        foregroundColor: themeName == "Outline Theme" ? colorScheme.primary : colorScheme.onPrimary,
        elevation: themeName == "Outline Theme" ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: themeName == "Outline Theme" ? BorderSide(color: colorScheme.primary, width: 2) : BorderSide.none,
        ),
      ),
    );
  }

  static TextTheme _getTextTheme(String fontName, Color onSurface) {
    bool isOutline = appThemeNotifier.value == "Outline Theme";

    TextTheme base;
    switch (fontName) {
      case "Inter": base = GoogleFonts.interTextTheme(); break;
      case "Montserrat": base = GoogleFonts.montserratTextTheme(); break;
      case "Urbanist": base = GoogleFonts.urbanistTextTheme(); break;
      case "Plus Jakarta Sans": base = GoogleFonts.plusJakartaSansTextTheme(); break;
      case "Roboto": base = GoogleFonts.robotoTextTheme(); break;
      case "Crimson Pro": base = GoogleFonts.crimsonProTextTheme(); break;
      case "Hind Siliguri (Bangla)": base = GoogleFonts.hindSiliguriTextTheme(); break;
      default: base = GoogleFonts.poppinsTextTheme();
    }

    return base.copyWith(
      headlineMedium: base.headlineMedium?.copyWith(fontSize: 26, fontWeight: FontWeight.w900, color: isOutline ? Colors.black : onSurface),
      titleLarge: base.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: isOutline ? Colors.black : onSurface),
      titleMedium: base.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: isOutline ? Colors.black : onSurface),
      titleSmall: base.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: isOutline ? Colors.black : onSurface),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 15, color: isOutline ? Colors.black : onSurface),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 13, color: isOutline ? Colors.black : onSurface),
      bodySmall: base.bodySmall?.copyWith(fontSize: 12, color: isOutline ? Colors.black : onSurface),
      labelSmall: base.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: isOutline ? Colors.black : onSurface),
    );
  }
}

/// Custom Color Categories via ThemeExtension
class AppColors extends ThemeExtension<AppColors> {
  final Color? success;
  final Color? onSuccess;
  final Color? warning;
  final Color? onWarning;
  final Color? info;
  final Color? onInfo;
  final Color? active;
  final Color? inactive;
  final Color? pending;
  final Color? gold;
  final Color? silver;
  final Color? bronze;
  final Color? premium;
  final Color? verified;
  final Color? electric;

  AppColors({
    this.success,
    this.onSuccess,
    this.warning,
    this.onWarning,
    this.info,
    this.onInfo,
    this.active,
    this.inactive,
    this.pending,
    this.gold,
    this.silver,
    this.bronze,
    this.premium,
    this.verified,
    this.electric,
  });

  @override
  AppColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? info,
    Color? onInfo,
    Color? active,
    Color? inactive,
    Color? pending,
    Color? gold,
    Color? silver,
    Color? bronze,
    Color? premium,
    Color? verified,
    Color? electric,
  }) {
    return AppColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      active: active ?? this.active,
      inactive: inactive ?? this.inactive,
      pending: pending ?? this.pending,
      gold: gold ?? this.gold,
      silver: silver ?? this.silver,
      bronze: bronze ?? this.bronze,
      premium: premium ?? this.premium,
      verified: verified ?? this.verified,
      electric: electric ?? this.electric,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t),
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t),
      warning: Color.lerp(warning, other.warning, t),
      onWarning: Color.lerp(onWarning, other.onWarning, t),
      info: Color.lerp(info, other.info, t),
      onInfo: Color.lerp(onInfo, other.onInfo, t),
      active: Color.lerp(active, other.active, t),
      inactive: Color.lerp(inactive, other.inactive, t),
      pending: Color.lerp(pending, other.pending, t),
      gold: Color.lerp(gold, other.gold, t),
      silver: Color.lerp(silver, other.silver, t),
      bronze: Color.lerp(bronze, other.bronze, t),
      premium: Color.lerp(premium, other.premium, t),
      verified: Color.lerp(verified, other.verified, t),
      electric: Color.lerp(electric, other.electric, t),
    );
  }
}

/// Shortcut extensions for easy access
extension AppThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  AppColors get appColors => theme.extension<AppColors>()!;

  // Basic shortcuts
  Color get primary => colorScheme.primary;
  Color get onPrimary => colorScheme.onPrimary;
  Color get secondary => colorScheme.secondary;
  Color get onSecondary => colorScheme.onSecondary;
  Color get tertiary => colorScheme.tertiary;
  Color get onTertiary => colorScheme.onTertiary;
  Color get error => colorScheme.error;
  Color get surface => colorScheme.surface;
  Color get onSurface => colorScheme.onSurface;
  Color get outline => colorScheme.outline;

  // Custom shortcuts
  Color get success => appColors.success!;
  Color get warning => appColors.warning!;
  Color get info => appColors.info!;
  Color get active => appColors.active!;
  Color get inactive => appColors.inactive!;
  Color get pending => appColors.pending!;
  Color get gold => appColors.gold!;
  Color get premium => appColors.premium!;
  Color get electric => appColors.electric!;
}
