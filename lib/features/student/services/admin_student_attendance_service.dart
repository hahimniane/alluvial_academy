import 'package:cloud_functions/cloud_functions.dart';

import '../models/student_attendance_overview.dart';

class AdminStudentAttendanceService {
  AdminStudentAttendanceService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<StudentAttendanceOverview> loadOverview({
    required String periodType,
    required DateTime referenceDate,
    bool forceRefresh = false,
  }) async {
    final callable =
        _functions.httpsCallable('getAdminStudentAttendanceOverview');
    final result = await callable.call<Map<String, dynamic>>({
      'periodType': periodType,
      'referenceDate': referenceDate.toUtc().toIso8601String(),
      'forceRefresh': forceRefresh,
    });
    return StudentAttendanceOverview.fromMap(result.data);
  }
}
