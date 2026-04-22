import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

/// Service to handle profile picture uploads
class ProfilePictureService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery or camera
  static Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800, // Resize to max 800px width
        maxHeight: 800, // Resize to max 800px height
        imageQuality: 85, // Compress to 85% quality
      );
      return image;
    } catch (e) {
      AppLogger.error('Error picking image: $e');
      return null;
    }
  }

  /// Upload profile picture to Firebase Storage and update Firestore.
  ///
  /// Writes to `profile_pictures/{uid}/{timestamp}.jpg` so Storage rules can
  /// enforce that only the owner can write to their own folder. The previous
  /// picture (if any) is best-effort deleted after the new URL is persisted.
  static Future<String?> uploadProfilePicture(XFile imageFile) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final userDocRef = _firestore.collection('users').doc(user.uid);
      final previousDoc = await userDocRef.get();
      final String? previousUrl =
          previousDoc.data()?['profile_picture_url'] as String?;

      final String fileName =
          'profile_pictures/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final Reference ref = _storage.ref().child(fileName);

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        final File file = File(imageFile.path);
        uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await userDocRef.update({
        'profile_picture_url': downloadUrl,
        'profile_picture_updated_at': FieldValue.serverTimestamp(),
      });

      if (previousUrl != null && previousUrl.isNotEmpty) {
        unawaited(deleteOldProfilePicture(previousUrl));
      }

      return downloadUrl;
    } catch (e) {
      AppLogger.error('Error uploading profile picture: $e');
      rethrow;
    }
  }

  /// Delete a previously uploaded profile picture from Storage.
  ///
  /// Resolves the object path from the Firebase download URL (which contains
  /// a URL-encoded `/o/<path>` segment) rather than trying to guess the path
  /// from the filename, so nested folders like `profile_pictures/{uid}/…`
  /// still resolve correctly.
  static Future<void> deleteOldProfilePicture(String oldUrl) async {
    try {
      if (oldUrl.isEmpty) return;

      final Reference ref = _storage.refFromURL(oldUrl);
      await ref.delete();
    } catch (e) {
      AppLogger.error('Error deleting old profile picture: $e');
    }
  }

  /// Get current user's profile picture URL
  static Future<String?> getProfilePictureUrl() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      final data = doc.data();
      return data?['profile_picture_url'] as String?;
    } catch (e) {
      AppLogger.error('Error getting profile picture URL: $e');
      return null;
    }
  }

  /// Remove profile picture
  static Future<void> removeProfilePicture() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Get current profile picture URL to delete from storage
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      final String? oldUrl = data?['profile_picture_url'] as String?;

      // Delete from storage
      if (oldUrl != null && oldUrl.isNotEmpty) {
        await deleteOldProfilePicture(oldUrl);
      }

      // Remove from Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'profile_picture_url': FieldValue.delete(),
        'profile_picture_updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.error('Error removing profile picture: $e');
      rethrow;
    }
  }

  /// Show image source selection dialog (Gallery or Camera)
  static Future<ImageSource?> showImageSourceSelection() async {
    // This will be called from the UI with a dialog
    // Returning null here as placeholder
    return null;
  }
}

