import 'package:flutter/material.dart';

/// Visual tokens for public site CMS (calm, system-like hierarchy).
abstract final class PublicSiteCmsTheme {
  const PublicSiteCmsTheme._();

  static const Color bg = Color(0xFFF1F4F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0x14000000);
  static const Color borderStrong = Color(0x22000000);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color accentNavy = Color(0xFF001E4E);
  static const double radiusLg = 20;
  static const double radiusMd = 14;
  static const double contentMaxW = 1200;

  static bool useSideRail(double width) => width >= 1024;

  static const Duration sectionSwitch = Duration(milliseconds: 200);
  static const Duration hoverDuration = Duration(milliseconds: 180);
}
