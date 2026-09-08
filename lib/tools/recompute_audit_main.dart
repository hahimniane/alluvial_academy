// Recomputes one teacher's monthly audit with the real engine and prints the
// result, then exits. Used to prove a fix against production without an
// interactive admin session:
//
//   flutter run -d <simulator> -t lib/tools/recompute_audit_main.dart \
//     --dart-define=FIREBASE_ENV=prod \
//     --dart-define=AUDIT_EMAIL=<throwaway admin email> \
//     --dart-define=AUDIT_PASSWORD=<its password> \
//     --dart-define=AUDIT_TEACHER=<uid or ALL> --dart-define=AUDIT_MONTH=2026-06,2026-07
//
// Prints one AUDIT_RESULT line per month, then AUDIT_DONE.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import '../features/audit/services/teacher_audit_service.dart';
import '../firebase_options.dart' as prod_firebase;

const String _email = String.fromEnvironment('AUDIT_EMAIL');
const String _password = String.fromEnvironment('AUDIT_PASSWORD');
/// One uid, or ALL for every teacher with a class, a timesheet entry or a
/// stored audit in the month.
const String _teacher = String.fromEnvironment('AUDIT_TEACHER');
/// One month, or several separated by commas: 2026-06,2026-07
const String _months = String.fromEnvironment('AUDIT_MONTH');

Future<List<String>> _teachersWithActivity(String yearMonth) async {
  final db = FirebaseFirestore.instance;
  final start = DateTime.parse('$yearMonth-01');
  final end = DateTime(start.year, start.month + 1, 1);
  final ids = <String>{};
  for (final col in ['teaching_shifts', 'teaching_shifts_archive']) {
    final snap = await db
        .collection(col)
        .where('shift_start', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('shift_start', isLessThan: Timestamp.fromDate(end))
        .get();
    for (final d in snap.docs) {
      final t = (d.data()['teacher_id'] ?? '').toString();
      if (t.isNotEmpty) ids.add(t);
    }
  }
  final entries = await db
      .collection('timesheet_entries')
      .where('clock_in_timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('clock_in_timestamp', isLessThan: Timestamp.fromDate(end))
      .get();
  for (final d in entries.docs) {
    final t = (d.data()['teacher_id'] ?? '').toString();
    if (t.isNotEmpty) ids.add(t);
  }
  final audits = await db.collection('teacher_audits').where('yearMonth', isEqualTo: yearMonth).get();
  for (final d in audits.docs) {
    final fromDoc = d.id.endsWith('_$yearMonth') ? d.id.substring(0, d.id.length - yearMonth.length - 1) : '';
    final t = (d.data()['oderId'] ?? d.data()['teacherId'] ?? d.data()['userId'] ?? fromDoc).toString();
    if (t.isNotEmpty) ids.add(t);
  }
  // Audits are for teacher accounts only. Admins who cover a class appear as
  // teacher_id on shifts but are never audited or paid through an audit.
  final teachers = <String>[];
  for (final id in ids) {
    final u = await db.collection('users').doc(id).get();
    final type = (u.data()?['user_type'] ?? '').toString().toLowerCase();
    if (u.exists && type == 'teacher') teachers.add(id);
  }
  return teachers..sort();
}

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
    for (final month in _months.split(',').map((m) => m.trim()).where((m) => m.isNotEmpty)) {
      final teachers = _teacher == 'ALL' ? await _teachersWithActivity(month) : [_teacher];
      debugPrint('AUDIT_START month=$month teachers=${teachers.length}');
      final results = await TeacherAuditService.computeAuditsBatch(
        teacherIds: teachers,
        yearMonth: month,
      );
      final ok = results.values.where((v) => v).length;
      debugPrint('AUDIT_RESULT month=$month computed=$ok of ${teachers.length} '
          'failed=${results.entries.where((e) => !e.value).map((e) => e.key).join(',')}');
    }
  } catch (e, st) {
    debugPrint('AUDIT_RESULT error=$e\n$st');
  } finally {
    await FirebaseAuth.instance.signOut();
  }
  debugPrint('AUDIT_DONE');
  exit(0);
}
