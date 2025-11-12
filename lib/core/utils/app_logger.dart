import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

/// Centralized logger for the application.
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

  /// Log a debug message (verbose information)
  /// Use for detailed debugging information that helps during development
  static void debug(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log an info message (general information)
  /// Use for general informational messages about app state
  static void info(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.i(message, error: error, stackTrace: stackTrace);
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
}

