// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

String buildRuntimeDiagnostic() {
  try {
    final navigator = html.window.navigator;
    final location = html.window.location;

    final parts = <String>[
      'ua=${_sanitize(navigator.userAgent)}',
      'online=${navigator.onLine}',
      'host=${_sanitize(location.host)}',
      'path=${_sanitize(location.pathname)}',
      'cores=${navigator.hardwareConcurrency}',
      'lang=${_sanitize(navigator.language)}',
    ];

    return parts.join('|');
  } catch (_) {
    return '';
  }
}

String _sanitize(String? value) {
  if (value == null || value.isEmpty) return 'unknown';
  return value
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll('|', '/')
      .replaceAll(';', ',');
}
