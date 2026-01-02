import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/app_logger.dart';
import 'mock_company_service.dart';

/// Service for fetching invoice-related data (parent names, student names, etc.)
class InvoiceDataService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Fetch parent name from Firestore
  static Future<String?> getParentName(String parentId) async {
    try {
      final doc = await _firestore.collection('users').doc(parentId).get();
      if (!doc.exists) {
        AppLogger.debug('InvoiceDataService: Parent not found: $parentId');
        return null;
      }

      final data = doc.data();
      final first = (data?['first_name'] ?? '').toString().trim();
      final last = (data?['last_name'] ?? '').toString().trim();
      final name = ('$first $last').trim();

      return name.isNotEmpty ? name : null;
    } catch (e) {
      AppLogger.error('InvoiceDataService: Error fetching parent name: $e');
      return null;
    }
  }

  /// Fetch student name from Firestore
  static Future<String?> getStudentName(String studentId) async {
    try {
      final doc = await _firestore.collection('users').doc(studentId).get();
      if (!doc.exists) {
        AppLogger.debug('InvoiceDataService: Student not found: $studentId');
        return null;
      }

      final data = doc.data();
      final first = (data?['first_name'] ?? '').toString().trim();
      final last = (data?['last_name'] ?? '').toString().trim();
      final name = ('$first $last').trim();

      return name.isNotEmpty ? name : null;
    } catch (e) {
      AppLogger.error('InvoiceDataService: Error fetching student name: $e');
      return null;
    }
  }

  /// Fetch multiple student names efficiently
  static Future<Map<String, String>> getStudentNames(List<String> studentIds) async {
    final Map<String, String> names = {};

    if (studentIds.isEmpty) return names;

    try {
      // Fetch in batches of 10 (Firestore 'in' query limit)
      for (int i = 0; i < studentIds.length; i += 10) {
        final batch = studentIds.skip(i).take(10).toList();
        final snapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final first = (data['first_name'] ?? '').toString().trim();
          final last = (data['last_name'] ?? '').toString().trim();
          final name = ('$first $last').trim();
          if (name.isNotEmpty) {
            names[doc.id] = name;
          }
        }
      }
    } catch (e) {
      AppLogger.error('InvoiceDataService: Error fetching student names: $e');
    }

    return names;
  }

  /// Get company info (currently from mock service, can be replaced with Firestore later)
  static CompanyInfo getCompanyInfo() {
    return MockCompanyService.getCompanyInfo();
  }

  /// Get admin info (currently from mock service, can be replaced with Firestore later)
  static AdminInfo getAdminInfo() {
    return MockCompanyService.getAdminInfo();
  }
}

