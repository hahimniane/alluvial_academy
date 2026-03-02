import 'dart:typed_data';

/// Stub for non-web platforms -- returns 0 (manual fallback).
Future<int> detectMediaDurationFromBytes(Uint8List bytes, String mimeType) async {
  return 0;
}
