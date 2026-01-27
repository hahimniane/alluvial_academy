import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';

class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'language_code';
  static const String _userLanguageField = 'language_preference';

  Locale? _locale;

  Locale? get locale => _locale;

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('fr'),
    // Locale('ar'), // Arabic disabled for now - RTL support needed
  ];

  LanguageService() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_languageKey);
      if (savedCode != null) {
        _locale = _resolveLocale(savedCode);
        notifyListeners();
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final code = doc.data()?[_userLanguageField] as String?;
        if (code != null) {
          _locale = _resolveLocale(code);
          await prefs.setString(_languageKey, _locale!.languageCode);
          notifyListeners();
          return;
        }
      }

      final deviceLocale = PlatformDispatcher.instance.locale;
      _locale = _resolveLocale(deviceLocale.languageCode);
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error loading language: $e');
    }
  }

  Future<void> setLocale(Locale locale) async {
    final resolved = _resolveLocale(locale.languageCode);
    if (_locale == resolved) return;
    _locale = resolved;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, resolved.languageCode);
    } catch (e) {
      AppLogger.error('Error saving language preference: $e');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({_userLanguageField: resolved.languageCode});
      } catch (e) {
        AppLogger.error('Error syncing language to Firestore: $e');
      }
    }
  }

  Locale _resolveLocale(String languageCode) {
    for (final locale in supportedLocales) {
      if (locale.languageCode == languageCode) return locale;
    }
    return supportedLocales.first;
  }

  bool isSupported(Locale locale) {
    return supportedLocales
        .any((supported) => supported.languageCode == locale.languageCode);
  }
}
