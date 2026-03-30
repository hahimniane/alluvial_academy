import 'save_export_file_stub.dart'
    if (dart.library.io) 'save_export_file_io.dart' as save_export_file_io;

/// Writes [content] as UTF-8. Only use when `!kIsWeb`.
Future<String> saveExportUtf8String(String content, String fileName) =>
    save_export_file_io.saveExportUtf8String(content, fileName);

/// Writes raw bytes. Only use when `!kIsWeb`.
Future<String> saveExportBytes(List<int> bytes, String fileName) =>
    save_export_file_io.saveExportBytes(bytes, fileName);
