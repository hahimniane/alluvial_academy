// Hard line: nothing that counts a period of teaching shifts may read the live
// collection alone. Classes older than 60 days live in
// `teaching_shifts_archive`; a live-only range query silently drops them and
// the hours, pay or attendance it feeds come out short (July 2026: 40.40 h
// shown for a teacher who clocked 55.25 h).
//
// Range queries on `shift_start` must go through ShiftArchiveReader.inRange.
// The files listed below predate the rule and show upcoming or current
// classes only. Do not add a file that feeds pay, audits, invoices or
// attendance to this list.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const allowedLiveOnly = {
  'lib/core/services/shift_archive_reader.dart', // the reader itself
  'lib/features/shift_management/services/shift_service.dart', // calendar views
  'lib/features/dashboard/services/leader_attendance_service.dart',
  'lib/features/dashboard/widgets/admin_cards/admin_action_cards.dart',
  'lib/features/forms/screens/teacher_forms_screen.dart',
  'lib/features/audit/screens/teacher_audit_screen.dart',
  'lib/features/audit/screens/test_audit_generation.dart',
  'lib/features/audit/services/audit_performance_optimizer.dart',
  'lib/features/tutor/screens/ai_tutor_screen.dart',
  'lib/features/parent/services/parent_service.dart', // parent's upcoming classes
  'lib/features/user_management/screens/user_management_screen.dart', // counts on the user card
  'lib/features/time_clock/widgets/edit_timesheet_dialog.dart', // neighbouring shifts while editing one entry
};

void main() {
  test('period computations read live + archive through ShiftArchiveReader', () {
    final pattern = RegExp(
      r"collection\('teaching_shifts'\)[\s\S]{0,500}?'shift_start'[\s\S]{0,80}?isGreaterThan",
    );
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rel = entity.path.replaceAll('\\', '/');
      if (allowedLiveOnly.contains(rel)) continue;
      if (pattern.hasMatch(entity.readAsStringSync())) offenders.add(rel);
    }
    expect(offenders, isEmpty,
        reason: 'These files query the live shift collection by date range. '
            'Use ShiftArchiveReader.inRange so archived classes are counted.');
  });
}
