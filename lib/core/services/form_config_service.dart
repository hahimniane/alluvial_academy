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

  static bool _hasTeacherAccess(Map<String, dynamic> data) {
    final permissions = data['permissions'] as Map<String, dynamic>?;
    if (permissions == null || permissions.isEmpty) return true;

    final permissionType = permissions['type'] as String?;
    if (permissionType == null || permissionType == 'public') return true;
    if (permissionType != 'restricted') return false;

    final role = (permissions['role'] as String?)?.trim().toLowerCase();
    if (role == null || role.isEmpty) return false;
    return role == 'teacher' || role == 'teachers';
  }

  static Future<bool> _isValidLegacyReadinessFormId(String formId) async {
    final formDoc = await _firestore.collection('form').doc(formId).get();
    if (!formDoc.exists) return false;

    final data = formDoc.data() ?? <String, dynamic>{};
    final status = (data['status'] ?? 'active').toString().toLowerCase();
    if (status != 'active') return false;
    return _hasTeacherAccess(data);
  }

  static Future<void> _clearInvalidReadinessFormConfig() async {
    await _firestore.collection('settings').doc('form_config').set(
      {
        'readinessFormId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
  
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
          final isValid = await _isValidLegacyReadinessFormId(formId);
          if (!isValid) {
            AppLogger.warning(
                'FormConfigService: Invalid readinessFormId=$formId (inactive/unauthorized). Clearing config.');
            await _clearInvalidReadinessFormConfig();
            throw StateError(
                'Configured readiness form is invalid. Please select an active teacher-accessible form.');
          }
          _cachedReadinessFormId = formId;
          _cacheTime = DateTime.now();
          AppLogger.debug('FormConfigService: Using config readinessFormId: $formId');
          return formId;
        }
      }
      
      // Config doesn't exist - create it with fallback value
      AppLogger.warning('FormConfigService: Config not found, using fallback and creating config');
      await _createDefaultConfig();

      final fallbackValid = await _isValidLegacyReadinessFormId(_fallbackReadinessFormId);
      if (!fallbackValid) {
        throw StateError(
            'No valid legacy readiness form configured. Please configure an active teacher-accessible form.');
      }
      _cachedReadinessFormId = _fallbackReadinessFormId;
      _cacheTime = DateTime.now();
      return _fallbackReadinessFormId;
      
    } catch (e) {
      AppLogger.error('FormConfigService: Error getting readiness form ID: $e');
      rethrow;
    }
  }
  
  /// Create default config document if it doesn't exist
  static Future<void> _createDefaultConfig() async {
    try {
      await _firestore.collection('settings').doc('form_config').set({
        'readinessFormId': _fallbackReadinessFormId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'description': 'Legacy readiness form configuration. Prefer template-based readiness when available.',
      }, SetOptions(merge: true));
      
      AppLogger.info('FormConfigService: Created default form_config document');
    } catch (e) {
      AppLogger.error('FormConfigService: Error creating default config: $e');
    }
  }
  
  /// Update the readiness form ID (admin function)
  static Future<bool> updateReadinessFormId(String newFormId) async {
    try {
      // Verify the form exists and is teacher-accessible
      final isValid = await _isValidLegacyReadinessFormId(newFormId);
      if (!isValid) {
        AppLogger.error(
            'FormConfigService: Cannot update - form $newFormId is inactive or not teacher-accessible');
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

