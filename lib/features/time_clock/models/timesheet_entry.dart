import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/enums/timesheet_enums.dart';

class TimesheetEntry {
  final String? documentId; // Firebase document ID for updates
  final String date;
  final String subject; // student name
  final String start;
  final String end;
  final String totalHours;
  final String description;
  final TimesheetStatus status;

  // Additional fields for admin review
  final String teacherId;
  final String teacherName;
  final double hourlyRate;
  final Timestamp? createdAt;
  final Timestamp? submittedAt;
  final Timestamp? approvedAt;
  final Timestamp? rejectedAt;
  final String? rejectionReason;
  final double? paymentAmount;
  final String? source; // 'clock_in' or 'manual'

  // Location fields
  final double? clockInLatitude;
  final double? clockInLongitude;
  final String? clockInAddress;
  final double? clockOutLatitude;
  final double? clockOutLongitude;
  final String? clockOutAddress;

  // Export fields (for ConnectTeam-style export)
  final String? shiftTitle; // Cached shift display name
  final String? shiftType; // Formatted type string (e.g., "Stu - John - Teacher (1hr)")
  final String? clockInPlatform; // Device used for clock-in
  final String? clockOutPlatform; // Device used for clock-out
  final DateTime? scheduledStart; // Original scheduled start time
  final DateTime? scheduledEnd; // Original scheduled end time
  final int? scheduledDurationMinutes; // Scheduled duration in minutes
  final String? employeeNotes; // Notes from teacher
  final String? managerNotes; // Notes from admin
  
  // Edit tracking fields
  final bool isEdited; // Whether this timesheet was edited
  final bool editApproved; // Whether the edit was approved by admin
  final Map<String, dynamic>? originalData; // Original data before edit (for comparison)
  final Timestamp? editedAt; // When the timesheet was edited
  final String? editedBy; // Who edited the timesheet
  
  // Readiness Form linkage
  final String? formResponseId; // ID of the linked form response
  final bool formCompleted; // Whether the post-class form was filled
  final double? reportedHours; // Hours reported in the form (for comparison)
  final String? formNotes; // Any notes from the form
  final String? shiftId; // Link to the shift
  
  // Consolidated View Support
  final bool isConsolidated;
  final List<TimesheetEntry>? childEntries;

  const TimesheetEntry({
    this.documentId,
    required this.date,
    required this.subject,
    required this.start,
    required this.end,
    required this.totalHours,
    required this.description,
    required this.status,
    this.teacherId = '',
    this.teacherName = '',
    this.hourlyRate = 4.0,
    this.createdAt,
    this.submittedAt,
    this.approvedAt,
    this.rejectedAt,
    this.rejectionReason,
    this.paymentAmount,
    this.source,
    this.clockInLatitude,
    this.clockInLongitude,
    this.clockInAddress,
    this.clockOutLatitude,
    this.clockOutLongitude,
    this.clockOutAddress,
    this.shiftTitle,
    this.shiftType,
    this.clockInPlatform,
    this.clockOutPlatform,
    this.scheduledStart,
    this.scheduledEnd,
    this.scheduledDurationMinutes,
    this.employeeNotes,
    this.managerNotes,
    this.isEdited = false,
    this.editApproved = false,
    this.originalData,
    this.editedAt,
    this.editedBy,
    this.formResponseId,
    this.formCompleted = false,
    this.reportedHours,
    this.formNotes,
    this.shiftId,
    this.isConsolidated = false,
    this.childEntries,
  });
}
