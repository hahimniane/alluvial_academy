import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

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
      print('Error picking image: $e');
      return null;
    }
  }

  /// Upload profile picture to Firebase Storage and update Firestore
  static Future<String?> uploadProfilePicture(XFile imageFile) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Create a unique file name
      final String fileName = 'profile_pictures/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Upload to Firebase Storage
      final Reference ref = _storage.ref().child(fileName);
      
      UploadTask uploadTask;
      if (kIsWeb) {
        // Web upload
        final bytes = await imageFile.readAsBytes();
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // Mobile upload
        final File file = File(imageFile.path);
        uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      
      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Update Firestore user document
      await _firestore.collection('users').doc(user.uid).update({
        'profile_picture_url': downloadUrl,
        'profile_picture_updated_at': FieldValue.serverTimestamp(),
      });

      print('Profile picture uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile picture: $e');
      rethrow;
    }
  }

  /// Delete old profile picture from storage
  static Future<void> deleteOldProfilePicture(String oldUrl) async {
    try {
      if (oldUrl.isEmpty) return;
      
      // Extract file path from URL
      final Uri uri = Uri.parse(oldUrl);
      final String path = uri.pathSegments.last;
      
      // Delete from storage
      final Reference ref = _storage.ref().child('profile_pictures/$path');
      await ref.delete();
      
      print('Old profile picture deleted successfully');
    } catch (e) {
      print('Error deleting old profile picture: $e');
      // Don't throw - it's okay if old picture deletion fails
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
      print('Error getting profile picture URL: $e');
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

      print('Profile picture removed successfully');
    } catch (e) {
      print('Error removing profile picture: $e');
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

