import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/time_clock/enums/timesheet_enums.dart';
import 'package:alluwalacademyadmin/features/time_clock/models/timesheet_entry.dart';
import 'package:alluwalacademyadmin/features/time_clock/services/timesheet_payment_service.dart';

void main() {
  group('TimesheetPaymentService', () {
    test('parseHoursToDecimal supports HH:MM:SS and plain decimals', () {
      expect(TimesheetPaymentService.parseHoursToDecimal('01:30:30'),
          closeTo(1.508, 0.001));
      expect(TimesheetPaymentService.parseHoursToDecimal('2.5'), 2.5);
      expect(TimesheetPaymentService.parseHoursToDecimal(''), 0.0);
    });

    test('calculatePayment prefers stored payment when safe', () {
      final entry = TimesheetEntry(
        documentId: 'doc-1',
        date: 'Apr 10, 2026',
        subject: 'Math',
        start: '9:00 AM',
        end: '10:00 AM',
        totalHours: '01:00',
        description: 'Class',
        status: TimesheetStatus.approved,
        teacherId: 't1',
        teacherName: 'Teacher A',
        hourlyRate: 10,
        paymentAmount: 99,
      );
      expect(TimesheetPaymentService.calculatePayment(entry), 99);
    });

    test('calculatePayment recalculates for edited unapproved rows', () {
      final entry = TimesheetEntry(
        documentId: 'doc-2',
        date: 'Apr 10, 2026',
        subject: 'Science',
        start: '9:00 AM',
        end: '11:00 AM',
        totalHours: '02:00',
        description: 'Class',
        status: TimesheetStatus.pending,
        teacherId: 't2',
        teacherName: 'Teacher B',
        hourlyRate: 12,
        paymentAmount: 999,
        isEdited: true,
        editApproved: false,
      );
      expect(TimesheetPaymentService.calculatePayment(entry), 24);
    });
  });
}
