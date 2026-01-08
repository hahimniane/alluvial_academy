import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class EnvironmentUtils {
  static String? get projectId {
    try {
      if (Firebase.apps.isEmpty) return null;
      return Firebase.app().options.projectId;
    } catch (_) {
      return null;
    }
  }

  static bool get isDevelopment {
    final id = projectId?.trim().toLowerCase();
    if (id == null || id.isEmpty) {
      return !kReleaseMode;
    }

    if (id == 'alluwal-dev' || id.contains('alluwal-dev') || id.endsWith('-dev')) {
      return true;
    }

    // Fallback for local/emulator style project IDs (should never match prod).
    if (id.contains('demo') || id.contains('emulator')) {
      return true;
    }

    return false;
  }
}

