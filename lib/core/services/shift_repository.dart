import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/teaching_shift.dart';
import 'shift_service.dart';
import '../utils/app_logger.dart';

/// Optimized repository for shift data with caching and performance optimizations
/// Follows patterns from TeacherAuditService for consistency
class ShiftRepository {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Memory cache for teacher shifts (valid for 5 minutes)
  static Map<String, List<TeachingShift>> _teacherShiftsCache = {};
  static Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheValidityDuration = Duration(minutes: 5);

  /// Get shifts for a teacher with caching
  /// Returns cached data if available and fresh, otherwise fetches new data
  static Future<List<TeachingShift>> getTeacherShiftsCached(String teacherId) async {
    final now = DateTime.now();
    
    // Check cache first
    if (_teacherShiftsCache.containsKey(teacherId) && 
        _cacheTimestamps.containsKey(teacherId)) {
      final cacheTime = _cacheTimestamps[teacherId]!;
      if (now.difference(cacheTime) < _cacheValidityDuration) {
        AppLogger.debug('📦 ShiftRepository: Cache hit for teacher $teacherId');
        return _teacherShiftsCache[teacherId]!;
      }
    }

    // Cache miss or expired - fetch fresh data
    AppLogger.debug('🔄 ShiftRepository: Fetching fresh shifts for teacher $teacherId');
    final shifts = await ShiftService.getShiftsForTeacher(teacherId);
    
    // Update cache
    _teacherShiftsCache[teacherId] = shifts;
    _cacheTimestamps[teacherId] = now;
    
    return shifts;
  }

  /// Clear cache for a specific teacher (call after shift updates)
  static void clearTeacherCache(String teacherId) {
    _teacherShiftsCache.remove(teacherId);
    _cacheTimestamps.remove(teacherId);
    AppLogger.debug('🗑️ ShiftRepository: Cleared cache for teacher $teacherId');
  }

  /// Clear all caches
  static void clearAllCaches() {
    _teacherShiftsCache.clear();
    _cacheTimestamps.clear();
    AppLogger.debug('🗑️ ShiftRepository: Cleared all caches');
  }

  /// Get cached shifts if available (synchronous, for immediate UI updates)
  static List<TeachingShift>? getCachedTeacherShifts(String teacherId) {
    if (_teacherShiftsCache.containsKey(teacherId) && 
        _cacheTimestamps.containsKey(teacherId)) {
      final cacheTime = _cacheTimestamps[teacherId]!;
      if (DateTime.now().difference(cacheTime) < _cacheValidityDuration) {
        return _teacherShiftsCache[teacherId];
      }
    }
    return null;
  }
}
