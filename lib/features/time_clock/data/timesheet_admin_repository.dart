import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/core/utils/performance_logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/enums/timesheet_enums.dart';
import '../controllers/timesheet_review_controller.dart';
import '../models/timesheet_entry.dart';

/// Firestore reads and snapshot processing for admin timesheet review.
class TimesheetAdminRepository {
  TimesheetAdminRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _entries =>
      _db.collection('timesheet_entries');

  /// Same query shape as legacy admin listener (status filter server-side).
  Query<Map<String, dynamic>> timesheetEntriesQuery(String statusFilter) {
    Query<Map<String, dynamic>> query = _entries;
    if (statusFilter != 'All') {
      query = query.where('status', isEqualTo: statusFilter.toLowerCase());
    }
    return query;
  }

  /// Parses snapshot into consolidated rows + teacher list + perf summary.
  Future<TimesheetSnapshotProcessResult> processTimesheetSnapshot(
    QuerySnapshot snapshot,
  ) async {
    final opId = PerformanceLogger.newOperationId(
        'TimesheetAdminRepository.processTimesheetSnapshot');
    PerformanceLogger.startTimer(opId, metadata: {
      'doc_count': snapshot.docs.length,
    });

    final summary = <String, dynamic>{
      'doc_count': snapshot.docs.length,
    };

    try {
      final List<TimesheetEntry> rawEntries = [];
      int parseErrors = 0;

      final userCache = <String, Map<String, dynamic>?>{};
      final shiftCache = <String, Map<String, dynamic>?>{};
      int userFetches = 0;
      int userCacheHits = 0;
      int userFetchMs = 0;
      int shiftFetches = 0;
      int shiftCacheHits = 0;
      int shiftFetchMs = 0;

      final parseStopwatch = Stopwatch()..start();
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final entry = await _createTimesheetEntry(
            doc,
            data,
            userCache: userCache,
            shiftCache: shiftCache,
            onUserFetch: (ms) {
              userFetches++;
              userFetchMs += ms;
            },
            onUserCacheHit: () => userCacheHits++,
            onShiftFetch: (ms) {
              shiftFetches++;
              shiftFetchMs += ms;
            },
            onShiftCacheHit: () => shiftCacheHits++,
          );
          if (entry != null) {
            rawEntries.add(entry);
          }
        } catch (e) {
          AppLogger.error('Error processing timesheet document ${doc.id}: $e');
          parseErrors++;
        }
      }
      parseStopwatch.stop();

      PerformanceLogger.checkpoint(opId, 'entries_built', metadata: {
        'raw_entries': rawEntries.length,
        'parse_errors': parseErrors,
        'parse_time_ms': parseStopwatch.elapsedMilliseconds,
        'user_fetches': userFetches,
        'user_cache_hits': userCacheHits,
        'user_fetch_time_ms': userFetchMs,
        'shift_fetches': shiftFetches,
        'shift_cache_hits': shiftCacheHits,
        'shift_fetch_time_ms': shiftFetchMs,
      });

      final Map<String, List<TimesheetEntry>> grouped = {};
      final List<TimesheetEntry> consolidatedList = [];

      final consolidateStopwatch = Stopwatch()..start();
      for (final entry in rawEntries) {
        if (entry.shiftId != null) {
          grouped.putIfAbsent(entry.shiftId!, () => []).add(entry);
        } else {
          consolidatedList.add(entry);
        }
      }

      grouped.forEach((shiftId, entries) {
        if (entries.length == 1) {
          consolidatedList.add(entries.first);
        } else {
          double totalHours = 0;
          double totalPayment = 0;

          for (final e in entries) {
            totalPayment += (e.paymentAmount ?? 0);
            final parts = e.totalHours.split(':');
            if (parts.length >= 2) {
              try {
                final h = int.parse(parts[0]);
                final m = int.parse(parts[1]);
                totalHours += h + (m / 60.0);
              } catch (_) {}
            }
          }

          final h = totalHours.floor();
          final m = ((totalHours - h) * 60).round();
          final formattedTotalHours =
              '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

          TimesheetStatus groupStatus = TimesheetStatus.approved;
          if (entries.any((e) => e.status == TimesheetStatus.rejected)) {
            groupStatus = TimesheetStatus.rejected;
          }
          if (entries.any((e) => e.status == TimesheetStatus.draft)) {
            groupStatus = TimesheetStatus.draft;
          }
          if (entries.any((e) => e.status == TimesheetStatus.pending)) {
            groupStatus = TimesheetStatus.pending;
          }

          entries.sort((a, b) => a.start.compareTo(b.start));
          final first = entries.first;
          final last = entries.last;

          consolidatedList.add(TimesheetEntry(
            documentId: 'consolidated_$shiftId',
            date: first.date,
            subject: '${first.subject} (${entries.length} sessions)',
            start: first.start,
            end: last.end,
            totalHours: formattedTotalHours,
            description: 'Consolidated shift with ${entries.length} clock-ins',
            status: groupStatus,
            teacherId: first.teacherId,
            teacherName: first.teacherName,
            hourlyRate: first.hourlyRate,
            paymentAmount: totalPayment,
            shiftTitle: first.shiftTitle,
            isConsolidated: true,
            childEntries: entries,
            shiftId: shiftId,
          ));
        }
      });
      consolidateStopwatch.stop();

      var timesheets = consolidatedList;

      final sortStopwatch = Stopwatch()..start();
      timesheets.sort((a, b) {
        try {
          return b.date.compareTo(a.date);
        } catch (_) {
          return 0;
        }
      });
      sortStopwatch.stop();

      PerformanceLogger.checkpoint(opId, 'consolidated_and_sorted', metadata: {
        'group_count': grouped.length,
        'consolidated_count': timesheets.length,
        'consolidate_time_ms': consolidateStopwatch.elapsedMilliseconds,
        'sort_time_ms': sortStopwatch.elapsedMilliseconds,
      });

      final teachers = timesheets.map((e) => e.teacherName).toSet().toList()
        ..sort();

      summary.addAll({
        'entries_built': rawEntries.length,
        'timesheets_final': timesheets.length,
        'parse_errors': parseErrors,
        'user_fetch_time_ms': userFetchMs,
        'shift_fetch_time_ms': shiftFetchMs,
      });
      PerformanceLogger.endTimer(opId, metadata: summary);

      return TimesheetSnapshotProcessResult(
        timesheets: timesheets,
        teachers: teachers,
        summary: summary,
      );
    } catch (e) {
      AppLogger.error('Error processing timesheet snapshot: $e');
      summary['error'] = e.toString();
      PerformanceLogger.endTimer(opId, metadata: summary);
      rethrow;
    }
  }

  Future<TimesheetEntry?> _createTimesheetEntry(
    QueryDocumentSnapshot doc,
    Map<String, dynamic> data, {
    required Map<String, Map<String, dynamic>?> userCache,
    required Map<String, Map<String, dynamic>?> shiftCache,
    required ValueChanged<int> onUserFetch,
    required VoidCallback onUserCacheHit,
    required ValueChanged<int> onShiftFetch,
    required VoidCallback onShiftCacheHit,
  }) async {
    try {
      final teacherId = data['teacher_id']?.toString();
      Map<String, dynamic>? userData;

      if (teacherId != null && teacherId.isNotEmpty) {
        if (userCache.containsKey(teacherId)) {
          userData = userCache[teacherId];
          onUserCacheHit();
        } else {
          final sw = Stopwatch()..start();
          final userDoc =
              await _db.collection('users').doc(teacherId).get();
          sw.stop();
          onUserFetch(sw.elapsedMilliseconds);

          userData = userDoc.data();
          userCache[teacherId] = userData;
        }
      }

      final timesheetHourlyRate = (data['hourly_rate'] as num?)?.toDouble();
      final userHourlyRate = (userData?['hourly_rate'] as num?)?.toDouble();
      final hourlyRate = timesheetHourlyRate ?? userHourlyRate ?? 4.0;
      final userName =
          '${userData?['first_name'] ?? ''} ${userData?['last_name'] ?? ''}'
              .trim();

      final clockInTimestamp = data['clock_in_timestamp'] as Timestamp?;
      final clockOutTimestamp = data['clock_out_timestamp'] as Timestamp?;
      final scheduledStart = data['scheduled_start'] as Timestamp?;
      final scheduledEnd = data['scheduled_end'] as Timestamp?;
      final scheduledDurationMinutes =
          data['scheduled_duration_minutes'] as int?;

      DateTime? finalScheduledStart = scheduledStart?.toDate();
      DateTime? finalScheduledEnd = scheduledEnd?.toDate();
      int? finalScheduledDurationMinutes = scheduledDurationMinutes;

      final shiftId = data['shift_id'] as String?;
      if ((finalScheduledStart == null ||
              finalScheduledEnd == null ||
              finalScheduledDurationMinutes == null) &&
          shiftId != null) {
        try {
          Map<String, dynamic>? shiftData;
          if (shiftCache.containsKey(shiftId)) {
            shiftData = shiftCache[shiftId];
            onShiftCacheHit();
          } else {
            final sw = Stopwatch()..start();
            final shiftDoc =
                await _db.collection('teaching_shifts').doc(shiftId).get();
            sw.stop();
            onShiftFetch(sw.elapsedMilliseconds);
            shiftData = shiftDoc.data();
            shiftCache[shiftId] = shiftData;
          }

          if (shiftData != null) {
            if (finalScheduledStart == null &&
                shiftData['shift_start'] != null) {
              finalScheduledStart =
                  (shiftData['shift_start'] as Timestamp).toDate();
            }
            if (finalScheduledEnd == null && shiftData['shift_end'] != null) {
              finalScheduledEnd =
                  (shiftData['shift_end'] as Timestamp).toDate();
            }
            if (finalScheduledDurationMinutes == null) {
              if (finalScheduledStart != null && finalScheduledEnd != null) {
                finalScheduledDurationMinutes =
                    finalScheduledEnd.difference(finalScheduledStart).inMinutes;
              }
            }
          }
        } catch (e) {
          AppLogger.debug(
              'Could not fetch shift data for shift_id $shiftId: $e');
        }
      }

      return TimesheetEntry(
        documentId: doc.id,
        date: data['date'] ?? '',
        subject: data['student_name'] ?? '',
        start: data['start_time'] ?? '',
        end: data['end_time'] ?? '',
        totalHours: data['total_hours'] ?? '00:00',
        description: data['description'] ?? '',
        status: TimesheetReviewController.parseStatusLabel(
            (data['status'] ?? 'draft').toString()),
        teacherId: data['teacher_id'] ?? '',
        teacherName: userName,
        hourlyRate: hourlyRate,
        createdAt: data['created_at'] as Timestamp?,
        submittedAt: data['submitted_at'] as Timestamp?,
        approvedAt: data['approved_at'] as Timestamp?,
        rejectedAt: data['rejected_at'] as Timestamp?,
        rejectionReason: data['rejection_reason'] as String?,
        paymentAmount: (data['payment_amount'] as num?)?.toDouble() ??
            (data['total_pay'] as num?)?.toDouble(),
        source: data['source'] as String? ?? 'manual',
        shiftTitle: data['shift_title'] as String?,
        shiftType: data['shift_type'] as String?,
        clockInPlatform: data['clock_in_platform'] as String?,
        clockOutPlatform: data['clock_out_platform'] as String?,
        scheduledStart: finalScheduledStart,
        scheduledEnd: finalScheduledEnd,
        scheduledDurationMinutes: finalScheduledDurationMinutes,
        employeeNotes: data['employee_notes'] as String?,
        managerNotes: data['manager_notes'] as String?,
        clockInTimestamp: clockInTimestamp,
        clockOutTimestamp: clockOutTimestamp,
        isEdited: data['is_edited'] == true || data['edited_at'] != null,
        editApproved: data['edit_approved'] == true,
        originalData: data['original_data'] as Map<String, dynamic>?,
        previousStatus: data['previous_status'] as String?,
        editedAt: data['edited_at'] as Timestamp?,
        editedBy: data['edited_by'] as String?,
        formResponseId: data['form_response_id'] as String?,
        formCompleted:
            data['form_completed'] == true || data['form_response_id'] != null,
        reportedHours: (data['reported_hours'] as num?)?.toDouble(),
        formNotes: data['form_notes'] as String?,
        shiftId: shiftId,
      );
    } catch (e) {
      AppLogger.error('Error creating timesheet entry for doc ${doc.id}: $e');
      return null;
    }
  }

  DocumentReference<Map<String, dynamic>> timesheetDoc(String documentId) =>
      _entries.doc(documentId);

  Future<void> updateTimesheet(
    String documentId,
    Map<String, dynamic> data,
  ) =>
      timesheetDoc(documentId).update(data);

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchTimesheet(
    String documentId,
  ) =>
      timesheetDoc(documentId).get();

  WriteBatch newWriteBatch() => _db.batch();

  /// When a teacher's **edit** is rejected, restore [original_data] and prior status.
  static Map<String, dynamic> buildEditRejectionUpdate(
    Map<String, dynamic> data,
    String reason,
  ) {
    final original = Map<String, dynamic>.from(data['original_data'] as Map);
    final revertData = <String, dynamic>{
      'clock_in_timestamp': original['clock_in_timestamp'],
      'clock_out_timestamp': original['clock_out_timestamp'],
      'start_time': original['start_time'],
      'end_time': original['end_time'],
      'total_hours': original['total_hours'],
      'is_edited': false,
      'edit_approved': false,
      'original_data': FieldValue.delete(),
      'edit_reverted_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'edit_rejection_reason': reason,
      'rejection_reason': FieldValue.delete(),
      'rejected_at': FieldValue.delete(),
    };
    if (original.containsKey('effective_end_timestamp')) {
      revertData['effective_end_timestamp'] =
          original['effective_end_timestamp'];
    } else {
      revertData['effective_end_timestamp'] = FieldValue.delete();
    }
    if (original.containsKey('payment_amount') &&
        original['payment_amount'] != null) {
      revertData['payment_amount'] = original['payment_amount'];
    }
    if (original.containsKey('total_pay') && original['total_pay'] != null) {
      revertData['total_pay'] = original['total_pay'];
    }
    revertData['status'] = (data['previous_status'] as String?) ?? 'pending';
    return revertData;
  }
}

class TimesheetSnapshotProcessResult {
  TimesheetSnapshotProcessResult({
    required this.timesheets,
    required this.teachers,
    required this.summary,
  });

  final List<TimesheetEntry> timesheets;
  final List<String> teachers;
  final Map<String, dynamic> summary;
}
