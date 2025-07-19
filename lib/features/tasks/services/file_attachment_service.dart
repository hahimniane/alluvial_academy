import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';

class FileAttachmentService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // Simple test function to verify file picker works
  Future<bool> testFilePicker() async {
    try {
      print('Testing file picker...');
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        print('Test successful: ${result.files.first.name}');
        return true;
      } else {
        print('Test: No file selected');
        return false;
      }
    } catch (e) {
      print('Test failed: $e');
      return false;
    }
  }

  // Pick file(s) for upload
  Future<List<PlatformFile>?> pickFiles() async {
    try {
      print('Starting file picker...');

      // Use a more web-friendly approach with fallback
      FilePickerResult? result;

      if (kIsWeb) {
        // Web-specific configuration
        result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.any,
          withData: true,
          withReadStream: false,
        );
      } else {
        // Mobile/Desktop configuration
        result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: [
            'pdf',
            'doc',
            'docx',
            'txt',
            'rtf',
            'xls',
            'xlsx',
            'csv',
            'ppt',
            'pptx',
            'jpg',
            'jpeg',
            'png',
            'gif',
            'bmp',
            'mp4',
            'avi',
            'mov',
            'wmv',
            'mp3',
            'wav',
            'aac',
            'zip',
            'rar',
            '7z',
          ],
          withData: true,
        );
      }

      print('File picker result: ${result?.files.length ?? 0} files selected');

      if (result != null && result.files.isNotEmpty) {
        // Filter files by size and type
        const maxFileSize = 10 * 1024 * 1024; // 10MB
        final allowedExtensions = {
          'pdf', 'doc', 'docx', 'txt', 'rtf', // Documents
          'xls', 'xlsx', 'csv', // Spreadsheets
          'ppt', 'pptx', // Presentations
          'jpg', 'jpeg', 'png', 'gif', 'bmp', // Images
          'mp4', 'avi', 'mov', 'wmv', // Videos
          'mp3', 'wav', 'aac', // Audio
          'zip', 'rar', '7z', // Archives
        };

        List<PlatformFile> validFiles = result.files.where((file) {
          final extension = file.extension?.toLowerCase() ?? '';
          final sizeOk = file.size <= maxFileSize;
          final typeOk = allowedExtensions.contains(extension);

          if (!typeOk) {
            print('File ${file.name} rejected: unsupported type ($extension)');
          }
          if (!sizeOk) {
            print('File ${file.name} rejected: too large (${file.size} bytes)');
          }

          return sizeOk && typeOk;
        }).toList();

        if (validFiles.isEmpty) {
          throw Exception(
              'No valid files selected. Please ensure files are under 10MB and of supported types.');
        }

        if (validFiles.length != result.files.length) {
          final rejected = result.files.length - validFiles.length;
          print(
              '$rejected files were excluded due to size or type restrictions');
        }

        print('${validFiles.length} valid files selected');
        return validFiles;
      }

      print('No files selected');
      return null;
    } catch (e) {
      print('File picker error: $e');
      throw Exception('Failed to pick files: ${e.toString()}');
    }
  }

  // Upload file to Firebase Storage
  Future<TaskAttachment> uploadFile(PlatformFile file, String taskId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Generate unique file name
      final fileId = _uuid.v4();
      final fileExtension = file.extension ?? '';
      final fileName = '$fileId.$fileExtension';

      // Create storage reference
      final storageRef =
          _storage.ref().child('task_attachments/$taskId/$fileName');

      // Upload file
      UploadTask uploadTask;
      if (file.bytes != null) {
        // Web upload
        uploadTask = storageRef.putData(
          file.bytes!,
          SettableMetadata(
            contentType: _getContentType(fileExtension),
            customMetadata: {
              'originalName': file.name,
              'uploadedBy': currentUser.uid,
              'taskId': taskId,
            },
          ),
        );
      } else if (file.path != null) {
        // Mobile upload
        uploadTask = storageRef.putFile(
          File(file.path!),
          SettableMetadata(
            contentType: _getContentType(fileExtension),
            customMetadata: {
              'originalName': file.name,
              'uploadedBy': currentUser.uid,
              'taskId': taskId,
            },
          ),
        );
      } else {
        throw Exception('File data not available');
      }

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Create attachment object
      return TaskAttachment(
        id: fileId,
        fileName: fileName,
        originalName: file.name,
        downloadUrl: downloadUrl,
        fileType: fileExtension,
        fileSize: file.size,
        uploadedAt: DateTime.now(),
        uploadedBy: currentUser.uid,
      );
    } catch (e) {
      throw Exception('Failed to upload file: ${e.toString()}');
    }
  }

  // Download/View file
  Future<void> downloadFile(TaskAttachment attachment) async {
    try {
      final Uri uri = Uri.parse(attachment.downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Cannot open file');
      }
    } catch (e) {
      throw Exception('Failed to download file: ${e.toString()}');
    }
  }

  // Delete file from Firebase Storage
  Future<void> deleteFile(TaskAttachment attachment, String taskId) async {
    try {
      final storageRef = _storage
          .ref()
          .child('task_attachments/$taskId/${attachment.fileName}');
      await storageRef.delete();
    } catch (e) {
      print('Failed to delete file from storage: ${e.toString()}');
      // Don't throw error as the file might already be deleted
    }
  }

  // Get content type based on file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'rtf':
        return 'application/rtf';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv':
        return 'text/csv';
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
      case 'bmp':
        return 'image/bmp';
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'wmv':
        return 'video/x-ms-wmv';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/vnd.rar';
      case '7z':
        return 'application/x-7z-compressed';
      default:
        return 'application/octet-stream';
    }
  }

  // Get file icon based on file type
  String getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      case 'txt':
      case 'rtf':
        return '📃';
      case 'xls':
      case 'xlsx':
      case 'csv':
        return '📊';
      case 'ppt':
      case 'pptx':
        return '📊';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return '🖼️';
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
        return '🎥';
      case 'mp3':
      case 'wav':
      case 'aac':
        return '🎵';
      case 'zip':
      case 'rar':
      case '7z':
        return '🗜️';
      default:
        return '📎';
    }
  }

  // Format file size for display
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
