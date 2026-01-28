import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/tasks/models/task.dart';
import '../enums/task_enums.dart';
import '../utils/app_logger.dart';

/// Optimized repository for task data with caching and performance optimizations
/// Follows patterns from ShiftRepository and TeacherAuditService for consistency
class TaskRepository {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Memory cache for teacher tasks (valid for 5 minutes)
  static Map<String, List<Task>> _teacherTasksCache = {};
  static Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheValidityDuration = Duration(minutes: 5);

  /// Get tasks for a teacher with caching
  /// Returns cached data if available and fresh, otherwise fetches new data
  static Future<List<Task>> getTeacherTasksCached(String teacherId, {bool includeCompleted = false}) async {
    final now = DateTime.now();
    final cacheKey = '$teacherId${includeCompleted ? '_all' : '_active'}';
    
    // Check cache first
    if (_teacherTasksCache.containsKey(cacheKey) && 
        _cacheTimestamps.containsKey(cacheKey)) {
      final cacheTime = _cacheTimestamps[cacheKey]!;
      if (now.difference(cacheTime) < _cacheValidityDuration) {
        AppLogger.debug('📦 TaskRepository: Cache hit for teacher $teacherId');
        return _teacherTasksCache[cacheKey]!;
      }
    }

    // Cache miss or expired - fetch fresh data
    AppLogger.debug('🔄 TaskRepository: Fetching fresh tasks for teacher $teacherId');
    
    try {
      // Fetch all tasks for this teacher and filter in memory
      // This avoids complex index requirements
      final allTasksSnapshot = await _firestore
          .collection('tasks')
          .where('assignedTo', arrayContains: teacherId)
          .get();

      final allTasks = allTasksSnapshot.docs
          .map((doc) {
            try {
              return Task.fromFirestore(doc);
            } catch (e) {
              AppLogger.error('Error parsing task ${doc.id}: $e');
              return null;
            }
          })
          .where((task) => task != null)
          .cast<Task>()
          .toList();

      // Filter by status if needed
      final filteredTasks = includeCompleted
          ? allTasks
          : allTasks.where((task) => task.status != TaskStatus.done).toList();

      // Sort by creation date (most recent first)
      filteredTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Update cache
      _teacherTasksCache[cacheKey] = filteredTasks;
      _cacheTimestamps[cacheKey] = now;
      
      return filteredTasks;
    } catch (e) {
      AppLogger.error('Error fetching tasks: $e');
      // Return cached data if available, even if expired
      if (_teacherTasksCache.containsKey(cacheKey)) {
        AppLogger.debug('⚠️ TaskRepository: Returning stale cache due to error');
        return _teacherTasksCache[cacheKey]!;
      }
      return [];
    }
  }

  /// Get recent tasks for a teacher (top N, cached)
  static Future<List<Task>> getRecentTasksCached(String teacherId, {int limit = 3}) async {
    final allTasks = await getTeacherTasksCached(teacherId, includeCompleted: false);
    return allTasks.take(limit).toList();
  }

  /// Clear cache for a specific teacher (call after task updates)
  static void clearTeacherCache(String teacherId) {
    _teacherTasksCache.remove('${teacherId}_all');
    _teacherTasksCache.remove('${teacherId}_active');
    _cacheTimestamps.remove('${teacherId}_all');
    _cacheTimestamps.remove('${teacherId}_active');
    AppLogger.debug('🗑️ TaskRepository: Cleared cache for teacher $teacherId');
  }

  /// Clear all caches
  static void clearAllCaches() {
    _teacherTasksCache.clear();
    _cacheTimestamps.clear();
    AppLogger.debug('🗑️ TaskRepository: Cleared all caches');
  }

  /// Get cached tasks if available (synchronous, for immediate UI updates)
  static List<Task>? getCachedTeacherTasks(String teacherId, {bool includeCompleted = false}) {
    final cacheKey = '$teacherId${includeCompleted ? '_all' : '_active'}';
    if (_teacherTasksCache.containsKey(cacheKey) && 
        _cacheTimestamps.containsKey(cacheKey)) {
      final cacheTime = _cacheTimestamps[cacheKey]!;
      if (DateTime.now().difference(cacheTime) < _cacheValidityDuration) {
        return _teacherTasksCache[cacheKey];
      }
    }
    return null;
  }
}
