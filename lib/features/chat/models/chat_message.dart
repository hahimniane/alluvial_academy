import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderProfilePicture;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String? messageType; // text, image, file
  final Map<String, dynamic>? metadata;

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
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
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
  String? get fileUrl => metadata?['file_url'];
  String? get fileName => metadata?['file_name'];
  int? get fileSize => metadata?['file_size'];
  int? get voiceDuration => metadata?['duration']; // Duration in seconds

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
}
