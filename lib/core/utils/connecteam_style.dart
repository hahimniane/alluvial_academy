import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Connecteam Design System
/// Clean enterprise aesthetic with high data density and spreadsheet-like grid system
class ConnecteamStyle {
  // Colors
  static const Color primaryBlue = Color(0xff2998FF);
  static const Color background = Color(0xffF3F5F7);
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xff333333);
  static const Color textGrey = Color(0xff6B7280);
  static const Color borderColor = Color(0xffE4E7EB);
  static const Color hoverColor = Color(0xffF9FAFB);

  // Status Colors (Pastel backgrounds, strong text)
  static const Color statusDoneBg = Color(0xffE6F8EF);
  static const Color statusDoneText = Color(0xff00C875);
  static const Color statusProgressBg = Color(0xffFDF3E6);
  static const Color statusProgressText = Color(0xffFDAB3D);
  static const Color statusTodoBg = Color(0xffEBEDF0);
  static const Color statusTodoText = Color(0xff676879);

  // Text Styles
  static TextStyle headerTitle = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textDark,
    letterSpacing: -0.5,
  );

  static TextStyle tableHeader = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textGrey,
    letterSpacing: 0.5,
  );

  static TextStyle cellText = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textDark,
  );

  // Components
  static BoxDecoration containerShadow = BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: borderColor),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.02),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

