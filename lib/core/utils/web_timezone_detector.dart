import 'dart:js_interop';
import 'package:flutter/foundation.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

@JS('Intl.DateTimeFormat')
external JSFunction get DateTimeFormat;

@JS('Intl.DateTimeFormat')
external JSAny intlDateTimeFormat();

@JS()
@staticInterop
class IntlDateTimeFormat {}

extension IntlDateTimeFormatExtension on IntlDateTimeFormat {
  external JSAny resolvedOptions();
}

@JS()
@staticInterop
class ResolvedOptions {}

extension ResolvedOptionsExtension on ResolvedOptions {
  external String get timeZone;
}

/// Detect timezone on web platform using Intl API
String detectWebTimezone() {
  if (!kIsWeb) {
    throw UnsupportedError('This function is only for web platform');
  }

  try {
    final formatter = intlDateTimeFormat() as IntlDateTimeFormat;
    final options = formatter.resolvedOptions() as ResolvedOptions;
    return options.timeZone;
  } catch (e) {
    AppLogger.error('Error detecting web timezone: $e');
    return 'UTC';
  }
}
