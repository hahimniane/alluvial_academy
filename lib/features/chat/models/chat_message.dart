import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderProfilePicture;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String?
      messageType; // text, image, file, voice, video, location, system
  final Map<String, dynamic>? metadata;

  /// Raw reactions map from Firestore: {userId: emoji}
  final Map<String, String>? reactions;
  final Set<String> deletedForUserIds;
  final bool deletedForEveryone;
  final String? deletedBy;
  final String? deletedByName;
  final bool deletedByAdmin;

  /// Whether this message has been edited
  final bool isEdited;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderProfilePicture,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.messageType = 'text',
    this.metadata,
    this.reactions,
    this.deletedForUserIds = const <String>{},
    this.deletedForEveryone = false,
    this.deletedBy,
    this.deletedByName,
    this.deletedByAdmin = false,
    this.isEdited = false,
    this.editedAt,
    this.deletedAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    // Parse reactions from doc root: {userId: emoji}
    Map<String, String>? reactions;
    if (map['reactions'] != null && map['reactions'] is Map) {
      reactions = Map<String, String>.from(
        (map['reactions'] as Map)
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      );
    }

    final deletedForUserIds = map['deleted_for_users'] is Map
        ? (map['deleted_for_users'] as Map)
            .keys
            .map((key) => key.toString())
            .toSet()
        : <String>{};

    return ChatMessage(
      id: id,
      senderId: map['sender_id'] ?? '',
      senderName: map['sender_name'] ?? '',
      senderProfilePicture: map['sender_profile_picture'],
      content: map['content'] ?? '',
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['is_read'] ?? false,
      messageType: map['message_type'] ?? 'text',
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
      reactions: reactions,
      deletedForUserIds: deletedForUserIds,
      deletedForEveryone: map['deleted_for_everyone'] == true ||
          map['message_type'] == 'deleted',
      deletedBy: map['deleted_by']?.toString(),
      deletedByName: map['deleted_by_name']?.toString(),
      deletedByAdmin: map['deleted_by_admin'] == true,
      isEdited: map['is_edited'] ?? false,
      editedAt: map['edited_at'] is Timestamp
          ? (map['edited_at'] as Timestamp).toDate()
          : null,
      deletedAt: map['deleted_at'] is Timestamp
          ? (map['deleted_at'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_profile_picture': senderProfilePicture,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'is_read': isRead,
      'message_type': messageType,
      'metadata': metadata,
    };
  }

  bool get isImage => messageType == 'image';
  bool get isFile => messageType == 'file';
  bool get isVoice => messageType == 'voice';
  bool get isVideo => messageType == 'video';
  bool get isLocation => messageType == 'location';
  bool get isSystem => messageType == 'system';
  bool get isDeleted => deletedForEveryone;

  /// Whether this message has any reactions
  bool get hasReactions =>
      !deletedForEveryone && reactions != null && reactions!.isNotEmpty;

  bool isDeletedForUser(String? userId) =>
      userId != null && deletedForUserIds.contains(userId);

  /// Reactions grouped by emoji with count: {emoji: count}
  Map<String, int> get reactionCounts {
    if (reactions == null || reactions!.isEmpty) return {};
    final counts = <String, int>{};
    for (final emoji in reactions!.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts;
  }

  String? get fileUrl => metadata?['file_url'];
  String? get fileName => metadata?['file_name'];
  int? get fileSize => metadata?['file_size'];
  double? get latitude {
    final value = metadata?['latitude'];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double? get longitude {
    final value = metadata?['longitude'];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String? get locationName => metadata?['location_name']?.toString();
  String? get locationSubtitle => metadata?['location_subtitle']?.toString();
  bool get isLiveLocation => metadata?['is_live'] == true;
  int? get voiceDuration => metadata?['duration']; // Duration in seconds
  String? get voiceMimeType {
    final stored = metadata?['mime_type']?.toString().trim();
    if (stored != null && stored.isNotEmpty) return stored;

    final source = (fileName?.isNotEmpty == true ? fileName! : fileUrl ?? '')
        .toLowerCase();
    if (source.endsWith('.m4a') || source.endsWith('.mp4')) {
      return 'audio/mp4';
    }
    if (source.endsWith('.mp3')) {
      return 'audio/mpeg';
    }
    if (source.endsWith('.wav')) {
      return 'audio/wav';
    }
    if (source.endsWith('.webm')) {
      return 'audio/webm';
    }
    if (source.endsWith('.ogg') || source.endsWith('.opus')) {
      return 'audio/ogg';
    }
    if (source.endsWith('.aac')) {
      return 'audio/aac';
    }
    return null;
  }

  String get fileSizeFormatted {
    final size = fileSize;
    if (size == null) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get voiceDurationFormatted {
    final duration = voiceDuration ?? 0;
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String deletedPreviewText(String? currentUserId) {
    if (!deletedForEveryone) return content;
    if (deletedBy == currentUserId) {
      return 'You deleted this message';
    }
    if (deletedByAdmin && deletedByName != null && deletedByName!.isNotEmpty) {
      return 'This message was deleted by admin $deletedByName';
    }
    return 'This message was deleted';
  }
}
