import 'package:flutter/material.dart';
import '../enums/shift_enums.dart';

/// Extension to get enum name as string
extension IslamicSubjectExtension on IslamicSubject {
  String get nameString {
    switch (this) {
      case IslamicSubject.quranStudies:
        return 'quran_studies';
      case IslamicSubject.hadithStudies:
        return 'hadith_studies';
      case IslamicSubject.fiqh:
        return 'fiqh';
      case IslamicSubject.arabicLanguage:
        return 'arabic_language';
      case IslamicSubject.islamicHistory:
        return 'islamic_history';
      case IslamicSubject.aqeedah:
        return 'aqeedah';
      case IslamicSubject.tafseer:
        return 'tafseer';
      case IslamicSubject.seerah:
        return 'seerah';
    }
  }
}

/// Color constants for shift blocks (ConnectTeam-inspired)
class ShiftColors {
  // Subject Colors (for teaching shifts)
  static const Map<String, Color> _subjectColors = {
    'quran_studies': Color(0xff10B981),      // Green
    'quran': Color(0xff10B981),
    'hadith_studies': Color(0xffF59E0B),     // Amber
    'hadith': Color(0xffF59E0B),
    'fiqh': Color(0xff8B5CF6),               // Purple
    'arabic_language': Color(0xff3B82F6),     // Blue
    'arabic': Color(0xff3B82F6),
    'islamic_history': Color(0xffEF4444),    // Red
    'history': Color(0xffEF4444),
    'aqeedah': Color(0xff06B6D4),            // Cyan
    'tafseer': Color(0xffEC4899),            // Pink
    'seerah': Color(0xffF97316),             // Orange
  };

  // Category Colors (for leader shifts)
  static const Map<ShiftCategory, Color> _categoryColors = {
    ShiftCategory.teaching: Color(0xff10B981),      // Green (default)
    ShiftCategory.leadership: Color(0xff6366F1),     // Indigo
    ShiftCategory.meeting: Color(0xff8B5CF6),         // Purple
    ShiftCategory.training: Color(0xff06B6D4),        // Cyan
  };

  // Status Colors
  static const Map<String, Color> _statusColors = {
    'scheduled': Color(0xff3B82F6),  // Blue
    'active': Color(0xffF59E0B),     // Amber
    'completed': Color(0xff10B981),  // Green
    'missed': Color(0xffEF4444),      // Red
    'cancelled': Color(0xff6B7280),  // Gray
  };

  /// Get color for a subject by ID, name, or enum
  static Color getSubjectColor(dynamic subjectIdentifier) {
    if (subjectIdentifier == null) {
      return const Color(0xff6B7280);
    }
    
    String key;
    if (subjectIdentifier is String) {
      key = subjectIdentifier.toLowerCase().replaceAll(' ', '_');
    } else if (subjectIdentifier is IslamicSubject) {
      // Use extension method to get proper name
      key = subjectIdentifier.nameString;
    } else {
      // Fallback to string conversion
      key = subjectIdentifier.toString().split('.').last.toLowerCase();
    }
    
    return _subjectColors[key] ?? 
           const Color(0xff6B7280); // Default gray
  }

  /// Get color for a shift category
  static Color getCategoryColor(ShiftCategory category) {
    return _categoryColors[category] ?? const Color(0xff6B7280);
  }

  /// Get color for a shift status
  static Color getStatusColor(String status) {
    return _statusColors[status.toLowerCase()] ?? const Color(0xff6B7280);
  }

  /// Get all subject colors map
  static Map<String, Color> get subjectColors => Map.unmodifiable(_subjectColors);

  /// Get all category colors map
  static Map<ShiftCategory, Color> get categoryColors => Map.unmodifiable(_categoryColors);
}

