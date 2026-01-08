import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';

/// Service to manage form configuration from Firestore
/// This replaces hardcoded form IDs with config-driven values
class FormConfigService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache for form IDs to avoid repeated Firestore reads
  static String? _cachedReadinessFormId;
  static DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 30);
  
  // Fallback ID in case config doesn't exist yet (for migration safety)
  static const String _fallbackReadinessFormId = 'Ur1oW7SmFsMyNniTf6jS';
  
  /// Get the readiness form ID from Firestore config
  /// Falls back to hardcoded value if config doesn't exist (migration safety)
  static Future<String> getReadinessFormId() async {
    // Check cache first
    if (_cachedReadinessFormId != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        return _cachedReadinessFormId!;
      }
    }
    
    try {
      final configDoc = await _firestore
          .collection('settings')
          .doc('form_config')
          .get();
      
      if (configDoc.exists) {
        final data = configDoc.data();
        final formId = data?['readinessFormId'] as String?;
        
        if (formId != null && formId.isNotEmpty) {
          _cachedReadinessFormId = formId;
          _cacheTime = DateTime.now();
          AppLogger.debug('FormConfigService: Using config readinessFormId: $formId');
          return formId;
        }
      }
      
      // Config doesn't exist - create it with fallback value
      AppLogger.warning('FormConfigService: Config not found, using fallback and creating config');
      await _createDefaultConfig();
      
      _cachedReadinessFormId = _fallbackReadinessFormId;
      _cacheTime = DateTime.now();
      return _fallbackReadinessFormId;
      
    } catch (e) {
      AppLogger.error('FormConfigService: Error getting readiness form ID: $e');
      // Return fallback on error
      return _fallbackReadinessFormId;
    }
  }
  
  /// Create default config document if it doesn't exist
  static Future<void> _createDefaultConfig() async {
    try {
      await _firestore.collection('settings').doc('form_config').set({
        'readinessFormId': _fallbackReadinessFormId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'description': 'Form configuration - DO NOT DELETE. Update readinessFormId to change which form is used for class readiness reports.',
      }, SetOptions(merge: true));
      
      AppLogger.info('FormConfigService: Created default form_config document');
    } catch (e) {
      AppLogger.error('FormConfigService: Error creating default config: $e');
    }
  }
  
  /// Update the readiness form ID (admin function)
  static Future<bool> updateReadinessFormId(String newFormId) async {
    try {
      // Verify the form exists
      final formDoc = await _firestore.collection('form').doc(newFormId).get();
      if (!formDoc.exists) {
        AppLogger.error('FormConfigService: Cannot update - form $newFormId does not exist');
        return false;
      }
      
      await _firestore.collection('settings').doc('form_config').set({
        'readinessFormId': newFormId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Clear cache
      _cachedReadinessFormId = null;
      _cacheTime = null;
      
      AppLogger.info('FormConfigService: Updated readinessFormId to $newFormId');
      return true;
    } catch (e) {
      AppLogger.error('FormConfigService: Error updating readiness form ID: $e');
      return false;
    }
  }
  
  /// Clear the cache (useful after config updates)
  static void clearCache() {
    _cachedReadinessFormId = null;
    _cacheTime = null;
  }
  
  /// Get yearMonth string from DateTime (format: "2026-01")
  static String getYearMonth(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }
  
  /// Get current yearMonth
  static String getCurrentYearMonth() {
    return getYearMonth(DateTime.now());
  }
  
  /// Parse yearMonth string to DateTime (first day of month)
  static DateTime? parseYearMonth(String yearMonth) {
    try {
      final parts = yearMonth.split('-');
      if (parts.length != 2) return null;
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
    } catch (e) {
      return null;
    }
  }
}

