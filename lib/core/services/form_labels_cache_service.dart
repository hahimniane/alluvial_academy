import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to cache form field labels for fast retrieval
/// This prevents multiple Firestore queries for the same form template
class FormLabelsCacheService {
  static final FormLabelsCacheService _instance = FormLabelsCacheService._internal();
  factory FormLabelsCacheService() => _instance;
  FormLabelsCacheService._internal();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache: formId -> Map<fieldId, label>
  final Map<String, Map<String, String>> _labelsCache = {};
  
  // Cache: formResponseId -> formId/templateId (to avoid querying form_responses multiple times)
  final Map<String, String?> _formIdCache = {};
  final Map<String, String?> _templateIdCache = {};
  
  // Track loading states to prevent duplicate requests
  final Set<String> _loadingFormIds = {};
  final Set<String> _loadingTemplateIds = {};
  final Set<String> _loadingResponseIds = {};

  /// Get field labels for a form response
  /// Returns cached labels if available, otherwise fetches from Firestore
  Future<Map<String, String>> getLabelsForFormResponse(String formResponseId) async {
    // Check if we already have the formId/templateId cached
    String? formId = _formIdCache[formResponseId];
    String? templateId = _templateIdCache[formResponseId];
    
    // If not cached, fetch from form_responses
    if (formId == null && templateId == null && !_loadingResponseIds.contains(formResponseId)) {
      _loadingResponseIds.add(formResponseId);
      try {
        final formResponseDoc = await _firestore
            .collection('form_responses')
            .doc(formResponseId)
            .get();
        
        if (formResponseDoc.exists) {
          final data = formResponseDoc.data() as Map<String, dynamic>?;
          formId = data?['formId'] as String?;
          templateId = data?['templateId'] as String?;
          
          // Cache the IDs
          _formIdCache[formResponseId] = formId;
          _templateIdCache[formResponseId] = templateId;
        }
      } catch (e) {
        debugPrint('❌ Error fetching form response $formResponseId: $e');
      } finally {
        _loadingResponseIds.remove(formResponseId);
      }
    }
    
    // Try to get labels from formId (old system)
    if (formId != null) {
      final labels = await getLabelsForForm(formId);
      if (labels.isNotEmpty) return labels;
    }
    
    // Try to get labels from templateId (new system)
    if (templateId != null) {
      final labels = await getLabelsForTemplate(templateId);
      if (labels.isNotEmpty) return labels;
    }
    
    return {};
  }

  /// Get field labels for a form (old system)
  Future<Map<String, String>> getLabelsForForm(String formId) async {
    // Check cache first
    if (_labelsCache.containsKey(formId)) {
      return _labelsCache[formId]!;
    }
    
    // Prevent duplicate requests
    if (_loadingFormIds.contains(formId)) {
      // Wait a bit and check cache again
      await Future.delayed(const Duration(milliseconds: 100));
      if (_labelsCache.containsKey(formId)) {
        return _labelsCache[formId]!;
      }
      return {};
    }
    
    _loadingFormIds.add(formId);
    try {
      final formDoc = await _firestore.collection('form').doc(formId).get();
      
      if (formDoc.exists) {
        final formData = formDoc.data() as Map<String, dynamic>?;
        final labels = <String, String>{};
        
        if (formData != null) {
          _extractLabelsFromFields(formData['fields'], labels);
          
          if (labels.isNotEmpty) {
            _labelsCache[formId] = labels;
            debugPrint('✅ Cached ${labels.length} labels for form $formId');
            return labels;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching form $formId: $e');
    } finally {
      _loadingFormIds.remove(formId);
    }
    
    return {};
  }

  /// Get field labels for a template (new system)
  Future<Map<String, String>> getLabelsForTemplate(String templateId) async {
    // Check cache first
    final cacheKey = 'template_$templateId';
    if (_labelsCache.containsKey(cacheKey)) {
      return _labelsCache[cacheKey]!;
    }
    
    // Prevent duplicate requests
    if (_loadingTemplateIds.contains(templateId)) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_labelsCache.containsKey(cacheKey)) {
        return _labelsCache[cacheKey]!;
      }
      return {};
    }
    
    _loadingTemplateIds.add(templateId);
    try {
      final templateDoc = await _firestore
          .collection('form_templates')
          .doc(templateId)
          .get();
      
      if (templateDoc.exists) {
        final raw = templateDoc.data();
        if (raw is! Map<String, dynamic>) {
          if (raw != null) {
            debugPrint('❌ Template $templateId: data is ${raw.runtimeType}, expected Map');
          }
        } else {
          final templateData = raw;
          final labels = <String, String>{};
          final fields = templateData['fields'];
          _extractLabelsFromFields(fields, labels);
          if (labels.isNotEmpty) {
            _labelsCache[cacheKey] = labels;
            debugPrint('✅ Cached ${labels.length} labels for template $templateId');
            return labels;
          }
        }
      }
    } catch (e, stack) {
      debugPrint('❌ Error fetching template $templateId: $e');
      debugPrint('$stack');
    } finally {
      _loadingTemplateIds.remove(templateId);
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
    _formIdCache.clear();
    _templateIdCache.clear();
    debugPrint('🗑️ Form labels cache cleared');
  }

  /// Clear cache for a specific form
  void clearFormCache(String formId) {
    _labelsCache.remove(formId);
    _labelsCache.remove('template_$formId');
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

