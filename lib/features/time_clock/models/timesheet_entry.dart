import 'package:cloud_firestore/cloud_firestore.dart';

enum TimesheetStatus { draft, pending, approved, rejected }

class TimesheetEntry {
  final String? documentId; // Firebase document ID for updates
  final String date;
  final String subject; // student name
  final String start;
  final String end;
  final String breakDuration;
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

  // Location fields
  final double? clockInLatitude;
  final double? clockInLongitude;
  final String? clockInAddress;
  final double? clockOutLatitude;
  final double? clockOutLongitude;
  final String? clockOutAddress;

  const TimesheetEntry({
    this.documentId,
    required this.date,
    required this.subject,
    required this.start,
    required this.end,
    required this.breakDuration,
    required this.totalHours,
    required this.description,
    required this.status,
    this.teacherId = '',
    this.teacherName = '',
    this.hourlyRate = 15.0,
    this.createdAt,
    this.submittedAt,
    this.approvedAt,
    this.rejectedAt,
    this.rejectionReason,
    this.paymentAmount,
    this.clockInLatitude,
    this.clockInLongitude,
    this.clockInAddress,
    this.clockOutLatitude,
    this.clockOutLongitude,
    this.clockOutAddress,
  });
}
