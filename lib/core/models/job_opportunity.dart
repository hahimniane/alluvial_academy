import 'package:cloud_firestore/cloud_firestore.dart';

class JobOpportunity {
  final String id;
  final String enrollmentId;
  final String studentName;
  final String studentAge;
  final String subject;
  final String gradeLevel;
  final List<String> days;
  final List<String> timeSlots;
  final String timeZone;
  final String status; // 'open', 'accepted', 'closed'
  final DateTime createdAt;
  final String? acceptedByTeacherId;
  final DateTime? acceptedAt;
  final bool isAdult;

  JobOpportunity({
    required this.id,
    required this.enrollmentId,
    required this.studentName,
    required this.studentAge,
    required this.subject,
    required this.gradeLevel,
    required this.days,
    required this.timeSlots,
    required this.timeZone,
    required this.status,
    required this.createdAt,
    this.acceptedByTeacherId,
    this.acceptedAt,
    this.isAdult = false,
  });

  factory JobOpportunity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobOpportunity(
      id: doc.id,
      enrollmentId: data['enrollmentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentAge: data['studentAge'] ?? '',
      subject: data['subject'] ?? '',
      gradeLevel: data['gradeLevel'] ?? '',
      days: List<String>.from(data['days'] ?? []),
      timeSlots: List<String>.from(data['timeSlots'] ?? []),
      timeZone: data['timeZone'] ?? '',
      status: data['status'] ?? 'open',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      acceptedByTeacherId: data['acceptedByTeacherId'],
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      isAdult: data['isAdult'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enrollmentId': enrollmentId,
      'studentName': studentName,
      'studentAge': studentAge,
      'subject': subject,
      'gradeLevel': gradeLevel,
      'days': days,
      'timeSlots': timeSlots,
      'timeZone': timeZone,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'isAdult': isAdult,
      if (acceptedByTeacherId != null) 'acceptedByTeacherId': acceptedByTeacherId,
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
    };
  }
}

