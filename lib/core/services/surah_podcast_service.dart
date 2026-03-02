import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/core/services/user_role_service.dart';

class SurahPodcastItem {
  final String podcastId;
  final int surahNumber;
  final String surahNameEn;
  final String surahNameAr;
  final String language;
  final String title;
  final String description;
  final String storagePath;
  final String downloadUrl;
  final int fileSizeBytes;
  final int durationSeconds;
  final String uploadedBy;
  final String uploadedByName;
  final String status;
  /// "audio", "video", "text", or "pdf"
  final String mediaType;
  /// For text content entries (mediaType == 'text')
  final String textContent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SurahPodcastItem({
    required this.podcastId,
    required this.surahNumber,
    required this.surahNameEn,
    required this.surahNameAr,
    required this.language,
    required this.title,
    required this.description,
    required this.storagePath,
    required this.downloadUrl,
    required this.fileSizeBytes,
    required this.durationSeconds,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.status,
    this.mediaType = 'audio',
    this.textContent = '',
    this.createdAt,
    this.updatedAt,
  });

  bool get isVideo => mediaType == 'video';
  bool get isAudio => mediaType == 'audio';
  bool get isText => mediaType == 'text';
  bool get isPdf => mediaType == 'pdf';

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedFileSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory SurahPodcastItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SurahPodcastItem(
      podcastId: doc.id,
      surahNumber: (data['surahNumber'] as num?)?.toInt() ?? 0,
      surahNameEn: data['surahNameEn']?.toString() ?? '',
      surahNameAr: data['surahNameAr']?.toString() ?? '',
      language: data['language']?.toString() ?? 'en',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      storagePath: data['storagePath']?.toString() ?? '',
      downloadUrl: data['downloadUrl']?.toString() ?? '',
      fileSizeBytes: (data['fileSizeBytes'] as num?)?.toInt() ?? 0,
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
      uploadedBy: data['uploadedBy']?.toString() ?? '',
      uploadedByName: data['uploadedByName']?.toString() ?? '',
      status: data['status']?.toString() ?? 'active',
      mediaType: data['mediaType']?.toString() ?? 'audio',
      textContent: data['textContent']?.toString() ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class PodcastAssignment {
  final String assignmentId;
  final String podcastId;
  final int surahNumber;
  final String surahNameEn;
  final String podcastTitle;
  final String teacherId;
  final String teacherName;
  final List<String> studentIds;
  final String? classId;
  final bool active;
  final DateTime? assignedAt;

  const PodcastAssignment({
    required this.assignmentId,
    required this.podcastId,
    required this.surahNumber,
    required this.surahNameEn,
    required this.podcastTitle,
    required this.teacherId,
    required this.teacherName,
    required this.studentIds,
    this.classId,
    required this.active,
    this.assignedAt,
  });

  factory PodcastAssignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PodcastAssignment(
      assignmentId: doc.id,
      podcastId: data['podcastId']?.toString() ?? '',
      surahNumber: (data['surahNumber'] as num?)?.toInt() ?? 0,
      surahNameEn: data['surahNameEn']?.toString() ?? '',
      podcastTitle: data['podcastTitle']?.toString() ?? '',
      teacherId: data['teacherId']?.toString() ?? '',
      teacherName: data['teacherName']?.toString() ?? '',
      studentIds: List<String>.from(data['studentIds'] ?? []),
      classId: data['classId']?.toString(),
      active: data['active'] == true,
      assignedAt: (data['assignedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class SurahPodcastService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const _podcastsCollection = 'surah_podcasts';
  static const _assignmentsCollection = 'podcast_assignments';

  /// Upload a podcast audio or video file and save metadata.
  /// [fileBytes] used on web, [filePath] used on mobile.
  static Future<SurahPodcastItem?> uploadPodcast({
    Uint8List? fileBytes,
    String? filePath,
    required String fileName,
    required int surahNumber,
    required String surahNameEn,
    required String surahNameAr,
    required String language,
    required String title,
    String description = '',
    required int durationSeconds,
    required int fileSizeBytes,
    String mediaType = 'audio',
    void Function(double progress)? onProgress,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final role = await UserRoleService.getCurrentUserRole();
      if (role != 'admin' && role != 'super_admin') {
        throw Exception('Only admins can upload podcasts');
      }

      final userData = await UserRoleService.getCurrentUserData();
      final uploaderName = _extractDisplayName(userData);

      final podcastId = const Uuid().v4();
      final ext = fileName.split('.').last.toLowerCase();
      final storagePath = 'surah_podcasts/${podcastId}_surah$surahNumber.$ext';

      final ref = _storage.ref().child(storagePath);
      final contentType = _mimeTypeForExtension(ext);

      UploadTask uploadTask;
      if (kIsWeb) {
        if (fileBytes == null) throw Exception('No file data provided');
        uploadTask = ref.putData(
          fileBytes,
          SettableMetadata(contentType: contentType),
        );
      } else {
        if (filePath == null) throw Exception('No file path provided');
        uploadTask = ref.putFile(
          File(filePath),
          SettableMetadata(contentType: contentType),
        );
      }

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final docData = {
        'surahNumber': surahNumber,
        'surahNameEn': surahNameEn,
        'surahNameAr': surahNameAr,
        'language': language,
        'title': title,
        'description': description,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'fileSizeBytes': fileSizeBytes,
        'durationSeconds': durationSeconds,
        'mediaType': mediaType,
        'uploadedBy': user.uid,
        'uploadedByName': uploaderName,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(_podcastsCollection)
          .doc(podcastId)
          .set(docData);

      AppLogger.info('Podcast uploaded: $podcastId for Surah $surahNumber');

      final doc = await _firestore
          .collection(_podcastsCollection)
          .doc(podcastId)
          .get();
      return SurahPodcastItem.fromFirestore(doc);
    } catch (e) {
      AppLogger.error('Error uploading podcast', error: e);
      rethrow;
    }
  }

  /// Save a text-only content entry (no file upload).
  static Future<SurahPodcastItem?> saveTextContent({
    required int surahNumber,
    required String surahNameEn,
    required String surahNameAr,
    required String language,
    required String title,
    required String textContent,
    String description = '',
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final role = await UserRoleService.getCurrentUserRole();
      if (role != 'admin' && role != 'super_admin') {
        throw Exception('Only admins can add content');
      }

      final userData = await UserRoleService.getCurrentUserData();
      final uploaderName = _extractDisplayName(userData);
      final podcastId = const Uuid().v4();

      final docData = {
        'surahNumber': surahNumber,
        'surahNameEn': surahNameEn,
        'surahNameAr': surahNameAr,
        'language': language,
        'title': title,
        'description': description,
        'textContent': textContent,
        'storagePath': '',
        'downloadUrl': '',
        'fileSizeBytes': 0,
        'durationSeconds': 0,
        'mediaType': 'text',
        'uploadedBy': user.uid,
        'uploadedByName': uploaderName,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(_podcastsCollection)
          .doc(podcastId)
          .set(docData);

      AppLogger.info('Text content saved: $podcastId for Surah $surahNumber');

      final doc = await _firestore
          .collection(_podcastsCollection)
          .doc(podcastId)
          .get();
      return SurahPodcastItem.fromFirestore(doc);
    } catch (e) {
      AppLogger.error('Error saving text content', error: e);
      rethrow;
    }
  }

  /// List all podcasts with optional filters.
  /// Always fetches from the server to ensure fresh data.
  static Future<List<SurahPodcastItem>> listPodcasts({
    int? surahNumber,
    String? language,
    String? status,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore.collection(_podcastsCollection);

      if (surahNumber != null) {
        query = query.where('surahNumber', isEqualTo: surahNumber);
      }
      if (language != null && language.isNotEmpty) {
        query = query.where('language', isEqualTo: language);
      }
      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }

      query = query.orderBy('surahNumber').limit(limit);

      final snapshot = await query.get(const GetOptions(source: Source.server));
      final items = snapshot.docs
          .map((doc) => SurahPodcastItem.fromFirestore(doc))
          .toList();
      AppLogger.info(
          'listPodcasts: got ${items.length} docs from server');
      return items;
    } catch (e) {
      AppLogger.error('listPodcasts server query failed: $e');
      // Fallback: simple query without orderBy, try server then cache
      try {
        QuerySnapshot snapshot;
        try {
          snapshot = await _firestore
              .collection(_podcastsCollection)
              .limit(limit)
              .get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await _firestore
              .collection(_podcastsCollection)
              .limit(limit)
              .get();
        }
        final items = snapshot.docs
            .map((doc) => SurahPodcastItem.fromFirestore(doc))
            .toList();
        items.sort((a, b) => a.surahNumber.compareTo(b.surahNumber));
        AppLogger.info(
            'listPodcasts fallback: got ${items.length} docs');
        return items;
      } catch (e2) {
        AppLogger.error('listPodcasts fallback also failed: $e2');
        return [];
      }
    }
  }

  /// Check if a podcast for a given surah + language already exists.
  static Future<bool> podcastExists(int surahNumber, String language) async {
    try {
      final snapshot = await _firestore
          .collection(_podcastsCollection)
          .where('surahNumber', isEqualTo: surahNumber)
          .where('language', isEqualTo: language)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Delete a podcast and all its assignments.
  static Future<void> deletePodcast(String podcastId) async {
    try {
      final doc = await _firestore
          .collection(_podcastsCollection)
          .doc(podcastId)
          .get();
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final storagePath = data['storagePath']?.toString() ?? '';

      // Delete from storage
      if (storagePath.isNotEmpty) {
        try {
          await _storage.ref().child(storagePath).delete();
        } catch (e) {
          AppLogger.error('Error deleting podcast file from storage', error: e);
        }
      }

      // Delete all assignments for this podcast
      final assignments = await _firestore
          .collection(_assignmentsCollection)
          .where('podcastId', isEqualTo: podcastId)
          .get();

      final batch = _firestore.batch();
      for (final assignDoc in assignments.docs) {
        batch.delete(assignDoc.reference);
      }
      batch.delete(
          _firestore.collection(_podcastsCollection).doc(podcastId));
      await batch.commit();

      AppLogger.info('Podcast deleted: $podcastId');
    } catch (e) {
      AppLogger.error('Error deleting podcast', error: e);
      rethrow;
    }
  }

  /// Update podcast status (active/archived).
  static Future<void> updatePodcastStatus(
      String podcastId, String status) async {
    try {
      await _firestore
          .collection(_podcastsCollection)
          .doc(podcastId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.error('Error updating podcast status', error: e);
      rethrow;
    }
  }

  /// Assign a podcast to students.
  static Future<void> assignPodcast({
    required String podcastId,
    required int surahNumber,
    required String surahNameEn,
    required String podcastTitle,
    required String teacherId,
    required String teacherName,
    required List<String> studentIds,
    String? classId,
  }) async {
    try {
      if (studentIds.isEmpty) throw Exception('No students selected');

      // Check for existing assignment by this teacher for this podcast
      final existing = await _firestore
          .collection(_assignmentsCollection)
          .where('podcastId', isEqualTo: podcastId)
          .where('teacherId', isEqualTo: teacherId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Update existing assignment with new student list
        await existing.docs.first.reference.update({
          'studentIds': studentIds,
          'classId': classId,
          'active': true,
          'assignedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection(_assignmentsCollection).add({
          'podcastId': podcastId,
          'surahNumber': surahNumber,
          'surahNameEn': surahNameEn,
          'podcastTitle': podcastTitle,
          'teacherId': teacherId,
          'teacherName': teacherName,
          'studentIds': studentIds,
          'classId': classId,
          'active': true,
          'assignedAt': FieldValue.serverTimestamp(),
        });
      }

      AppLogger.info(
          'Podcast $podcastId assigned to ${studentIds.length} students');
    } catch (e) {
      AppLogger.error('Error assigning podcast', error: e);
      rethrow;
    }
  }

  /// Unassign a podcast (set active = false).
  static Future<void> unassignPodcast(String assignmentId) async {
    try {
      await _firestore
          .collection(_assignmentsCollection)
          .doc(assignmentId)
          .update({'active': false});
    } catch (e) {
      AppLogger.error('Error unassigning podcast', error: e);
      rethrow;
    }
  }

  /// Get podcasts assigned to a specific student.
  static Future<List<SurahPodcastItem>> getAssignedPodcasts(
      String studentId) async {
    try {
      // Query assignments containing this student - avoid composite index
      // by only filtering on arrayContains, then check 'active' client-side
      QuerySnapshot assignmentSnapshot;
      try {
        assignmentSnapshot = await _firestore
            .collection(_assignmentsCollection)
            .where('studentIds', arrayContains: studentId)
            .get(const GetOptions(source: Source.server));
      } catch (_) {
        assignmentSnapshot = await _firestore
            .collection(_assignmentsCollection)
            .where('studentIds', arrayContains: studentId)
            .get();
      }

      if (assignmentSnapshot.docs.isEmpty) return [];

      final podcastIds = assignmentSnapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return data?['active'] == true;
          })
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['podcastId']?.toString() ?? '';
          })
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (podcastIds.isEmpty) return [];

      final podcasts = <SurahPodcastItem>[];
      for (var i = 0; i < podcastIds.length; i += 30) {
        final chunk = podcastIds.sublist(
            i, i + 30 > podcastIds.length ? podcastIds.length : i + 30);
        final snapshot = await _firestore
            .collection(_podcastsCollection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        podcasts.addAll(
          snapshot.docs
              .map((doc) => SurahPodcastItem.fromFirestore(doc))
              .where((p) => p.status == 'active'),
        );
      }

      podcasts.sort((a, b) => a.surahNumber.compareTo(b.surahNumber));
      AppLogger.info(
          'getAssignedPodcasts: ${podcasts.length} podcasts for student $studentId');
      return podcasts;
    } catch (e) {
      AppLogger.error('Error getting assigned podcasts: $e');
      return [];
    }
  }

  /// Get the student IDs currently assigned to a specific podcast by a teacher.
  static Future<List<String>> getAssignedStudentIds(
      String podcastId, String teacherId) async {
    try {
      final snapshot = await _firestore
          .collection(_assignmentsCollection)
          .where('podcastId', isEqualTo: podcastId)
          .where('teacherId', isEqualTo: teacherId)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return [];
      final data = snapshot.docs.first.data();
      return List<String>.from(data['studentIds'] ?? []);
    } catch (e) {
      AppLogger.error('Error getting assigned student IDs: $e');
      return [];
    }
  }

  /// Get assignments made by a teacher.
  static Future<List<PodcastAssignment>> getTeacherAssignments(
      String teacherId) async {
    try {
      final snapshot = await _firestore
          .collection(_assignmentsCollection)
          .where('teacherId', isEqualTo: teacherId)
          .where('active', isEqualTo: true)
          .get();
      final results = snapshot.docs
          .map((doc) => PodcastAssignment.fromFirestore(doc))
          .toList();
      results.sort((a, b) =>
          (b.assignedAt ?? DateTime(2000)).compareTo(a.assignedAt ?? DateTime(2000)));
      return results;
    } catch (e) {
      AppLogger.error('Error getting teacher assignments: $e');
      return [];
    }
  }

  /// Get a list of unique students from a teacher's shifts.
  static Future<List<Map<String, String>>> getStudentsForTeacher(
      String teacherId) async {
    try {
      final shiftsSnapshot = await _firestore
          .collection('teaching_shifts')
          .where('teacher_id', isEqualTo: teacherId)
          .where('status', whereIn: ['scheduled', 'active'])
          .get();

      final studentMap = <String, String>{};
      for (final doc in shiftsSnapshot.docs) {
        final data = doc.data();
        final ids = List<String>.from(data['student_ids'] ?? []);
        final names = List<String>.from(data['student_names'] ?? []);
        for (var i = 0; i < ids.length; i++) {
          if (!studentMap.containsKey(ids[i])) {
            studentMap[ids[i]] = i < names.length ? names[i] : 'Student';
          }
        }
      }

      return studentMap.entries
          .map((e) => {'id': e.key, 'name': e.value})
          .toList()
        ..sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    } catch (e) {
      AppLogger.error('Error getting students for teacher', error: e);
      return [];
    }
  }

  static String _extractDisplayName(Map<String, dynamic>? userData) {
    if (userData == null) return 'Admin';
    final first = userData['first_name'] ?? userData['firstName'] ?? '';
    final last = userData['last_name'] ?? userData['lastName'] ?? '';
    final full = '$first $last'.trim();
    return full.isNotEmpty ? full : (userData['name']?.toString() ?? 'Admin');
  }

  static String _mimeTypeForExtension(String ext) {
    switch (ext) {
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mov':
        return 'video/quicktime';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}
