import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to cache form field labels for fast retrieval
/// This prevents multiple Firestore queries for the same form template
class FormLabelsCacheService {
  static final FormLabelsCacheService _instance = FormLabelsCacheService._internal();
  factory FormLabelsCacheService() => _instance;
  FormLabelsCacheService._internal();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache: formId -> Map<fieldId, label> with TTL
  static const Duration _cacheTtl = Duration(minutes: 15);
  static const int _maxCacheEntries = 200;
  final Map<String, Map<String, String>> _labelsCache = {};
  final Map<String, DateTime> _labelsCacheTime = {};

  // Cache: formResponseId -> formId/templateId (to avoid querying form_responses multiple times)
  final Map<String, String?> _formIdCache = {};
  final Map<String, String?> _templateIdCache = {};

  /// In-flight loads coalesce concurrent callers onto the same [Future].
  final Map<String, Future<Map<String, String>>> _inFlightResponseLabels = {};
  final Map<String, Future<Map<String, String>>> _inFlightFormLabels = {};
  final Map<String, Future<Map<String, String>>> _inFlightTemplateLabels = {};

  /// Get field labels for a form response
  /// Returns cached labels if available, otherwise fetches from Firestore
  Future<Map<String, String>> getLabelsForFormResponse(String formResponseId) {
    return _inFlightResponseLabels.putIfAbsent(
      formResponseId,
      () => _loadLabelsForFormResponse(formResponseId),
    );
  }

  Future<Map<String, String>> _loadLabelsForFormResponse(
      String formResponseId) async {
    try {
      String? formId = _formIdCache[formResponseId];
      String? templateId = _templateIdCache[formResponseId];

      if (formId == null && templateId == null) {
        try {
          final formResponseDoc = await _firestore
              .collection('form_responses')
              .doc(formResponseId)
              .get();

          if (formResponseDoc.exists) {
            final data = formResponseDoc.data();
            formId = data?['formId'] as String?;
            templateId = data?['templateId'] as String?;
            _formIdCache[formResponseId] = formId;
            _templateIdCache[formResponseId] = templateId;
          }
        } catch (e) {
          debugPrint('❌ Error fetching form response $formResponseId: $e');
        }
      }

      if (formId != null) {
        final labels = await getLabelsForForm(formId);
        if (labels.isNotEmpty) return labels;
      }

      if (templateId != null) {
        final labels = await getLabelsForTemplate(templateId);
        if (labels.isNotEmpty) return labels;
      }

      // Fallback: formId might actually be a form_templates doc ID
      // (older submissions may not have saved templateId separately)
      if (formId != null && templateId == null) {
        final labels = await getLabelsForTemplate(formId);
        if (labels.isNotEmpty) return labels;
      }

      return {};
    } finally {
      _inFlightResponseLabels.remove(formResponseId);
    }
  }

  bool _isCacheValid(String key) {
    final time = _labelsCacheTime[key];
    if (time == null) return false;
    return DateTime.now().difference(time) < _cacheTtl;
  }

  void _putCache(String key, Map<String, String> labels) {
    // Evict oldest entries if at capacity
    if (_labelsCache.length >= _maxCacheEntries && !_labelsCache.containsKey(key)) {
      final oldest = _labelsCacheTime.entries.reduce(
        (a, b) => a.value.isBefore(b.value) ? a : b,
      );
      _labelsCache.remove(oldest.key);
      _labelsCacheTime.remove(oldest.key);
    }
    _labelsCache[key] = labels;
    _labelsCacheTime[key] = DateTime.now();
  }

  /// Get field labels for a form (old system)
  Future<Map<String, String>> getLabelsForForm(String formId) {
    if (_labelsCache.containsKey(formId) && _isCacheValid(formId)) {
      return Future.value(_labelsCache[formId]!);
    }
    return _inFlightFormLabels.putIfAbsent(
      formId,
      () => _loadLabelsForForm(formId),
    );
  }

  Future<Map<String, String>> _loadLabelsForForm(String formId) async {
    try {
      final formDoc = await _firestore.collection('form').doc(formId).get();

      if (formDoc.exists) {
        final formData = formDoc.data();
        final labels = <String, String>{};

        if (formData != null) {
          _extractLabelsFromFields(formData['fields'], labels);

          if (labels.isNotEmpty) {
            _putCache(formId, labels);
            debugPrint('✅ Cached ${labels.length} labels for form $formId');
            return labels;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching form $formId: $e');
    } finally {
      _inFlightFormLabels.remove(formId);
    }

    return {};
  }

  /// Get field labels for a template (new system)
  Future<Map<String, String>> getLabelsForTemplate(String templateId) {
    final cacheKey = 'template_$templateId';
    if (_labelsCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return Future.value(_labelsCache[cacheKey]!);
    }
    return _inFlightTemplateLabels.putIfAbsent(
      templateId,
      () => _loadLabelsForTemplate(templateId, cacheKey),
    );
  }

  Future<Map<String, String>> _loadLabelsForTemplate(
      String templateId, String cacheKey) async {
    try {
      final templateDoc = await _firestore
          .collection('form_templates')
          .doc(templateId)
          .get();

      if (templateDoc.exists) {
        final raw = templateDoc.data();
        if (raw != null) {
          final labels = <String, String>{};
          final fields = raw['fields'];
          _extractLabelsFromFields(fields, labels);
          if (labels.isNotEmpty) {
            _putCache(cacheKey, labels);
            debugPrint('✅ Cached ${labels.length} labels for template $templateId');
            return labels;
          }
        }
      }
    } catch (e, stack) {
      debugPrint('❌ Error fetching template $templateId: $e');
      debugPrint('$stack');
    } finally {
      _inFlightTemplateLabels.remove(templateId);
    }

    return {};
  }

  /// Extract labels from fields (supports both Map and List formats)
  void _extractLabelsFromFields(dynamic fields, Map<String, String> labels) {
    if (fields == null) return;
    if (fields is Map) {
      // Fields is a Map: { "fieldId": { "label": "...", "type": "..." } }
      fields.forEach((fieldId, fieldData) {
        if (fieldData is Map) {
          final label = fieldData['label']?.toString() ??
              fieldData['question']?.toString() ??
              fieldData['name']?.toString() ??
              '';
          if (label.isNotEmpty) {
            labels[fieldId.toString()] = label;
          }
        }
      });
    } else if (fields is List) {
      // Fields is a List: [ { "id": "...", "label": "..." } ]
      for (var field in fields) {
        if (field is Map) {
          final id = field['id']?.toString() ?? '';
          final label = field['label']?.toString() ??
              field['question']?.toString() ??
              field['name']?.toString() ??
              '';
          if (id.isNotEmpty && label.isNotEmpty) {
            labels[id] = label;
          }
        }
      }
    }
  }

  /// Clear the cache (useful for testing or when forms are updated)
  void clearCache() {
    _labelsCache.clear();
    _labelsCacheTime.clear();
    _formIdCache.clear();
    _templateIdCache.clear();
    debugPrint('🗑️ Form labels cache cleared');
  }

  /// Clear cache for a specific form
  void clearFormCache(String formId) {
    _labelsCache.remove(formId);
    _labelsCache.remove('template_$formId');
    _labelsCacheTime.remove(formId);
    _labelsCacheTime.remove('template_$formId');
    _formIdCache.remove(formId);
    _templateIdCache.remove(formId);
  }

  /// Get cache statistics (for debugging)
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedForms': _labelsCache.length,
      'cachedFormIds': _formIdCache.length,
      'cachedTemplateIds': _templateIdCache.length,
    };
  }
}
