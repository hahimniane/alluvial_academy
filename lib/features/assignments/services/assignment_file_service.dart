import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart';
import '../../../core/utils/app_logger.dart';

/// Service for handling assignment file uploads and downloads
class AssignmentFileService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload a file to Firebase Storage for an assignment
  static Future<Map<String, dynamic>> uploadFile(
    dynamic file, // PlatformFile for mobile, html.File for web
    String assignmentId,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      String fileName;
      int fileSize;
      Uint8List? fileBytes;
      String? filePath;

      if (kIsWeb) {
        // Web: html.File
        final htmlFile = file as html.File;
        fileName = htmlFile.name;
        fileSize = htmlFile.size;
        fileBytes = await _readWebFile(htmlFile);
      } else {
        // Mobile: PlatformFile
        final platformFile = file as PlatformFile;
        fileName = platformFile.name;
        fileSize = platformFile.size ?? 0;
        fileBytes = platformFile.bytes;
        filePath = platformFile.path;
      }

      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = fileName.split('.').last.toLowerCase();
      final uniqueFileName = '${timestamp}_${fileName.replaceAll(' ', '_')}';
      final storagePath = 'assignment_files/$assignmentId/$uniqueFileName';

      // Create storage reference
      final storageRef = _storage.ref().child(storagePath);

      // Upload file
      UploadTask uploadTask;
      if (fileBytes != null) {
        // Upload from bytes (web or mobile with bytes)
        uploadTask = storageRef.putData(
          fileBytes,
          SettableMetadata(
            contentType: _getContentType(fileExtension),
            customMetadata: {
              'originalName': fileName,
              'uploadedBy': currentUser.uid,
              'assignmentId': assignmentId,
            },
          ),
        );
      } else if (filePath != null && !kIsWeb) {
        // Mobile: Upload from file path
        uploadTask = storageRef.putFile(
          File(filePath),
          SettableMetadata(
            contentType: _getContentType(fileExtension),
            customMetadata: {
              'originalName': fileName,
              'uploadedBy': currentUser.uid,
              'assignmentId': assignmentId,
            },
          ),
        );
      } else {
        throw Exception('File data not available');
      }

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      AppLogger.debug('File uploaded successfully: $fileName');
      AppLogger.debug('Download URL: $downloadUrl');

      // Return attachment object
      return {
        'name': fileName,
        'originalName': fileName,
        'size': fileSize,
        'url': downloadUrl,
        'downloadURL': downloadUrl,
        'type': fileExtension,
        'storagePath': storagePath,
        'uploadedAt': DateTime.now().toIso8601String(),
        'uploadedBy': currentUser.uid,
      };
    } catch (e) {
      AppLogger.error('Error uploading assignment file: $e');
      throw Exception('Failed to upload file: ${e.toString()}');
    }
  }

  /// Read file bytes from web File object
  static Future<Uint8List> _readWebFile(html.File file) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    // Convert the result to Uint8List
    final result = reader.result;
    if (result is List<int>) {
      return Uint8List.fromList(result);
    } else if (result is ByteBuffer) {
      return Uint8List.view(result);
    } else {
      throw Exception('Unexpected file reader result type');
    }
  }

  /// Get content type from file extension
  static String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  /// Delete a file from Firebase Storage
  static Future<void> deleteFile(String storagePath) async {
    try {
      final storageRef = _storage.ref().child(storagePath);
      await storageRef.delete();
      AppLogger.debug('File deleted: $storagePath');
    } catch (e) {
      AppLogger.error('Error deleting file: $e');
      throw Exception('Failed to delete file: ${e.toString()}');
    }
  }
}

