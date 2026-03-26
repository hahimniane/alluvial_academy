import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

String _sanitizeFileName(String name) {
  var base = name.replaceAll('\\', '/').split('/').last;
  if (base.isEmpty || base == '.' || base == '..') {
    throw ArgumentError('Invalid file name');
  }
  if (base.contains('..')) {
    throw ArgumentError('Invalid file name');
  }
  return base;
}

Future<Directory> _resolveExportDir() async {
  final downloads = await getDownloadsDirectory();
  if (downloads != null) return downloads;
  return getApplicationDocumentsDirectory();
}

Future<File> _uniqueFile(Directory dir, String fileName) async {
  final sanitized = _sanitizeFileName(fileName);
  var candidate = File(p.join(dir.path, sanitized));
  if (!await candidate.exists()) return candidate;
  final baseName = p.basenameWithoutExtension(sanitized);
  final ext = p.extension(sanitized);
  final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  candidate = File(p.join(dir.path, '${baseName}_$stamp$ext'));
  if (!await candidate.exists()) return candidate;
  final ms = DateTime.now().millisecondsSinceEpoch;
  return File(p.join(dir.path, '${baseName}_${stamp}_$ms$ext'));
}

Future<String> saveExportUtf8String(String content, String fileName) async {
  final dir = await _resolveExportDir();
  final file = await _uniqueFile(dir, fileName);
  await file.writeAsString(content, flush: true, encoding: utf8);
  return file.path;
}

Future<String> saveExportBytes(List<int> bytes, String fileName) async {
  final dir = await _resolveExportDir();
  final file = await _uniqueFile(dir, fileName);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
