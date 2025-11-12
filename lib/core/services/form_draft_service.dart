import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/form_draft.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

/// Service for managing form drafts in Firestore
class FormDraftService {
  static const String _collection = 'form_drafts';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Save or update a form draft
  Future<String> saveDraft({
    String? draftId,
    required String title,
    required String description,
    required Map<String, dynamic> fields,
    String? originalFormId,
    Map<String, dynamic>? originalFormData,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to save drafts');
      }

      final now = DateTime.now();

      final draftData = {
        'title': title,
        'description': description,
        'fields': fields,
        'createdBy': user.uid,
        'lastModifiedAt': Timestamp.fromDate(now),
        if (originalFormId != null) 'originalFormId': originalFormId,
        if (originalFormData != null) 'originalFormData': originalFormData,
      };

      if (draftId != null) {
        // Update existing draft
        await _firestore.collection(_collection).doc(draftId).update(draftData);
        AppLogger.info('FormDraftService: Updated draft $draftId');
        return draftId;
      } else {
        // Create new draft
        draftData['createdAt'] = Timestamp.fromDate(now);
        final docRef = await _firestore.collection(_collection).add(draftData);
        AppLogger.error('FormDraftService: Created new draft ${docRef.id}');

        // Clean up old drafts if we exceed 10 drafts
        await _limitUserDrafts();

        return docRef.id;
      }
    } catch (e) {
      AppLogger.error('FormDraftService: Error saving draft: $e');
      rethrow;
    }
  }

  /// Get a specific draft by ID
  Future<FormDraft?> getDraft(String draftId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(draftId).get();
      if (!doc.exists) return null;

      return FormDraft.fromFirestore(doc);
    } catch (e) {
      AppLogger.error('FormDraftService: Error getting draft: $e');
      return null;
    }
  }

  /// Get all drafts for the current user (limited to 10 most recent)
  Stream<List<FormDraft>> getUserDrafts() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_collection)
        .where('createdBy', isEqualTo: user.uid)
        .orderBy('lastModifiedAt', descending: true)
        .limit(10) // Limit to 10 most recent drafts
        .snapshots()
        .handleError((error) {
      AppLogger.error('FormDraftService: Error in getUserDrafts stream: $error');
      return <QuerySnapshot>[];
    }).map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => FormDraft.fromFirestore(doc))
            .toList();
      } catch (e) {
        AppLogger.error('FormDraftService: Error parsing drafts: $e');
        return <FormDraft>[];
      }
    });
  }

  /// Delete a draft
  Future<void> deleteDraft(String draftId) async {
    try {
      await _firestore.collection(_collection).doc(draftId).delete();
      AppLogger.error('FormDraftService: Deleted draft $draftId');
    } catch (e) {
      AppLogger.error('FormDraftService: Error deleting draft: $e');
      rethrow;
    }
  }

  /// Delete all drafts for a user (cleanup function)
  Future<void> deleteAllUserDrafts() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _firestore
          .collection(_collection)
          .where('createdBy', isEqualTo: user.uid)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      AppLogger.error('FormDraftService: Deleted all drafts for user ${user.uid}');
    } catch (e) {
      AppLogger.error('FormDraftService: Error deleting all drafts: $e');
      rethrow;
    }
  }

  /// Clean up old drafts (older than 30 days)
  Future<void> cleanupOldDrafts() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

      final snapshot = await _firestore
          .collection(_collection)
          .where('createdBy', isEqualTo: user.uid)
          .where('lastModifiedAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      AppLogger.error('FormDraftService: Cleaned up ${snapshot.docs.length} old drafts');
    } catch (e) {
      AppLogger.error('FormDraftService: Error cleaning up old drafts: $e');
    }
  }

  /// Check if there's an existing draft for editing a specific form
  Future<FormDraft?> getDraftForForm(String originalFormId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final snapshot = await _firestore
          .collection(_collection)
          .where('createdBy', isEqualTo: user.uid)
          .where('originalFormId', isEqualTo: originalFormId)
          .orderBy('lastModifiedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return FormDraft.fromFirestore(snapshot.docs.first);
    } catch (e) {
      AppLogger.error('FormDraftService: Error getting draft for form: $e');
      return null;
    }
  }

  /// Convert draft fields back to FormFieldData list for the form builder
  List<dynamic> convertDraftFieldsToFormFields(
      Map<String, dynamic> draftFields) {
    final converted = draftFields.entries.map((entry) {
      final fieldData = entry.value as Map<String, dynamic>;
      return {
        'id': entry.key,
        'type': fieldData['type'] ?? 'openEnded',
        'label': fieldData['label'] ?? '',
        'placeholder': fieldData['placeholder'] ?? '',
        'required': fieldData['required'] ?? false,
        'order': fieldData['order'] ?? 0,
        'options': (fieldData['options'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        'additionalConfig': fieldData['additionalConfig'],
        'conditionalLogic': fieldData['conditionalLogic'],
      };
    }).toList();

    // Sort by order to maintain proper field sequence
    converted.sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));

    AppLogger.debug('FormDraftService: Converted ${converted.length} fields from draft');
    for (var field in converted) {
      AppLogger.debug('  - Field ${field['id']}: ${field['type']} (${field['label']})');
    }

    return converted;
  }

  /// Limit user drafts to 10 most recent, delete oldest ones
  Future<void> _limitUserDrafts() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get all drafts for user, ordered by last modified (oldest first)
      final snapshot = await _firestore
          .collection(_collection)
          .where('createdBy', isEqualTo: user.uid)
          .orderBy('lastModifiedAt', descending: false) // Oldest first
          .get();

      // If we have more than 10 drafts, delete the oldest ones
      if (snapshot.docs.length > 10) {
        final docsToDelete =
            snapshot.docs.take(snapshot.docs.length - 10).toList();

        final batch = _firestore.batch();
        for (final doc in docsToDelete) {
          batch.delete(doc.reference);
        }

        await batch.commit();
        AppLogger.error(
            'FormDraftService: Cleaned up ${docsToDelete.length} old drafts to maintain 10 draft limit');
      }
    } catch (e) {
      AppLogger.error('FormDraftService: Error limiting user drafts: $e');
      // Don't rethrow as this is a cleanup operation
    }
  }

  /// Test Firestore connection and permissions
  Future<bool> testConnection() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        AppLogger.debug('FormDraftService: No authenticated user for connection test');
        return false;
      }

      AppLogger.debug('FormDraftService: Testing connection for user ${user.uid}');

      // Try to read from the collection
      final snapshot = await _firestore
          .collection(_collection)
          .where('createdBy', isEqualTo: user.uid)
          .limit(1)
          .get();

      AppLogger.error(
          'FormDraftService: Connection test successful, found ${snapshot.docs.length} documents');
      return true;
    } catch (e) {
      AppLogger.error('FormDraftService: Connection test failed: $e');
      return false;
    }
  }
}
