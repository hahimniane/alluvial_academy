import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/teacher_audit_full.dart';
import '../services/teacher_audit_service.dart';
import '../services/form_labels_cache_service.dart';

/// **OPTIMIZATION 1: Parallel Data Loading**
/// Load audits, labels, and other data in parallel instead of sequentially
class OptimizedAuditLoader {
  
  /// Load all audit data with maximum parallelization
  static Future<List<TeacherAuditFull>> loadAuditsOptimized({
    required String yearMonth,
  }) async {
    // Start timer for performance measurement
    final stopwatch = Stopwatch()..start();
    
    try {
      // **PARALLEL LOAD**: Fetch audits and preload form labels simultaneously
      final results = await Future.wait([
        TeacherAuditService.getAuditsForMonth(yearMonth: yearMonth),
        _preloadAllFormLabels(yearMonth), // Preload labels in parallel
      ]);
      
      final audits = results[0] as List<TeacherAuditFull>;
      
      if (kDebugMode) {
        print('✅ Loaded ${audits.length} audits in ${stopwatch.elapsedMilliseconds}ms');
      }
      
      return audits;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading audits: $e');
      }
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }
  
  /// Preload all form labels for a given month in parallel
  static Future<void> _preloadAllFormLabels(String yearMonth) async {
    try {
      // Get all form responses for the month in one query
      final startDate = DateTime.parse('$yearMonth-01');
      final endDate = DateTime(startDate.year, startDate.month + 1, 0, 23, 59, 59);
      
      final snapshot = await FirebaseFirestore.instance
          .collection('form_responses')
          .where('submittedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('submittedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .limit(500) // Limit to prevent excessive queries
          .get();
      
      // Extract unique form IDs and template IDs
      final formIds = <String>{};
      final templateIds = <String>{};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final formId = data['formId'] as String?;
        final templateId = data['templateId'] as String?;
        if (formId != null) formIds.add(formId);
        if (templateId != null) templateIds.add(templateId);
      }
      
      if (formIds.isEmpty && templateIds.isEmpty) return;
      
      // **PARALLEL BATCH LOAD**: Load labels for all forms in parallel batches
      final cacheService = FormLabelsCacheService();
      final futures = <Future>[];
      
      // Load form labels
      for (var formId in formIds) {
        futures.add(cacheService.getLabelsForForm(formId));
      }
      
      // Load template labels
      for (var templateId in templateIds) {
        futures.add(cacheService.getLabelsForTemplate(templateId));
      }
      
      // Wait for all labels to be cached (but don't fail if some fail)
      await Future.wait(futures, eagerError: false);
      
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error preloading form labels: $e');
      }
      // Don't throw - labels are nice-to-have, not critical
    }
  }
}

/// **OPTIMIZATION 2: Parallel Audit Generation**
/// Generate multiple audits simultaneously with controlled concurrency
class OptimizedAuditGenerator {
  
  /// Generate audits with parallel processing and progress tracking
  /// This wraps the existing TeacherAuditService.computeAuditsBatch for consistency
  static Future<Map<String, bool>> generateAuditsBatch({
    required List<String> teacherIds,
    required String yearMonth,
    Function(int completed, int total)? onProgress,
  }) async {
    // Use the existing optimized batch processing from TeacherAuditService
    return await TeacherAuditService.computeAuditsBatch(
      teacherIds: teacherIds,
      yearMonth: yearMonth,
      onProgress: onProgress,
    );
  }
}

/// **OPTIMIZATION 3: Parallel Data Fetching in _AuditDetailSheet**
class OptimizedAuditDataFetcher {
  
  /// Fetch shift and form data in parallel
  static Future<Map<String, dynamic>> fetchAuditDetails({
    required String teacherId,
    required String yearMonth,
  }) async {
    final startDate = DateTime.parse('$yearMonth-01');
    final endDate = DateTime(startDate.year, startDate.month + 1, 0, 23, 59, 59);
    
    // **PARALLEL FETCH**: Get shifts and forms simultaneously
    final results = await Future.wait([
      _fetchShifts(teacherId, startDate, endDate),
      _fetchForms(teacherId, startDate, endDate),
    ]);
    
    return {
      'shifts': results[0],
      'forms': results[1],
    };
  }
  
  static Future<List<DocumentSnapshot>> _fetchShifts(
    String teacherId,
    DateTime start,
    DateTime end,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('teaching_shifts')
        .where('teacher_id', isEqualTo: teacherId)
        .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('start', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    
    return snapshot.docs;
  }
  
  static Future<List<DocumentSnapshot>> _fetchForms(
    String teacherId,
    DateTime start,
    DateTime end,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('form_responses')
        .where('teacherId', isEqualTo: teacherId)
        .where('submittedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('submittedAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    
    return snapshot.docs;
  }
}

/// **OPTIMIZATION 4: Parallel CSV Export**
class OptimizedCSVExporter {
  
  /// Generate CSV data in parallel by processing audits in batches
  static Future<String> generateCSV(List<TeacherAuditFull> audits) async {
    final stopwatch = Stopwatch()..start();
    
    if (audits.isEmpty) {
      return 'Teacher Name,Email,Department,Audit Date,Score,Status,Total Hours,Total Classes,Payout,Coach Review,CEO Review,Founder Review';
    }
    
    // Process audits in parallel batches
    const batchSize = 50;
    final rows = <String>[];
    
    // Header
    rows.add('Teacher Name,Email,Department,Audit Date,Score,Status,Total Hours,Total Classes,Payout,Coach Review,CEO Review,Founder Review');
    
    // Process batches in parallel using compute for heavy processing
    final batches = <Future<List<String>>>[];
    
    for (var i = 0; i < audits.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, audits.length);
      final batch = audits.sublist(i, end);
      
      // Use compute for CPU-intensive CSV generation
      batches.add(compute(_processCSVBatch, batch));
    }
    
    final batchResults = await Future.wait(batches);
    
    // Combine results
    for (var batchRows in batchResults) {
      rows.addAll(batchRows);
    }
    
    if (kDebugMode) {
      print('✅ CSV generated in ${stopwatch.elapsedMilliseconds}ms');
    }
    
    return rows.join('\n');
  }
  
  /// Process a batch of audits (runs in isolate via compute)
  static List<String> _processCSVBatch(List<TeacherAuditFull> audits) {
    return audits.map((audit) {
      final department = audit.hoursTaughtBySubject.keys.isNotEmpty
          ? audit.hoursTaughtBySubject.keys.first
          : 'N/A';
      
      final coachComment = audit.reviewChain?.coachReview?.notes ?? '';
      final ceoComment = audit.reviewChain?.ceoReview?.notes ?? '';
      final founderComment = audit.reviewChain?.founderReview?.notes ?? '';
      
      return '${_escapeCsv(audit.teacherName)},'
          '${_escapeCsv(audit.teacherEmail)},'
          '${_escapeCsv(department)},'
          '${DateFormat('MMM d, yyyy').format(DateTime.parse('${audit.yearMonth}-01'))},'
          '${audit.overallScore.toStringAsFixed(1)},'
          '${audit.status.name},'
          '${audit.totalHoursTaught.toStringAsFixed(1)},'
          '${audit.totalClassesCompleted},'
          '\$${audit.paymentSummary?.totalNetPayment.toStringAsFixed(2) ?? '0.00'},'
          '${_escapeCsv(coachComment)},'
          '${_escapeCsv(ceoComment)},'
          '${_escapeCsv(founderComment)}';
    }).toList();
  }
  
  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

/// **OPTIMIZATION 5: Parallel Teacher Lookup**
class OptimizedTeacherLoader {
  
  /// Load teachers with parallel queries and deduplication
  static Future<List<Map<String, dynamic>>> loadTeachers() async {
    final stopwatch = Stopwatch()..start();
    
    // **PARALLEL QUERIES**: Run all queries simultaneously
    final queries = [
      FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'teacher').get(),
      FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Teacher').get(),
      FirebaseFirestore.instance.collection('users').where('user_type', isEqualTo: 'teacher').get(),
      FirebaseFirestore.instance.collection('users').where('user_type', isEqualTo: 'Teacher').get(),
    ];
    
    final results = await Future.wait(queries);
    
    // Deduplicate
    final allDocs = <String, QueryDocumentSnapshot>{};
    
    for (var snapshot in results) {
      for (var doc in snapshot.docs) {
        allDocs[doc.id] = doc;
      }
    }
    
    // Process documents
    final teachers = <Map<String, dynamic>>[];
    
    for (var doc in allDocs.values) {
      final data = doc.data() as Map<String, dynamic>;
      final name = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
      final email = data['e-mail'] ?? data['email'] ?? '';
      
      if (name.isEmpty && email.isEmpty) continue;
      
      teachers.add({
        'id': doc.id,
        'name': name.isEmpty ? email.split('@')[0] : name,
        'email': email,
      });
    }
    
    teachers.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    
    if (kDebugMode) {
      print('✅ Loaded ${teachers.length} teachers in ${stopwatch.elapsedMilliseconds}ms');
    }
    
    return teachers;
  }
}

/// Performance monitoring utility
class PerformanceMonitor {
  static void time(String label, Future Function() fn) async {
    final stopwatch = Stopwatch()..start();
    await fn();
    stopwatch.stop();
    
    if (kDebugMode) {
      print('⏱️ $label: ${stopwatch.elapsedMilliseconds}ms');
    }
  }
  
  static T timeSync<T>(String label, T Function() fn) {
    final stopwatch = Stopwatch()..start();
    final result = fn();
    stopwatch.stop();
    
    if (kDebugMode) {
      print('⏱️ $label: ${stopwatch.elapsedMilliseconds}ms');
    }
    
    return result;
  }
}

