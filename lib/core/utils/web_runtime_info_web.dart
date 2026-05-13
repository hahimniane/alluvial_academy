// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:js_util' as js_util; // ignore: uri_does_not_exist

/// Best-effort snapshot of `navigator.onLine` plus the non-standard
/// `navigator.connection` (Network Information API). Only Chromium-based
/// browsers expose the connection object; Safari/Firefox return null.
Map<String, dynamic> buildNetworkDiagnostic() {
  final result = <String, dynamic>{};
  try {
    final nav = html.window.navigator;
    result['online'] = nav.onLine;
    final conn = js_util.getProperty(nav, 'connection');
    if (conn != null) {
      result['effectiveType'] = js_util.getProperty(conn, 'effectiveType');
      result['downlinkMbps'] = js_util.getProperty(conn, 'downlink');
      result['rttMs'] = js_util.getProperty(conn, 'rtt');
      result['saveData'] = js_util.getProperty(conn, 'saveData');
    }
  } catch (e) {
    result['error'] = e.toString();
  }
  return result;
}

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
