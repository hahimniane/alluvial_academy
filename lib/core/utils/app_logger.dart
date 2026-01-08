import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

/// Centralized logger for the application with throttling support.
/// 
/// Usage:
/// ```dart
/// import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
/// 
/// // Debug messages (verbose information)
/// AppLogger.debug('User data: $userData');
/// 
/// // Info messages (general information)
/// AppLogger.info('User logged in successfully');
/// 
/// // Warning messages (potential issues)
/// AppLogger.warning('API response took longer than expected');
/// 
/// // Error messages (errors that don't crash the app)
/// AppLogger.error('Failed to load data', error: e, stackTrace: stackTrace);
/// 
/// // Fatal errors (critical errors)
/// AppLogger.fatal('Critical system failure', error: e, stackTrace: stackTrace);
/// ```
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2, // Number of method calls to be displayed
      errorMethodCount: 8, // Number of method calls if stacktrace is provided
      lineLength: 120, // Width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    // Only show logs in debug mode
    filter: kDebugMode ? DevelopmentFilter() : ProductionFilter(),
  );

  /// Throttle mechanism to prevent log spam
  static final Map<String, DateTime> _lastLogTimes = {};
  static const Duration _throttleDuration = Duration(seconds: 5);

  /// Services/prefixes to suppress verbose debug logs from
  static final Set<String> _suppressedDebugPrefixes = {
    'ShiftTimesheetService:',
    'ShiftService:',
    'TeacherAuditService:',
    // Add more services here to suppress their debug logs
  };

  /// Enable/disable debug logging globally
  static bool enableVerboseDebug = false;

  /// Check if a log should be throttled
  static bool _shouldThrottle(String key) {
    final now = DateTime.now();
    final lastTime = _lastLogTimes[key];
    
    if (lastTime == null || now.difference(lastTime) >= _throttleDuration) {
      _lastLogTimes[key] = now;
      return false; // Don't throttle, allow log
    }
    return true; // Throttle, suppress log
  }

  /// Check if message should be suppressed based on prefix
  static bool _shouldSuppressDebug(String message) {
    if (enableVerboseDebug) return false;
    
    final msgStr = message.toString();
    for (final prefix in _suppressedDebugPrefixes) {
      if (msgStr.contains(prefix)) {
        return true;
      }
    }
    return false;
  }

  /// Log a debug message (verbose information)
  /// Use for detailed debugging information that helps during development
  /// Note: Some services have their debug logs suppressed by default
  static void debug(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    final msgStr = message.toString();
    
    // Suppress verbose debug from certain services unless explicitly enabled
    if (_shouldSuppressDebug(msgStr)) {
      return;
    }
    
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log a debug message with throttling (prevents spam)
  /// Use for debug messages that might be called frequently
  static void debugThrottled(String key, dynamic message, {dynamic error, StackTrace? stackTrace}) {
    if (_shouldThrottle(key)) return;
    debug(message, error: error, stackTrace: stackTrace);
  }

  /// Log an info message (general information)
  /// Use for general informational messages about app state
  static void info(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log an info message with throttling
  static void infoThrottled(String key, dynamic message, {dynamic error, StackTrace? stackTrace}) {
    if (_shouldThrottle(key)) return;
    info(message, error: error, stackTrace: stackTrace);
  }

  /// Log a warning message (potential issues)
  /// Use for situations that might cause problems but aren't errors yet
  static void warning(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log an error message (recoverable errors)
  /// Use for errors that were caught and handled
  static void error(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log a fatal error (critical errors)
  /// Use for critical errors that might cause app instability
  static void fatal(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// Log a trace message (very detailed debugging)
  /// Use for extremely verbose debugging when you need to trace execution
  static void trace(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  /// Enable verbose debug logging for all services
  static void enableVerbose() {
    enableVerboseDebug = true;
  }

  /// Disable verbose debug logging (default state)
  static void disableVerbose() {
    enableVerboseDebug = false;
  }

  /// Clear the throttle cache (useful for testing)
  static void clearThrottleCache() {
    _lastLogTimes.clear();
  }

  /// Add a prefix to suppress debug logs from
  static void suppressDebugFrom(String prefix) {
    _suppressedDebugPrefixes.add(prefix);
  }

  /// Remove a prefix from suppression list
  static void unsuppressDebugFrom(String prefix) {
    _suppressedDebugPrefixes.remove(prefix);
  }
}
