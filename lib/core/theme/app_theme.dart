import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App theme definitions for light and dark modes
class AppTheme {
  // Light Theme Colors
  static const Color _lightPrimary = Color(0xff0386FF);
  static const Color _lightSecondary = Color(0xff0693e3);
  static const Color _lightBackground = Color(0xffF8FAFC);
  static const Color _lightSurface = Colors.white;
  static const Color _lightTextPrimary = Color(0xff111827);
  static const Color _lightTextSecondary = Color(0xff6B7280);
  
  // Dark Theme Colors
  static const Color _darkPrimary = Color(0xff0386FF);
  static const Color _darkSecondary = Color(0xff0693e3);
  static const Color _darkBackground = Color(0xff0F172A);
  static const Color _darkSurface = Color(0xff1E293B);
  static const Color _darkTextPrimary = Color(0xffF8FAFC);
  static const Color _darkTextSecondary = Color(0xff94A3B8);
  
  /// Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _lightBackground,
    canvasColor: _lightBackground,
    
    // Color Scheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: _lightPrimary,
      primary: _lightPrimary,
      secondary: _lightSecondary,
      background: _lightBackground,
      surface: _lightSurface,
      brightness: Brightness.light,
    ),
    
    // App Bar Theme
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: _lightSurface,
      foregroundColor: _lightTextPrimary,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _lightTextPrimary,
      ),
      iconTheme: const IconThemeData(color: _lightTextPrimary),
    ),
    
    // Text Theme
    textTheme: GoogleFonts.interTextTheme().apply(
      bodyColor: _lightTextPrimary,
      displayColor: _lightTextPrimary,
    ),
    
    // Card Theme
    cardTheme: CardThemeData(
      color: _lightSurface,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    
    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightSurface,
      hoverColor: Colors.transparent,
      focusColor: _lightPrimary.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xffE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xffE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _lightPrimary, width: 2),
      ),
    ),
    
    // Popup Menu Theme
    popupMenuTheme: PopupMenuThemeData(
      color: _lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xffE2E8F0), width: 1),
      ),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.1),
      textStyle: GoogleFonts.inter(
        fontSize: 14,
        color: _lightTextPrimary,
      ),
    ),
    
    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _lightSurface,
      selectedItemColor: _lightPrimary,
      unselectedItemColor: _lightTextSecondary,
      elevation: 8,
    ),
    
    // Divider Theme
    dividerTheme: const DividerThemeData(
      color: Color(0xffE5E7EB),
      thickness: 1,
    ),
    
    // Icon Theme
    iconTheme: const IconThemeData(
      color: _lightTextSecondary,
    ),
  );
  
  /// Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _darkBackground,
    canvasColor: _darkBackground,
    
    // Color Scheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: _darkPrimary,
      primary: _darkPrimary,
      secondary: _darkSecondary,
      background: _darkBackground,
      surface: _darkSurface,
      brightness: Brightness.dark,
    ),
    
    // App Bar Theme
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: _darkSurface,
      foregroundColor: _darkTextPrimary,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _darkTextPrimary,
      ),
      iconTheme: const IconThemeData(color: _darkTextPrimary),
    ),
    
    // Text Theme
    textTheme: GoogleFonts.interTextTheme().apply(
      bodyColor: _darkTextPrimary,
      displayColor: _darkTextPrimary,
    ),
    
    // Card Theme
    cardTheme: CardThemeData(
      color: _darkSurface,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    
    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkSurface,
      hoverColor: Colors.transparent,
      focusColor: _darkPrimary.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xff334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xff334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _darkPrimary, width: 2),
      ),
    ),
    
    // Popup Menu Theme
    popupMenuTheme: PopupMenuThemeData(
      color: _darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xff334155), width: 1),
      ),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.3),
      textStyle: GoogleFonts.inter(
        fontSize: 14,
        color: _darkTextPrimary,
      ),
    ),
    
    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _darkSurface,
      selectedItemColor: _darkPrimary,
      unselectedItemColor: _darkTextSecondary,
      elevation: 8,
    ),
    
    // Divider Theme
    dividerTheme: const DividerThemeData(
      color: Color(0xff334155),
      thickness: 1,
    ),
    
    // Icon Theme
    iconTheme: const IconThemeData(
      color: _darkTextSecondary,
    ),
  );
}

/// Extension methods for easier access to theme colors
extension AppThemeExtension on BuildContext {
  /// Get the current color scheme
  ColorScheme get colors => Theme.of(this).colorScheme;
  
  /// Get primary color
  Color get primaryColor => Theme.of(this).primaryColor;
  
  /// Get background color
  Color get backgroundColor => Theme.of(this).scaffoldBackgroundColor;
  
  /// Get surface color (for cards, sheets, etc)
  Color get surfaceColor => Theme.of(this).cardColor;
  
  /// Get primary text color
  Color get textPrimary => Theme.of(this).textTheme.bodyLarge?.color ?? 
    (Theme.of(this).brightness == Brightness.dark 
      ? const Color(0xffF8FAFC) 
      : const Color(0xff111827));
  
  /// Get secondary text color
  Color get textSecondary => Theme.of(this).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? 
    (Theme.of(this).brightness == Brightness.dark 
      ? const Color(0xff94A3B8) 
      : const Color(0xff6B7280));
  
  /// Get border color
  Color get borderColor => Theme.of(this).dividerColor;
  
  /// Check if dark mode is active
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

