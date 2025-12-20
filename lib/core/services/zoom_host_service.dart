import 'package:cloud_functions/cloud_functions.dart';
import 'package:alluwalacademyadmin/core/models/zoom_host.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

/// Service for managing Zoom host accounts.
/// Provides methods for CRUD operations on zoom hosts via Cloud Functions.
class ZoomHostService {
  static FirebaseFunctions get _functions => FirebaseFunctions.instance;

  /// List all Zoom hosts with their utilization statistics.
  /// Admin only.
  static Future<List<ZoomHost>> listHosts() async {
    try {
      AppLogger.debug('ZoomHostService: Fetching hosts list...');
      final callable = _functions.httpsCallable('listZoomHosts');
      final result = await callable.call();

      final data = result.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception('Failed to list hosts');
      }

      final hostsList = (data['hosts'] as List<dynamic>?) ?? [];
      final hosts = hostsList
          .map((h) => ZoomHost.fromMap(h as Map<String, dynamic>))
          .toList();

      AppLogger.debug('ZoomHostService: Retrieved ${hosts.length} hosts');
      return hosts;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('ZoomHostService: Cloud Functions error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      AppLogger.error('ZoomHostService: Error listing hosts: $e');
      rethrow;
    }
  }

  /// Add a new Zoom host account.
  /// Validates the account against Zoom API before adding.
  static Future<ZoomHost> addHost({
    required String email,
    String? displayName,
    int maxConcurrentMeetings = 1,
    int? priority,
    String? notes,
  }) async {
    try {
      AppLogger.debug('ZoomHostService: Adding host: $email');
      final callable = _functions.httpsCallable('addZoomHost');
      final result = await callable.call({
        'email': email,
        'displayName': displayName,
        'maxConcurrentMeetings': maxConcurrentMeetings,
        'priority': priority,
        'notes': notes,
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception('Failed to add host');
      }

      final host = ZoomHost.fromMap(data['host'] as Map<String, dynamic>);
      AppLogger.debug('ZoomHostService: Added host with ID: ${host.id}');
      return host;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('ZoomHostService: Cloud Functions error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      AppLogger.error('ZoomHostService: Error adding host: $e');
      rethrow;
    }
  }

  /// Update an existing Zoom host's settings.
  static Future<void> updateHost({
    required String hostId,
    String? displayName,
    int? maxConcurrentMeetings,
    int? priority,
    bool? isActive,
    String? notes,
  }) async {
    try {
      AppLogger.debug('ZoomHostService: Updating host: $hostId');
      final callable = _functions.httpsCallable('updateZoomHost');
      final result = await callable.call({
        'hostId': hostId,
        if (displayName != null) 'displayName': displayName,
        if (maxConcurrentMeetings != null) 'maxConcurrentMeetings': maxConcurrentMeetings,
        if (priority != null) 'priority': priority,
        if (isActive != null) 'isActive': isActive,
        if (notes != null) 'notes': notes,
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception('Failed to update host');
      }

      AppLogger.debug('ZoomHostService: Host updated successfully');
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('ZoomHostService: Cloud Functions error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      AppLogger.error('ZoomHostService: Error updating host: $e');
      rethrow;
    }
  }

  /// Remove (deactivate) a Zoom host.
  /// Fails if the host has upcoming meetings assigned to it.
  static Future<void> removeHost({
    required String hostId,
    bool forceDelete = false,
  }) async {
    try {
      AppLogger.debug('ZoomHostService: Removing host: $hostId (force: $forceDelete)');
      final callable = _functions.httpsCallable('removeZoomHost');
      final result = await callable.call({
        'hostId': hostId,
        'forceDelete': forceDelete,
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception('Failed to remove host');
      }

      AppLogger.debug('ZoomHostService: Host removed successfully');
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('ZoomHostService: Cloud Functions error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      AppLogger.error('ZoomHostService: Error removing host: $e');
      rethrow;
    }
  }

  /// Revalidate a Zoom host's account status.
  static Future<Map<String, dynamic>> revalidateHost({
    required String hostId,
  }) async {
    try {
      AppLogger.debug('ZoomHostService: Revalidating host: $hostId');
      final callable = _functions.httpsCallable('revalidateZoomHost');
      final result = await callable.call({
        'hostId': hostId,
      });

      final data = result.data as Map<String, dynamic>;
      AppLogger.debug('ZoomHostService: Host revalidated - valid: ${data['valid']}');
      return data;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('ZoomHostService: Cloud Functions error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      AppLogger.error('ZoomHostService: Error revalidating host: $e');
      rethrow;
    }
  }

  /// Check host availability for a specific time slot.
  static Future<Map<String, dynamic>> checkAvailability({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      AppLogger.debug('ZoomHostService: Checking availability for ${startTime.toIso8601String()} - ${endTime.toIso8601String()}');
      final callable = _functions.httpsCallable('checkHostAvailability');
      final result = await callable.call({
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
      });

      final data = result.data as Map<String, dynamic>;
      AppLogger.debug('ZoomHostService: Availability check - available: ${data['available']}');
      return data;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('ZoomHostService: Cloud Functions error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      AppLogger.error('ZoomHostService: Error checking availability: $e');
      rethrow;
    }
  }

  /// Parse a NoAvailableHostError from an API response.
  static NoAvailableHostError? parseNoAvailableHostError(Map<String, dynamic>? errorData) {
    if (errorData == null) return null;
    if (errorData['code'] != 'NO_AVAILABLE_HOST' &&
        errorData['code'] != 'NO_HOSTS_CONFIGURED') {
      return null;
    }
    return NoAvailableHostError.fromMap(errorData);
  }
}
