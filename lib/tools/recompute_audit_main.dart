// Recomputes one teacher's monthly audit with the real engine and prints the
// result, then exits. Used to prove a fix against production without an
// interactive admin session:
//
//   flutter run -d <simulator> -t lib/tools/recompute_audit_main.dart \
//     --dart-define=FIREBASE_ENV=prod \
//     --dart-define=AUDIT_EMAIL=<throwaway admin email> \
//     --dart-define=AUDIT_PASSWORD=<its password> \
//     --dart-define=AUDIT_TEACHER=<teacher uid> --dart-define=AUDIT_MONTH=2026-07
//
// Prints a single line starting with AUDIT_RESULT.
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import '../features/audit/services/teacher_audit_service.dart';
import '../firebase_options.dart' as prod_firebase;

const String _email = String.fromEnvironment('AUDIT_EMAIL');
const String _password = String.fromEnvironment('AUDIT_PASSWORD');
const String _teacher = String.fromEnvironment('AUDIT_TEACHER');
const String _month = String.fromEnvironment('AUDIT_MONTH');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  await Firebase.initializeApp(
    options: prod_firebase.DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _email,
      password: _password,
    );
    final audit = await TeacherAuditService.computeAuditForTeacher(
      userId: _teacher,
      yearMonth: _month,
    );
    if (audit == null) {
      debugPrint('AUDIT_RESULT error=no-audit-returned');
    } else {
      final m = audit.toMap();
      final pay = m['paymentSummary'];
      debugPrint(
        'AUDIT_RESULT teacher=$_teacher month=$_month '
        'hours=${m['totalWorkedHours']} status=${m['status']} '
        'net=${pay is Map ? pay['totalNetPayment'] : '-'} '
        'gross=${pay is Map ? pay['totalGrossPayment'] : '-'}',
      );
    }
  } catch (e, st) {
    debugPrint('AUDIT_RESULT error=$e\n$st');
  } finally {
    await FirebaseAuth.instance.signOut();
  }
  exit(0);
}
