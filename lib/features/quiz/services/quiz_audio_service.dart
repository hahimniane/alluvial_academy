import 'package:flutter/services.dart';

/// Service for playing quiz sound effects using haptic feedback
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

  /// Play sound for correct answer - success haptic
  Future<void> playCorrectSound() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      // Ignore errors
    }
  }

  /// Play sound for wrong answer - error haptic
  Future<void> playWrongSound() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      // Ignore errors
    }
  }

  /// Play cheerful celebration pattern at quiz completion
  Future<void> playCelebrationSound() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      // Ignore errors
    }
  }

  /// Dispose
  Future<void> dispose() async {
    _initialized = false;
  }
}
