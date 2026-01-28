import 'package:flutter/services.dart';
import 'package:flutter_beep/flutter_beep.dart';

/// Service for playing quiz sound effects using system sounds
class QuizAudioService {
  static final QuizAudioService _instance = QuizAudioService._internal();
  factory QuizAudioService() => _instance;
  QuizAudioService._internal();

  bool _initialized = false;

  /// Initialize audio service
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// Play sound for correct answer - success beep
  Future<void> playCorrectSound() async {
    try {
      // Play success beep sound
      await FlutterBeep.beep(); // Default success sound
      await HapticFeedback.mediumImpact();
    } catch (e) {
      // Fallback to haptic only
      await HapticFeedback.mediumImpact();
    }
  }

  /// Play sound for wrong answer - error beep
  Future<void> playWrongSound() async {
    try {
      // Play error/failure beep sound
      await FlutterBeep.beep(false); // false = error sound
      await HapticFeedback.heavyImpact();
    } catch (e) {
      // Fallback to haptic only
      await HapticFeedback.heavyImpact();
    }
  }

  /// Play cheerful celebration sound at quiz completion
  Future<void> playCelebrationSound() async {
    try {
      // Play multiple success beeps for celebration effect
      await FlutterBeep.beep();
      await HapticFeedback.heavyImpact();
      
      await Future.delayed(const Duration(milliseconds: 150));
      await FlutterBeep.beep();
      await HapticFeedback.mediumImpact();
      
      await Future.delayed(const Duration(milliseconds: 150));
      await FlutterBeep.beep();
      await HapticFeedback.lightImpact();
      
      await Future.delayed(const Duration(milliseconds: 150));
      // Final triumphant beep
      await FlutterBeep.playSysSound(1025); // iOS payment success sound
      await HapticFeedback.heavyImpact();
    } catch (e) {
      // Fallback to haptic pattern
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
    }
  }

  /// Dispose - nothing to dispose for FlutterBeep
  Future<void> dispose() async {
    _initialized = false;
  }
}
