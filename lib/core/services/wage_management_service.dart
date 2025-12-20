import 'package:cloud_firestore/cloud_firestore.dart';
import 'settings_service.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import '../enums/wage_enums.dart';

class WageManagementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _wageSettingsCollection = 'wage_settings';
  static const String _globalDocId = 'global_settings';

  /// Get global wage setting
  static Future<double> getGlobalWage() async {
    return await SettingsService.getGlobalTeacherHourlyRate();
  }

  /// Set global wage for all teachers
  static Future<void> setGlobalWage(double wage) async {
    await SettingsService.setGlobalTeacherHourlyRate(wage);

    // Also update the wage settings collection for tracking
    await _firestore.collection(_wageSettingsCollection).doc(_globalDocId).set({
      'global_wage': wage,
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': 'admin', // You can pass actual admin ID
    }, SetOptions(merge: true));
  }

  /// Get role-based wage settings
  static Future<Map<String, double>> getRoleWages() async {
    try {
      final doc = await _firestore
          .collection(_wageSettingsCollection)
          .doc('role_wages')
          .get();

      if (!doc.exists) return {};

      final data = doc.data() as Map<String, dynamic>;
      final Map<String, double> roleWages = {};

      data.forEach((key, value) {
        if (key != 'updated_at' && key != 'updated_by') {
          roleWages[key] = (value as num).toDouble();
        }
      });

      return roleWages;
    } catch (e) {
      AppLogger.error('Error getting role wages: $e');
      return {};
    }
  }

  /// Set wage for a specific role
  static Future<void> setRoleWage(String role, double wage) async {
    await _firestore.collection(_wageSettingsCollection).doc('role_wages').set({
      role: wage,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get individual wage overrides
  static Future<Map<String, double>> getIndividualWages() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('wage_override', isNotEqualTo: null)
          .get();

      final Map<String, double> individualWages = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['wage_override'] != null) {
          individualWages[doc.id] = (data['wage_override'] as num).toDouble();
        }
      }

      return individualWages;
    } catch (e) {
      AppLogger.error('Error getting individual wages: $e');
      return {};
    }
  }

  /// Set wage for a specific user
  static Future<void> setIndividualWage(String userId, double? wage) async {
    if (wage == null) {
      // Remove wage override
      await _firestore.collection('users').doc(userId).update({
        'wage_override': FieldValue.delete(),
      });
    } else {
      await _firestore.collection('users').doc(userId).update({
        'wage_override': wage,
        'wage_override_updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Get effective wage for a user (considering overrides)
  static Future<double> getEffectiveWageForUser(String userId) async {
    try {
      // First check for individual override
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;

        // Check individual override
        if (data['wage_override'] != null) {
          return (data['wage_override'] as num).toDouble();
        }

        // Check role-based wage
        final userRole = data['role'] as String?;
        if (userRole != null) {
          final roleWages = await getRoleWages();
          if (roleWages.containsKey(userRole)) {
            return roleWages[userRole]!;
          }
        }
      }

      // Fall back to global wage
      return await getGlobalWage();
    } catch (e) {
      AppLogger.error('Error getting effective wage for user: $e');
      return await getGlobalWage();
    }
  }

  /// Apply wage updates to all existing shifts and timesheets
  static Future<Map<String, int>> applyWageUpdates({
    required WageType updateType,
    String? role,
    String? userId,
    required double newWage,
  }) async {
    int shiftsUpdated = 0;
    int timesheetsUpdated = 0;

    try {
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      // Update shifts based on type
      Query shiftsQuery = _firestore.collection('teaching_shifts');

      if (updateType == WageType.individual && userId != null) {
        shiftsQuery = shiftsQuery.where('teacherId', isEqualTo: userId);
      }

      final shiftsSnapshot = await shiftsQuery.get();

      for (var doc in shiftsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        bool shouldUpdate = false;

        switch (updateType) {
          case WageType.global:
            shouldUpdate = true;
            break;
          case WageType.role:
            // Check if teacher has this role
            if (role != null) {
              final teacherDoc = await _firestore
                  .collection('users')
                  .doc(data['teacherId'])
                  .get();
              if (teacherDoc.exists && teacherDoc.data()!['role'] == role) {
                shouldUpdate = true;
              }
            }
            break;
          case WageType.individual:
            shouldUpdate = data['teacherId'] == userId;
            break;
        }

        if (shouldUpdate) {
          batch.update(doc.reference, {
            'hourlyRate': newWage,
            'lastModified': FieldValue.serverTimestamp(),
          });
          shiftsUpdated++;
          batchCount++;

          if (batchCount >= 500) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
          }
        }
      }

      // Update timesheet entries
      Query timesheetsQuery = _firestore.collection('timesheet_entries');

      if (updateType == WageType.individual && userId != null) {
        timesheetsQuery =
            timesheetsQuery.where('teacher_id', isEqualTo: userId);
      }

      final timesheetsSnapshot = await timesheetsQuery.get();

      for (var doc in timesheetsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        bool shouldUpdate = false;

        switch (updateType) {
          case WageType.global:
            shouldUpdate = true;
            break;
          case WageType.role:
            // Check if teacher has this role
            if (role != null) {
              final teacherDoc = await _firestore
                  .collection('users')
                  .doc(data['teacher_id'])
                  .get();
              if (teacherDoc.exists && teacherDoc.data()!['role'] == role) {
                shouldUpdate = true;
              }
            }
            break;
          case WageType.individual:
            shouldUpdate = data['teacher_id'] == userId;
            break;
        }

        if (shouldUpdate) {
          batch.update(doc.reference, {
            'hourly_rate': newWage,
            'updated_at': FieldValue.serverTimestamp(),
          });
          timesheetsUpdated++;
          batchCount++;

          if (batchCount >= 500) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
          }
        }
      }

      // Commit remaining updates
      if (batchCount > 0) {
        await batch.commit();
      }

      return {
        'shifts': shiftsUpdated,
        'timesheets': timesheetsUpdated,
      };
    } catch (e) {
      AppLogger.error('Error applying wage updates: $e');
      return {
        'shifts': shiftsUpdated,
        'timesheets': timesheetsUpdated,
      };
    }
  }

  /// Get all available roles in the system
  static Future<List<String>> getAvailableRoles() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isNotEqualTo: null)
          .get();

      final Set<String> roles = {};
      for (var doc in snapshot.docs) {
        final role = doc.data()['role'] as String?;
        if (role != null) {
          roles.add(role);
        }
      }

      return roles.toList()..sort();
    } catch (e) {
      AppLogger.error('Error getting available roles: $e');
      return ['Teacher', 'Admin', 'Student']; // Default roles
    }
  }

  /// Get all users for individual wage management
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').where('role',
          whereIn: ['Teacher', 'teacher', 'Admin', 'admin']).get();

      final users = <Map<String, dynamic>>[];
      final globalWage = await getGlobalWage();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final role = data['role'] as String? ?? 'Unknown';
        users.add({
          'id': doc.id,
          'name':
              '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim(),
          'email': data['email'],
          'role': role,
          'current_wage': data['hourly_rate'] ?? globalWage,
          'has_override': data['wage_override'] != null,
          'override_wage': data['wage_override'],
        });
      }

      users.sort((a, b) => a['name'].compareTo(b['name']));
      return users;
    } catch (e) {
      AppLogger.error('Error getting users: $e');
      return [];
    }
  }

  /// Update wages for multiple users at once
  static Future<void> setMultipleIndividualWages(
      Map<String, double> userWages) async {
    final batch = _firestore.batch();

    for (var entry in userWages.entries) {
      batch.update(_firestore.collection('users').doc(entry.key), {
        'wage_override': entry.value,
        'wage_override_updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
