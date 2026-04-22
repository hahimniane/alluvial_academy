import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';

/// Matches [storage.rules] `canWritePublicSiteAssets` max size for CMS uploads.
const int kPublicSiteImageMaxBytes = 8 * 1024 * 1024;

/// Reads image bytes from [FilePicker] on all platforms (web uses stream; IO uses bytes/path).
Future<Uint8List?> readPlatformImageBytes(PlatformFile f) async {
  if (f.bytes != null && f.bytes!.isNotEmpty) {
    return f.bytes!.length > kPublicSiteImageMaxBytes ? null : f.bytes;
  }
  if (f.readStream != null) {
    final out = <int>[];
    await for (final chunk in f.readStream!) {
      out.addAll(chunk);
      if (out.length > kPublicSiteImageMaxBytes) {
        return null;
      }
    }
    return out.isEmpty ? null : Uint8List.fromList(out);
  }
  if (f.path != null && f.path!.isNotEmpty) {
    try {
      final data = await XFile(f.path!, name: f.name).readAsBytes();
      if (data.isEmpty || data.length > kPublicSiteImageMaxBytes) {
        return null;
      }
      return data;
    } catch (_) {
      return null;
    }
  }
  return null;
}
