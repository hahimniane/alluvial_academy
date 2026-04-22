import '../models/timesheet_entry.dart';

class TimesheetPaymentService {
  const TimesheetPaymentService._();

  static double parseHoursToDecimal(String timeString) {
    try {
      if (timeString.isEmpty || timeString.trim().isEmpty) return 0.0;

      final sanitized = timeString
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'(hours|hour|hrs|hr)'), '')
          .trim();
      if (sanitized.isEmpty) return 0.0;

      if (!sanitized.contains(':')) {
        return double.tryParse(sanitized) ?? 0.0;
      }

      final parts = sanitized.split(':');
      if (parts.length < 2) return 0.0;

      final hours = int.tryParse(parts[0].trim()) ?? 0;
      final minutes = int.tryParse(parts[1].trim()) ?? 0;
      final seconds = parts.length > 2 ? int.tryParse(parts[2].trim()) ?? 0 : 0;

      return hours + (minutes / 60.0) + (seconds / 3600.0);
    } catch (_) {
      return 0.0;
    }
  }

  static double calculatePayment(TimesheetEntry timesheet) {
    try {
      final forceRecalc = timesheet.isEdited && !timesheet.editApproved;
      if (!forceRecalc &&
          timesheet.paymentAmount != null &&
          timesheet.paymentAmount! > 0) {
        return timesheet.paymentAmount!;
      }

      final totalHoursDecimal = parseHoursToDecimal(timesheet.totalHours);
      return totalHoursDecimal * timesheet.hourlyRate;
    } catch (_) {
      return 0.0;
    }
  }
}
