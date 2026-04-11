import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class ReceiptUploadService {
  static FirebaseStorage get _storage => FirebaseStorage.instance;
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pickReceipt(
      {ImageSource source = ImageSource.camera}) async {
    try {
      return await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
    } catch (error) {
      AppLogger.error('ReceiptUploadService.pickReceipt error: $error');
      return null;
    }
  }

  static Future<String> uploadReceipt(
    XFile file, {
    required String circleId,
    required String cycleId,
    required String userId,
  }) async {
    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref =
        _storage.ref().child('circle_receipts/$circleId/$cycleId/$fileName');

    UploadTask uploadTask;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } else {
      uploadTask = ref.putFile(
        File(file.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
    }

    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }
}
