import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/audit/models/teacher_audit_full.dart';
import 'package:alluwalacademyadmin/features/audit/services/audit_message_composer.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations_en.dart';

void main() {
  test('notification body uses audit status text', () {
    final body = AuditMessageComposer.notificationBody(
      l10n: AppLocalizationsEn(),
      yearMonth: '2026-04',
      status: AuditStatus.completed,
    );

    expect(body, contains('Monthly audit update'));
    expect(body, contains('2026-04'));
    expect(body, contains('finalized'));
  });

  test('detailed audit message uses audit snapshot totals', () {
    final audit = TeacherAuditFull(
      id: 'teacher1_2026-04',
      oderId: 'teacher1',
      teacherEmail: 'teacher@example.com',
      teacherName: 'Teacher One',
      yearMonth: '2026-04',
      hoursTaughtBySubject: const {},
      totalHoursTaught: 0,
      totalClassesScheduled: 3,
      totalClassesCompleted: 2,
      totalClassesMissed: 1,
      totalClassesCancelled: 0,
      completionRate: 66.7,
      totalClockIns: 2,
      onTimeClockIns: 1,
      lateClockIns: 1,
      avgLatencyMinutes: 3,
      punctualityRate: 50,
      readinessFormsRequired: 3,
      readinessFormsSubmitted: 2,
      formComplianceRate: 66.7,
      staffMeetingsScheduled: 0,
      staffMeetingsMissed: 0,
      meetingLateArrivals: 0,
      quizzesGiven: 0,
      assignmentsGiven: 0,
      midtermCompleted: false,
      finalExamCompleted: false,
      semesterProjectStatus: 'Not started',
      overdueTasks: 0,
      weeklyRecordingsSent: 0,
      connecteamSignIns: 0,
      classRemindersSet: 0,
      internetDropOffs: 0,
      status: AuditStatus.completed,
      issues: const [],
      automaticScore: 70,
      coachScore: 80,
      overallScore: 75,
      performanceTier: 'good',
      lastUpdated: DateTime(2026, 5, 1),
    );

    final body = AuditMessageComposer.compose(
      audit: audit,
      l10n: AppLocalizationsEn(),
      channel: AuditMessageChannel.chatDraft,
    );

    expect(body, contains('Teacher One'));
    expect(body, contains('Payment summary'));
    expect(body, contains('Final amount'));
  });

  test('shareLink channel matches detailed audit body like chatDraft', () {
    final audit = TeacherAuditFull(
      id: 'teacher1_2026-04',
      oderId: 'teacher1',
      teacherEmail: 'teacher@example.com',
      teacherName: 'Teacher One',
      yearMonth: '2026-04',
      hoursTaughtBySubject: const {},
      totalHoursTaught: 0,
      totalClassesScheduled: 3,
      totalClassesCompleted: 2,
      totalClassesMissed: 1,
      totalClassesCancelled: 0,
      completionRate: 66.7,
      totalClockIns: 2,
      onTimeClockIns: 1,
      lateClockIns: 1,
      avgLatencyMinutes: 3,
      punctualityRate: 50,
      readinessFormsRequired: 3,
      readinessFormsSubmitted: 2,
      formComplianceRate: 66.7,
      staffMeetingsScheduled: 0,
      staffMeetingsMissed: 0,
      meetingLateArrivals: 0,
      quizzesGiven: 0,
      assignmentsGiven: 0,
      midtermCompleted: false,
      finalExamCompleted: false,
      semesterProjectStatus: 'Not started',
      overdueTasks: 0,
      weeklyRecordingsSent: 0,
      connecteamSignIns: 0,
      classRemindersSet: 0,
      internetDropOffs: 0,
      status: AuditStatus.completed,
      issues: const [],
      automaticScore: 70,
      coachScore: 80,
      overallScore: 75,
      performanceTier: 'good',
      lastUpdated: DateTime(2026, 5, 1),
    );

    final draft = AuditMessageComposer.compose(
      audit: audit,
      l10n: AppLocalizationsEn(),
      channel: AuditMessageChannel.chatDraft,
    );
    final share = AuditMessageComposer.compose(
      audit: audit,
      l10n: AppLocalizationsEn(),
      channel: AuditMessageChannel.shareLink,
    );
    expect(share, draft);
  });
}
