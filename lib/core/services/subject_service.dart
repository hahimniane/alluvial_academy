import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subject.dart';

class SubjectService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'subjects';

  // Create a slug from display name and ensure uniqueness in Firestore
  static Future<String> generateUniqueInternalName(String displayName) async {
    String slug = displayName
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), "_")
        .replaceAll(RegExp(r"_+"), "_")
        .replaceAll(RegExp(r"^_+|_+$"), "");
    if (slug.isEmpty) slug = 'subject';

    String unique = slug;
    int i = 1;
    while (true) {
      final dup = await _firestore
          .collection(_collection)
          .where('name', isEqualTo: unique)
          .limit(1)
          .get();
      if (dup.docs.isEmpty) return unique;
      unique = '${slug}_${i++}';
    }
  }

  // Initialize default subjects if collection is empty
  static Future<void> initializeDefaultSubjects() async {
    try {
      final snapshot = await _firestore.collection(_collection).limit(1).get();

      if (snapshot.docs.isEmpty) {
        print('Initializing default subjects...');
        final batch = _firestore.batch();

        for (final subjectData in DefaultSubjects.subjects) {
          final docRef = _firestore.collection(_collection).doc();
          batch.set(docRef, {
            ...subjectData,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        print('Default subjects initialized successfully');
      }
    } catch (e) {
      print('Error initializing default subjects: $e');
    }
  }

  // Get all subjects
  static Stream<List<Subject>> getSubjectsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Subject.fromFirestore(doc)).toList();
    });
  }

  // Get active subjects only
  static Stream<List<Subject>> getActiveSubjectsStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Subject.fromFirestore(doc)).toList();
    });
  }

  // Get all subjects (one-time fetch)
  static Future<List<Subject>> getAllSubjects() async {
    try {
      final snapshot =
          await _firestore.collection(_collection).orderBy('sortOrder').get();

      return snapshot.docs.map((doc) => Subject.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching subjects: $e');
      return [];
    }
  }

  // Get active subjects (one-time fetch)
  static Future<List<Subject>> getActiveSubjects() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

      return snapshot.docs.map((doc) => Subject.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching active subjects: $e');
      return [];
    }
  }

  // Add a new subject
  static Future<void> addSubject({
    required String name,
    required String displayName,
    String? description,
    String? arabicName,
    required int sortOrder,
  }) async {
    try {
      await _firestore.collection(_collection).add({
        'name': name,
        'displayName': displayName,
        'description': description,
        'arabicName': arabicName,
        'sortOrder': sortOrder,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding subject: $e');
      rethrow;
    }
  }

  // Add subject by auto-generating a unique internal name (slug)
  static Future<void> addSubjectAutoName({
    required String displayName,
    String? description,
    String? arabicName,
    required int sortOrder,
  }) async {
    final name = await generateUniqueInternalName(displayName);
    return addSubject(
      name: name,
      displayName: displayName,
      description: description,
      arabicName: arabicName,
      sortOrder: sortOrder,
    );
  }

  // Update a subject
  static Future<void> updateSubject(
      String id, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating subject: $e');
      rethrow;
    }
  }

  // Toggle subject active status
  static Future<void> toggleSubjectStatus(String id, bool isActive) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error toggling subject status: $e');
      rethrow;
    }
  }

  // Delete a subject (soft delete by setting isActive to false)
  static Future<void> deleteSubject(String id) async {
    try {
      // Instead of deleting, we'll just deactivate it
      await toggleSubjectStatus(id, false);
    } catch (e) {
      print('Error deleting subject: $e');
      rethrow;
    }
  }

  // Permanently delete a subject document
  static Future<void> hardDeleteSubject(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      print('Error permanently deleting subject: $e');
      rethrow;
    }
  }

  // Reorder subjects
  static Future<void> reorderSubjects(List<Subject> subjects) async {
    try {
      final batch = _firestore.batch();

      for (int i = 0; i < subjects.length; i++) {
        batch.update(
          _firestore.collection(_collection).doc(subjects[i].id),
          {
            'sortOrder': i + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }

      await batch.commit();
    } catch (e) {
      print('Error reordering subjects: $e');
      rethrow;
    }
  }

  // Get subject by ID
  static Future<Subject?> getSubjectById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();

      if (doc.exists) {
        return Subject.fromFirestore(doc);
      }

      return null;
    } catch (e) {
      print('Error fetching subject by ID: $e');
      return null;
    }
  }

  // Search subjects
  static Future<List<Subject>> searchSubjects(String query) async {
    try {
      final lowercaseQuery = query.toLowerCase();
      final snapshot =
          await _firestore.collection(_collection).orderBy('sortOrder').get();

      return snapshot.docs
          .map((doc) => Subject.fromFirestore(doc))
          .where((subject) =>
              subject.displayName.toLowerCase().contains(lowercaseQuery) ||
              subject.name.toLowerCase().contains(lowercaseQuery) ||
              (subject.arabicName?.contains(query) ?? false) ||
              (subject.description?.toLowerCase().contains(lowercaseQuery) ??
                  false))
          .toList();
    } catch (e) {
      print('Error searching subjects: $e');
      return [];
    }
  }
}
