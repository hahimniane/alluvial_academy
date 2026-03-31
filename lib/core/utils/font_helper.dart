import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Helper class to provide consistent font styling with proper fallback
class FontHelper {
  /// Returns a TextStyle with Noto Sans and proper fallback
  /// This ensures all characters are displayed correctly
  static TextStyle notoSans({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.notoSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      // Add fallback to system fonts for missing characters
    ).copyWith(
      fontFamilyFallback: const [
        'Arial',
        'Helvetica',
        'sans-serif',
      ],
    );
  }

  /// Returns a TextStyle with Inter font (more reliable for web)
  /// Use this for primary text that needs to be consistent
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
