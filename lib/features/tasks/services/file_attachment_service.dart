import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;
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
      if (kIsWeb) {
        // For web, fetch file and create proper download
        await _downloadFileWeb(attachment);
      } else {
        // For mobile/desktop, use url launcher
        final Uri uri = Uri.parse(attachment.downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Cannot open file');
        }
      }
    } catch (e) {
      throw Exception('Failed to download file: ${e.toString()}');
    }
  }

  // Web-specific download implementation
  Future<void> _downloadFileWeb(TaskAttachment attachment) async {
    try {
      print('Starting download for: ${attachment.originalName}');

      // Method 1: Try to fetch file and create blob download
      try {
        final response = await http.get(Uri.parse(attachment.downloadUrl));

        if (response.statusCode == 200) {
          // Create blob from file data
          final bytes = response.bodyBytes;
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);

          // Create download link
          final anchor = html.AnchorElement(href: url);
          anchor.setAttribute('download', attachment.originalName);
          anchor.style.display = 'none';

          // Add to document, click, and remove
          html.document.body!.append(anchor);
          anchor.click();
          anchor.remove();

          // Clean up the blob URL
          html.Url.revokeObjectUrl(url);

          print('Download completed for: ${attachment.originalName}');
          return; // Success, exit early
        }
      } catch (fetchError) {
        print('Fetch method failed: $fetchError');
      }

      // Method 2: Try direct download with proper headers
      _tryDirectDownload(attachment);
    } catch (e) {
      print('All download methods failed: $e');
      // Final fallback
      _fallbackDownload(attachment);
    }
  }

  // Try direct download with headers
  void _tryDirectDownload(TaskAttachment attachment) {
    try {
      // Create anchor with download attribute and proper MIME type
      final anchor = html.AnchorElement();
      anchor.href = attachment.downloadUrl;
      anchor.setAttribute('download', attachment.originalName);
      anchor.setAttribute('target', '_self'); // Changed from _blank
      anchor.style.display = 'none';

      // Add headers to force download
      final contentType = _getContentType(attachment.fileType);
      if (contentType.isNotEmpty) {
        anchor.setAttribute('type', contentType);
      }

      // Add to document, click, and remove
      html.document.body!.append(anchor);
      anchor.click();

      // Small delay before removing
      Future.delayed(const Duration(milliseconds: 500), () {
        anchor.remove();
      });

      print('Direct download triggered for: ${attachment.originalName}');
    } catch (e) {
      print('Direct download failed: $e');
      _fallbackDownload(attachment);
    }
  }

  // Fallback download method
  void _fallbackDownload(TaskAttachment attachment) {
    try {
      print('Trying iframe fallback for: ${attachment.originalName}');

      // Method 3: Create iframe to trigger download
      final iframe = html.IFrameElement();
      iframe.style.display = 'none';
      iframe.style.width = '0px';
      iframe.style.height = '0px';
      iframe.src =
          '${attachment.downloadUrl}?download=1&filename=${Uri.encodeComponent(attachment.originalName)}';
      html.document.body!.append(iframe);

      // Remove iframe after a delay
      Future.delayed(const Duration(seconds: 3), () {
        iframe.remove();
      });

      print('Iframe fallback triggered for: ${attachment.originalName}');

      // Wait a bit and then try a final method if needed
      Future.delayed(const Duration(seconds: 1), () {
        _finalDownloadAttempt(attachment);
      });
    } catch (e) {
      print('Iframe fallback failed: $e');
      _finalDownloadAttempt(attachment);
    }
  }

  // Final download attempt with forced headers
  void _finalDownloadAttempt(TaskAttachment attachment) {
    try {
      print('Final download attempt for: ${attachment.originalName}');

      // Create a form to POST and trigger download
      final form = html.FormElement();
      form.method = 'GET';
      form.action = attachment.downloadUrl;
      form.target = '_self';
      form.style.display = 'none';

      html.document.body!.append(form);
      form.submit();

      // Remove form after submission
      Future.delayed(const Duration(milliseconds: 500), () {
        form.remove();
      });

      print(
          'Form submission download triggered for: ${attachment.originalName}');
    } catch (e) {
      print('Final download attempt failed: $e');
      print('Opening in new tab as last resort');
      // Last resort: open in new tab with download hint
      html.window.open('${attachment.downloadUrl}?download=true', '_blank');
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
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
