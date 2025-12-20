import 'dart:ui';

import 'package:google_fonts/google_fonts.dart';

// Text Styles
class AppTextStyles {
  static final openSansHebrew = GoogleFonts.openSans(
    color: const Color(0xff3f4648),
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
}

// Keep backward compatibility
var openSansHebrewTextStyle = AppTextStyles.openSansHebrew;

// App Colors
class AppColors {
  static const Color primaryGray = Color(0xff3f4648);
  static const Color primaryBlue = Color(0xff0386FF);
  static const Color secondaryBlue = Color(0xff0693e3);
  static const Color backgroundGray = Color(0xffF8FAFC);
  static const Color borderGray = Color(0xffE2E8F0);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
}

// App Dimensions
class AppDimensions {
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultBorderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double cardElevation = 4.0;
}
