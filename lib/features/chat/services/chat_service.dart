import 'dart:io' show File;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../../../core/services/user_role_service.dart';
import '../../../core/utils/presence_utils.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const Duration deleteForEveryoneWindow = Duration(days: 2);

  /// Virtual user ID for the shared admin support inbox.
  /// Non-admin users message this ID; all admins can see and respond.
  static const String adminSupportId = 'admin_support';

  String? get currentUserId => _auth.currentUser?.uid;
  String? get currentUserEmail => _auth.currentUser?.email;

  /// Whether the given ID refers to the shared admin support chat.
  static bool isAdminSupportChat(String id) => id == adminSupportId;

  /// Firestore chat document ID for admin support is `{sortedUid1}_{sortedUid2}`
  /// where one segment is exactly [adminSupportId]. Returns the real user's UID
  /// or null if [chatDocId] is not an admin-support conversation id.
  static String? humanUserIdFromAdminSupportChatDocId(String chatDocId) {
    if (chatDocId == adminSupportId) return null;
    final prefix = '${adminSupportId}_';
    if (chatDocId.startsWith(prefix)) {
      return chatDocId.substring(prefix.length);
    }
    final suffix = '_$adminSupportId';
    if (chatDocId.endsWith(suffix)) {
      return chatDocId.substring(0, chatDocId.length - suffix.length);
    }
    return null;
  }

  // Get all users for browsing (except current user)
  Stream<List<ChatUser>> getAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) => snapshot
            .docs
            .where((doc) => doc.data()['email'] != currentUserEmail)
            .map((doc) {
          final data = doc.data();
          final presence = PresenceUtils.resolvePresence(data);
          return ChatUser(
            id: doc.id,
            name:
                '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim(),
            email: data['email'] ?? data['e-mail'] ?? '',
            profilePicture:
                data['profile_picture_url'] ?? data['profile_picture'],
            role: data['user_type'],
            isOnline: presence.isOnline,
            lastSeen: presence.lastSeen,
          );
        }).toList());
  }

  // Get user's existing chats with last message info
  Stream<List<ChatUser>> getUserChats() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .asyncMap((chatSnapshot) async {
      try {
        final visibleChats = chatSnapshot.docs
            .where((doc) => _hasRecentMessage(doc.data()))
            .toList();
        final chatUsers = await _processChatSnapshot(visibleChats);

        chatUsers.sort((a, b) => (b.lastMessageTime ?? DateTime(0))
            .compareTo(a.lastMessageTime ?? DateTime(0)));

        return chatUsers;
      } catch (e) {
        AppLogger.error('Error in getUserChats: $e');
        return <ChatUser>[];
      }
    });
  }

  /// Returns a stream of all admin-support conversations (for admin users).
  /// Each conversation is shown with the non-admin user's name/details.
  Stream<List<ChatUser>> getAdminSupportChats() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: adminSupportId)
        .snapshots()
        .asyncMap((chatSnapshot) async {
      try {
        final visibleChats = chatSnapshot.docs
            .where((doc) => _includeDocInAdminSupportInbox(doc.data()))
            .toList();
        final chatUsers = await _processAdminSupportSnapshot(visibleChats);
        chatUsers.sort((a, b) => (b.lastMessageTime ?? DateTime(0))
            .compareTo(a.lastMessageTime ?? DateTime(0)));
        return chatUsers;
      } catch (e, st) {
        AppLogger.error('Error in getAdminSupportChats: $e\n$st');
        return <ChatUser>[];
      }
    });
  }

  bool _hasRecentMessage(Map<String, dynamic> chatData) {
    return chatData['last_message'] is Map;
  }

  /// Support inbox should list threads even if `last_message` on the chat doc is
  /// missing or not yet materialized — [_processAdminSupportSnapshot] can load
  /// preview from the [messages] subcollection instead.
  bool _includeDocInAdminSupportInbox(Map<String, dynamic> chatData) {
    if (_hasRecentMessage(chatData)) return true;
    return chatData['chat_type'] == 'admin_support';
  }

  Map<String, dynamic> _fallbackUserRowForSupportInbox(String userId) {
    return {
      'first_name': 'User',
      'last_name': userId.length > 10 ? '${userId.substring(0, 10)}…' : userId,
      'email': '',
      'e-mail': '',
      'user_type': null,
      'profile_picture': null,
      'profile_picture_url': null,
    };
  }

  bool _isMessageHiddenForCurrentUser(Map<String, dynamic> messageData) {
    if (currentUserId == null) return false;
    final deletedForUsers = messageData['deleted_for_users'];
    return deletedForUsers is Map && deletedForUsers.containsKey(currentUserId);
  }

  Map<String, dynamic>? _extractVisibleLastMessage(
      Map<String, dynamic> chatData) {
    final lastMessage = chatData['last_message'];
    if (lastMessage is! Map) return null;
    final messageData = Map<String, dynamic>.from(lastMessage);
    if (_isMessageHiddenForCurrentUser(messageData)) {
      return null;
    }
    return messageData;
  }

  Future<Map<String, dynamic>?> _resolveVisibleLastMessage(
    String chatId,
    Map<String, dynamic> chatData,
  ) async {
    final preferredMessage = _extractVisibleLastMessage(chatData);
    if (preferredMessage != null) {
      return preferredMessage;
    }

    final recentMessages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();

    for (final doc in recentMessages.docs) {
      final data = doc.data();
      if (!_isMessageHiddenForCurrentUser(data)) {
        return data;
      }
    }

    return null;
  }

  String _recentMessagePreview(Map<String, dynamic>? lastMessage) {
    if (lastMessage == null) return '';
    final isDeleted = lastMessage['deleted_for_everyone'] == true ||
        lastMessage['message_type'] == 'deleted';
    if (!isDeleted) {
      return lastMessage['content']?.toString() ?? '';
    }

    final deletedBy = lastMessage['deleted_by']?.toString();
    final deletedByName = lastMessage['deleted_by_name']?.toString();
    final deletedByAdmin = lastMessage['deleted_by_admin'] == true;

    if (deletedBy == currentUserId) {
      return 'You deleted this message';
    }
    if (deletedByAdmin && deletedByName != null && deletedByName.isNotEmpty) {
      return 'This message was deleted by admin $deletedByName';
    }
    return 'This message was deleted';
  }

  /// Process admin support chat docs — show the real user's name/avatar,
  /// but keep the chat ID so messages route to the correct conversation.
  Future<List<ChatUser>> _processAdminSupportSnapshot(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final allUserIds = <String>{};
    for (var chatDoc in docs) {
      final participants =
          List<String>.from(chatDoc.data()['participants'] ?? []);
      final realUserId = participants.firstWhere((id) => id != adminSupportId,
          orElse: () => '');
      if (realUserId.isNotEmpty) {
        allUserIds.add(realUserId);
      }
    }

    final usersData = await _fetchUsersDataInBatch(allUserIds);
    final chatFutures = <Future<ChatUser?>>[];

    for (var chatDoc in docs) {
      final chatData = chatDoc.data();
      final participants = List<String>.from(chatData['participants'] ?? []);
      final realUserId = participants.firstWhere((id) => id != adminSupportId,
          orElse: () => '');
      if (realUserId.isEmpty) continue;

      chatFutures.add(() async {
        final lastMessage =
            await _resolveVisibleLastMessage(chatDoc.id, chatData);
        // Admin-initiated support chats may have no messages yet — still show them.
        final unreadCount = await _getUnreadCount(chatDoc.id);
        final userRow = usersData[realUserId] ??
            _fallbackUserRowForSupportInbox(realUserId);
        return _createAdminSupportChatUser(
          chatDoc,
          realUserId,
          userRow,
          unreadCount,
          lastMessage: lastMessage,
        );
      }());
    }

    return (await Future.wait(chatFutures)).whereType<ChatUser>().toList();
  }

  /// Creates a ChatUser for an admin-support conversation, showing the real
  /// user's info but using the chat document ID for routing.
  ChatUser _createAdminSupportChatUser(DocumentSnapshot chatDoc,
      String realUserId, Map<String, dynamic> userData, int unreadCount,
      {Map<String, dynamic>? lastMessage}) {
    final chatData = chatDoc.data() as Map<String, dynamic>;
    final presence = PresenceUtils.resolvePresence(userData);

    return ChatUser(
      // Use the chat doc ID so ChatScreen routes correctly
      id: chatDoc.id,
      name: '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'
          .trim(),
      email: userData['email'] ?? userData['e-mail'] ?? '',
      profilePicture:
          userData['profile_picture_url'] ?? userData['profile_picture'],
      role: userData['user_type'],
      isOnline: presence.isOnline,
      lastSeen: presence.lastSeen,
      lastMessage: _recentMessagePreview(lastMessage),
      lastMessageTime: lastMessage != null
          ? (lastMessage['timestamp'] as Timestamp?)?.toDate()
          : (chatData['created_at'] as Timestamp?)?.toDate(),
      unreadCount: unreadCount,
      // Tag as admin support so the UI can distinguish
      isGroup: false,
    );
  }

  Future<List<ChatUser>> _processChatSnapshot(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final allUserIds = <String>{};
    final chatFutures = <Future<ChatUser?>>[];

    for (var chatDoc in docs) {
      final chatData = chatDoc.data();
      final participants = List<String>.from(chatData['participants'] ?? []);

      if (chatData['chat_type'] == 'group') {
        chatFutures.add(() async {
          final lastMessage =
              await _resolveVisibleLastMessage(chatDoc.id, chatData);
          if (lastMessage == null) return null;
          final unreadCount = await _getUnreadCount(chatDoc.id);
          return _createGroupChatUser(
            chatDoc,
            chatData,
            unreadCount,
            lastMessage: lastMessage,
          );
        }());
      } else {
        final otherUserId = participants.firstWhere((id) => id != currentUserId,
            orElse: () => '');
        if (otherUserId.isNotEmpty && otherUserId != adminSupportId) {
          allUserIds.add(otherUserId);
        }
      }
    }

    final usersData = await _fetchUsersDataInBatch(allUserIds);

    for (var chatDoc in docs) {
      final chatData = chatDoc.data();
      if (chatData['chat_type'] != 'group') {
        final participants = List<String>.from(chatData['participants'] ?? []);
        final otherUserId = participants.firstWhere((id) => id != currentUserId,
            orElse: () => '');
        // Skip admin_support chats in the normal list — they're shown separately for admins
        if (otherUserId == adminSupportId) continue;
        if (otherUserId.isNotEmpty && usersData.containsKey(otherUserId)) {
          chatFutures.add(() async {
            final lastMessage =
                await _resolveVisibleLastMessage(chatDoc.id, chatData);
            if (lastMessage == null) return null;
            final unreadCount = await _getUnreadCount(chatDoc.id);
            return _createIndividualChatUser(
              chatDoc,
              otherUserId,
              usersData[otherUserId]!,
              unreadCount,
              lastMessage: lastMessage,
            );
          }());
        }
      }
    }

    return (await Future.wait(chatFutures)).whereType<ChatUser>().toList();
  }

  Future<Map<String, Map<String, dynamic>>> _fetchUsersDataInBatch(
      Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final usersData = <String, Map<String, dynamic>>{};
    // Firestore whereIn has a limit of 30, so batch the queries
    final idList = userIds.toList();
    for (var i = 0; i < idList.length; i += 30) {
      final batch =
          idList.sublist(i, i + 30 > idList.length ? idList.length : i + 30);
      final userDocs = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (var doc in userDocs.docs) {
        usersData[doc.id] = doc.data();
      }
    }
    return usersData;
  }

  ChatUser _createGroupChatUser(
      DocumentSnapshot chatDoc, Map<String, dynamic> chatData, int unreadCount,
      {Map<String, dynamic>? lastMessage}) {
    final participants = List<String>.from(chatData['participants'] ?? []);

    return ChatUser(
      id: chatDoc.id,
      name: chatData['group_name'] ?? 'Unnamed Group',
      email: chatData['group_description'] ?? 'Group chat',
      isGroup: true,
      participants: participants,
      createdBy: chatData['created_by'],
      participantCount: participants.length,
      lastMessage: _recentMessagePreview(lastMessage),
      lastMessageTime: (lastMessage?['timestamp'] as Timestamp?)?.toDate() ??
          (chatData['created_at'] as Timestamp?)?.toDate(),
      unreadCount: unreadCount,
    );
  }

  ChatUser _createIndividualChatUser(DocumentSnapshot chatDoc, String userId,
      Map<String, dynamic> userData, int unreadCount,
      {Map<String, dynamic>? lastMessage}) {
    final chatData = chatDoc.data() as Map<String, dynamic>;
    final presence = PresenceUtils.resolvePresence(userData);

    return ChatUser(
      id: userId,
      name: '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'
          .trim(),
      email: userData['email'] ?? userData['e-mail'] ?? '',
      profilePicture:
          userData['profile_picture_url'] ?? userData['profile_picture'],
      role: userData['user_type'],
      isOnline: presence.isOnline,
      lastSeen: presence.lastSeen,
      lastMessage: _recentMessagePreview(lastMessage),
      lastMessageTime: lastMessage != null
          ? (lastMessage['timestamp'] as Timestamp?)?.toDate()
          : (chatData['created_at'] as Timestamp?)
              ?.toDate(), // Use creation time if no messages yet
      unreadCount: unreadCount,
    );
  }

  // Get messages for a specific chat (handles both individual and group chats)
  Stream<List<ChatMessage>> getChatMessages(String chatIdOrUserId,
      {bool isGroupChat = false}) {
    if (currentUserId == null) return Stream.value([]);

    String chatId;
    // Check if this is already a generated chat ID (contains underscore)
    // or explicitly marked as a group chat
    // or a user ID for individual chats
    if (chatIdOrUserId.contains('_')) {
      // Already a generated chat ID for individual chat
      chatId = chatIdOrUserId;
    } else if (isGroupChat) {
      // Explicitly marked as group chat - use the provided Firestore document ID
      chatId = chatIdOrUserId;
    } else {
      // Individual chat - generate chat ID from user ID
      // This ensures we only get messages between current user and the selected user
      chatId = _generateChatId(currentUserId!, chatIdOrUserId);
    }

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
            .where((message) => !message.isDeletedForUser(currentUserId))
            .toList());
  }

  // Create or get a chat conversation (ensures chat appears in Recent Chats immediately)
  Future<String> getOrCreateIndividualChat(String otherUserId) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final chatId = _generateChatId(currentUserId!, otherUserId);
    final chatDocRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatDocRef.get();

    if (!chatDoc.exists) {
      // Create the chat document so it appears in Recent Chats
      await chatDocRef.set({
        'participants': [currentUserId, otherUserId],
        'chat_type': 'individual',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        // Don't add last_message yet - it will be added when first message is sent
      });
    }

    return chatId;
  }

  /// Create or get the admin support chat for the current (non-admin) user.
  /// The chat document uses participants: [userId, 'admin_support'].
  Future<String> getOrCreateAdminSupportChat() async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final chatId = _generateChatId(currentUserId!, adminSupportId);
    final chatDocRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatDocRef.get();

    if (!chatDoc.exists) {
      await chatDocRef.set({
        'participants': [currentUserId, adminSupportId],
        'chat_type': 'admin_support',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } else {
      // Repair docs created by older code with corrupted participants.
      final data = chatDoc.data()!;
      final participants = List<String>.from(data['participants'] ?? []);
      if (!participants.contains(adminSupportId) || data['chat_type'] != 'admin_support') {
        await chatDocRef.update({
          'participants': [currentUserId, adminSupportId],
          'chat_type': 'admin_support',
        });
      }
    }

    return chatId;
  }

  // Send a message (handles both individual and group chats)
  Future<void> sendMessage(String chatIdOrUserId, String content,
      {String messageType = 'text',
      Map<String, dynamic>? metadata,
      bool isGroupChat = false}) async {
    if (currentUserId == null) return;

    String chatId;

    // Check if this is already a generated chat ID or explicitly a group chat
    if (chatIdOrUserId.contains('_')) {
      chatId = chatIdOrUserId;
    } else if (isGroupChat) {
      chatId = chatIdOrUserId;
    } else {
      chatId = _generateChatId(currentUserId!, chatIdOrUserId);
    }

    final currentUserDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final currentUserData = currentUserDoc.data() ?? {};
    final senderName =
        '${currentUserData['first_name'] ?? ''} ${currentUserData['last_name'] ?? ''}'
            .trim();
    final senderProfilePicture = currentUserData['profile_picture'];

    final messageData = ChatMessage(
      id: '',
      senderId: currentUserId!,
      senderName:
          senderName.isNotEmpty ? senderName : currentUserEmail ?? 'Unknown',
      senderProfilePicture: senderProfilePicture,
      content: content,
      timestamp: DateTime.now(),
      messageType: messageType,
      metadata: metadata,
    ).toMap();

    final chatDocRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatDocRef.get();

    if (!chatDoc.exists) {
      if (isGroupChat) {
        await chatDocRef.collection('messages').add(messageData);
        return;
      } else {
        final supportHumanId =
            ChatService.humanUserIdFromAdminSupportChatDocId(chatId);
        if (supportHumanId != null) {
          // Composite id was passed (e.g. from ChatScreen admin support). Must
          // store literal admin_support in participants or Support Inbox misses it.
          await chatDocRef.set({
            'participants': [supportHumanId, adminSupportId],
            'chat_type': 'admin_support',
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
            'last_message': messageData,
          });
        } else {
          await chatDocRef.set({
            'participants': [currentUserId, chatIdOrUserId],
            'chat_type': 'individual',
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
            'last_message': messageData,
          });
        }
      }
    } else {
      await chatDocRef.update({
        'updated_at': FieldValue.serverTimestamp(),
        'last_message': messageData,
      });
    }

    await chatDocRef.collection('messages').add(messageData);
  }

  /// Upload an image and send as a message
  Future<void> sendImageMessage(String chatIdOrUserId, XFile imageFile,
      {bool isGroupChat = false, String? caption}) async {
    if (currentUserId == null) return;

    try {
      final bytes = await imageFile.readAsBytes();
      final ext = imageFile.name.split('.').last.toLowerCase();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(currentUserId!)
          .child(fileName);

      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$ext'),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      final fileSize = bytes.length;

      final displayText = caption != null && caption.trim().isNotEmpty
          ? caption.trim()
          : '📷 Photo';

      await sendMessage(
        chatIdOrUserId,
        displayText,
        messageType: 'image',
        metadata: {
          'file_url': downloadUrl,
          'file_name': fileName,
          'file_size': fileSize,
          'mime_type': 'image/$ext',
          if (caption != null && caption.trim().isNotEmpty)
            'caption': caption.trim(),
        },
        isGroupChat: isGroupChat,
      );
    } catch (e) {
      AppLogger.error('Error sending image message: $e');
      rethrow;
    }
  }

  /// Upload a file and send as a message
  Future<void> sendFileMessage(
      String chatIdOrUserId, Uint8List bytes, String originalFileName,
      {bool isGroupChat = false}) async {
    if (currentUserId == null) return;

    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$originalFileName';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_files')
          .child(currentUserId!)
          .child(fileName);

      final uploadTask = await ref.putData(bytes);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      final fileSize = bytes.length;

      await sendMessage(
        chatIdOrUserId,
        '📎 $originalFileName',
        messageType: 'file',
        metadata: {
          'file_url': downloadUrl,
          'file_name': originalFileName,
          'file_size': fileSize,
        },
        isGroupChat: isGroupChat,
      );
    } catch (e) {
      AppLogger.error('Error sending file message: $e');
      rethrow;
    }
  }

  /// Upload a voice message and send
  Future<void> sendVoiceMessage(
      String chatIdOrUserId, File audioFile, int durationSeconds,
      {bool isGroupChat = false}) async {
    if (currentUserId == null) return;

    try {
      final extension = _extractFileExtension(audioFile.path);
      final mimeType = _audioMimeTypeForExtension(extension);
      final fileName =
          'voice_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_voice')
          .child(currentUserId!)
          .child(fileName);

      final uploadTask = await ref.putFile(
        audioFile,
        SettableMetadata(contentType: mimeType),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      final fileSize = await audioFile.length();

      await sendMessage(
        chatIdOrUserId,
        '🎤 Voice message',
        messageType: 'voice',
        metadata: {
          'file_url': downloadUrl,
          'file_name': fileName,
          'file_size': fileSize,
          'duration': durationSeconds,
          'mime_type': mimeType,
        },
        isGroupChat: isGroupChat,
      );
    } catch (e) {
      AppLogger.error('Error sending voice message: $e');
      rethrow;
    }
  }

  /// Upload a video and send as a message
  Future<void> sendVideoMessage(String chatIdOrUserId, XFile videoFile,
      {bool isGroupChat = false, String? caption}) async {
    if (currentUserId == null) return;

    try {
      final bytes = await videoFile.readAsBytes();
      final ext = videoFile.name.split('.').last.toLowerCase();
      final mimeType = 'video/$ext';
      final fileName =
          'video_${DateTime.now().millisecondsSinceEpoch}_${videoFile.name}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_videos')
          .child(currentUserId!)
          .child(fileName);

      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: mimeType),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      final fileSize = bytes.length;

      final displayText = caption != null && caption.trim().isNotEmpty
          ? caption.trim()
          : '🎥 Video';

      await sendMessage(
        chatIdOrUserId,
        displayText,
        messageType: 'video',
        metadata: {
          'file_url': downloadUrl,
          'file_name': fileName,
          'file_size': fileSize,
          'mime_type': mimeType,
          if (caption != null && caption.trim().isNotEmpty)
            'caption': caption.trim(),
        },
        isGroupChat: isGroupChat,
      );
    } catch (e) {
      AppLogger.error('Error sending video message: $e');
      rethrow;
    }
  }

  /// Edit a message's text content (WhatsApp-style)
  Future<bool> editMessage(
      String chatIdOrUserId, String messageId, String newContent,
      {bool isGroupChat = false}) async {
    if (currentUserId == null) return false;

    try {
      final chatId = isGroupChat || chatIdOrUserId.contains('_')
          ? chatIdOrUserId
          : _generateChatId(currentUserId!, chatIdOrUserId);

      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      // Verify the message belongs to the current user
      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) return false;
      final data = messageDoc.data()!;
      if (data['sender_id'] != currentUserId) return false;
      if (data['deleted_for_everyone'] == true ||
          data['message_type'] == 'deleted') {
        return false;
      }

      await messageRef.update({
        'content': newContent,
        'is_edited': true,
        'edited_at': FieldValue.serverTimestamp(),
      });

      // Also update last_message on the chat doc if this was the latest message
      final chatDocRef = _firestore.collection('chats').doc(chatId);
      final chatDoc = await chatDocRef.get();
      if (chatDoc.exists) {
        final chatData = chatDoc.data()!;
        final lastMessage = chatData['last_message'] as Map<String, dynamic>?;
        if (lastMessage != null && lastMessage['sender_id'] == currentUserId) {
          await chatDocRef.update({
            'last_message.content': newContent,
          });
        }
      }

      return true;
    } catch (e) {
      AppLogger.error('Error editing message: $e');
      return false;
    }
  }

  /// Create an admin-support chat for a specific user (admin-initiated).
  Future<String> getOrCreateAdminSupportChatForUser(String userId) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final chatId = _generateChatId(userId, adminSupportId);
    final chatDocRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatDocRef.get();

    if (!chatDoc.exists) {
      await chatDocRef.set({
        'participants': [userId, adminSupportId],
        'chat_type': 'admin_support',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } else {
      // Repair docs created by older code that stored the chat doc ID as a participant
      // instead of the literal 'admin_support' string.
      final data = chatDoc.data()!;
      final participants = List<String>.from(data['participants'] ?? []);
      final needsRepair = !participants.contains(adminSupportId) ||
          data['chat_type'] != 'admin_support';
      if (needsRepair) {
        AppLogger.error('[SupportChat] Repairing corrupted doc: $chatId old participants=$participants');
        await chatDocRef.update({
          'participants': [userId, adminSupportId],
          'chat_type': 'admin_support',
        });
        AppLogger.error('[SupportChat] Repaired: $chatId');
      }
    }

    return chatId;
  }

  String _extractFileExtension(String filePath) {
    final fileName = filePath.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return 'm4a';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  String _audioMimeTypeForExtension(String extension) {
    switch (extension) {
      case 'webm':
        return 'audio/webm';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
      case 'mp4':
      default:
        return 'audio/mp4';
    }
  }

  // Create a group chat (admin only)
  Future<String?> createGroupChat(
      String groupName, List<String> participantIds, String description) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      AppLogger.debug(
          'ChatService: Creating group chat - Name: $groupName, Participants: ${participantIds.length}');

      // Use UserRoleService to get the current active role (respects role switching)
      final userRole = await UserRoleService.getCurrentUserRole();

      AppLogger.debug('ChatService: Current user active role: $userRole');

      // Also check the actual Firestore document for debugging
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      if (currentUserDoc.exists) {
        final userData = currentUserDoc.data() ?? {};
        AppLogger.debug(
            'ChatService: User document data - user_type: ${userData['user_type']}, is_admin_teacher: ${userData['is_admin_teacher']}');
        AppLogger.debug('ChatService: User UID: $currentUserId');
      } else {
        AppLogger.error(
            'ChatService: ERROR - User document does not exist for UID: $currentUserId');
      }

      // Check if user is admin
      if (userRole?.toLowerCase() != 'admin') {
        throw Exception(
            'Only administrators can create group chats. Current role: $userRole');
      }

      // Add current user to participants if not already included
      if (!participantIds.contains(currentUserId)) {
        participantIds.add(currentUserId!);
      }

      AppLogger.debug('ChatService: Final participants list: $participantIds');

      final groupDoc = await _firestore.collection('chats').add({
        'chat_type': 'group',
        'group_name': groupName,
        'group_description': description,
        'participants': participantIds,
        'admin_ids': [currentUserId],
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'created_by': currentUserId,
      });

      AppLogger.error(
          'ChatService: Group created successfully with ID: ${groupDoc.id}');

      final creatorName = await _getUserDisplayName(currentUserId!);
      await _sendSystemMessage(groupDoc.id, '$creatorName created this group');

      return groupDoc.id;
    } catch (e) {
      AppLogger.error('ChatService: Error creating group chat: $e');
      // Re-throw the exception instead of silently returning null
      rethrow;
    }
  }

  // Get group chats
  Stream<List<Map<String, dynamic>>> getGroupChats() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .where('chat_type', isEqualTo: 'group')
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<void> _sendSystemMessage(String groupChatId, String content) async {
    final messageData = {
      'sender_id': 'system',
      'sender_name': '',
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'is_read': false,
      'message_type': 'system',
    };

    final chatDocRef = _firestore.collection('chats').doc(groupChatId);
    await chatDocRef.collection('messages').add(messageData);
    await chatDocRef.update({
      'updated_at': FieldValue.serverTimestamp(),
      'last_message': messageData,
    });
  }

  Future<String> _getUserDisplayName(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return 'Unknown';
      final data = doc.data()!;
      final name =
          '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
      return name.isNotEmpty ? name : (data['email'] ?? 'Unknown');
    } catch (_) {
      return 'Unknown';
    }
  }

  // Add members to an existing group (admin only)
  Future<bool> addMembersToGroup(
      String groupChatId, List<String> newMemberIds) async {
    if (currentUserId == null) return false;

    try {
      final groupDoc =
          await _firestore.collection('chats').doc(groupChatId).get();
      if (!groupDoc.exists) return false;

      final groupData = groupDoc.data()!;
      final adminIds = List<String>.from(groupData['admin_ids'] ?? []);
      final currentParticipants =
          List<String>.from(groupData['participants'] ?? []);

      if (!adminIds.contains(currentUserId) && !(await _isAppAdmin())) {
        throw Exception('Only group administrators can add members');
      }

      final membersToAdd = newMemberIds
          .where((id) => !currentParticipants.contains(id))
          .toList();

      if (membersToAdd.isEmpty) return true;

      await _firestore.collection('chats').doc(groupChatId).update({
        'participants': FieldValue.arrayUnion(membersToAdd),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Send system messages for added members
      final adderName = await _getUserDisplayName(currentUserId!);
      for (final memberId in membersToAdd) {
        final memberName = await _getUserDisplayName(memberId);
        await _sendSystemMessage(groupChatId, '$adderName added $memberName');
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get group details
  Future<Map<String, dynamic>?> getGroupDetails(String groupChatId) async {
    try {
      final groupDoc =
          await _firestore.collection('chats').doc(groupChatId).get();
      if (!groupDoc.exists) return null;

      return {'id': groupDoc.id, ...groupDoc.data()!};
    } catch (e) {
      return null;
    }
  }

  // Check if current user is admin of a group
  Future<bool> isGroupAdmin(String groupChatId) async {
    if (currentUserId == null) return false;

    try {
      final groupDoc =
          await _firestore.collection('chats').doc(groupChatId).get();
      if (!groupDoc.exists) return false;

      final groupData = groupDoc.data()!;
      final adminIds = List<String>.from(groupData['admin_ids'] ?? []);

      // Group-level admin OR app-level admin
      if (adminIds.contains(currentUserId)) return true;
      return await _isAppAdmin();
    } catch (e) {
      return false;
    }
  }

  /// Check if the current user is an app-level administrator.
  Future<bool> _isAppAdmin() async {
    if (currentUserId == null) return false;
    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      if (!userDoc.exists) return false;
      final userType = userDoc.data()?['user_type'] as String?;
      return userType == 'admin';
    } catch (e) {
      return false;
    }
  }

  // Update group info (name and/or description) - admin only
  Future<bool> updateGroupInfo(String groupChatId,
      {String? name, String? description}) async {
    if (currentUserId == null) return false;

    try {
      // Check if current user is admin of the group
      final groupDoc =
          await _firestore.collection('chats').doc(groupChatId).get();
      if (!groupDoc.exists) return false;

      final groupData = groupDoc.data()!;
      final adminIds = List<String>.from(groupData['admin_ids'] ?? []);

      if (!adminIds.contains(currentUserId) && !(await _isAppAdmin())) {
        throw Exception('Only group administrators can edit group info');
      }

      final updates = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (name != null && name.trim().isNotEmpty) {
        updates['group_name'] = name.trim();
      }
      if (description != null) {
        updates['group_description'] = description.trim();
      }

      await _firestore.collection('chats').doc(groupChatId).update(updates);
      return true;
    } catch (e) {
      AppLogger.error('Error updating group info: $e');
      return false;
    }
  }

  // Remove a member from group - admin only
  Future<bool> removeMemberFromGroup(
      String groupChatId, String memberId) async {
    if (currentUserId == null) return false;

    try {
      final groupDoc =
          await _firestore.collection('chats').doc(groupChatId).get();
      if (!groupDoc.exists) return false;

      final groupData = groupDoc.data()!;
      final adminIds = List<String>.from(groupData['admin_ids'] ?? []);
      final participants = List<String>.from(groupData['participants'] ?? []);

      // Check if current user is group admin or app-level admin
      final isAppLevelAdmin = await _isAppAdmin();
      if (!adminIds.contains(currentUserId) && !isAppLevelAdmin) {
        throw Exception('Only group administrators can remove members');
      }

      // Cannot remove yourself as admin (use leaveGroup instead)
      if (memberId == currentUserId) {
        throw Exception(
            'Admins cannot remove themselves. Use leave group instead.');
      }

      // Cannot remove another admin (they must leave voluntarily)
      if (adminIds.contains(memberId)) {
        throw Exception('Cannot remove another admin from the group');
      }

      // Remove member from participants
      if (!participants.contains(memberId)) {
        return true; // Already not in group
      }

      await _firestore.collection('chats').doc(groupChatId).update({
        'participants': FieldValue.arrayRemove([memberId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      final removerName = await _getUserDisplayName(currentUserId!);
      final removedName = await _getUserDisplayName(memberId);
      await _sendSystemMessage(
          groupChatId, '$removerName removed $removedName');

      return true;
    } catch (e) {
      AppLogger.error('Error removing member from group: $e');
      return false;
    }
  }

  // Leave a group - any member can leave
  Future<bool> leaveGroup(String groupChatId) async {
    if (currentUserId == null) return false;

    try {
      final groupDoc =
          await _firestore.collection('chats').doc(groupChatId).get();
      if (!groupDoc.exists) return false;

      final groupData = groupDoc.data()!;
      final adminIds = List<String>.from(groupData['admin_ids'] ?? []);
      final participants = List<String>.from(groupData['participants'] ?? []);

      // Check if user is in the group
      if (!participants.contains(currentUserId)) {
        return true; // Already not in group
      }

      // If user is the only admin and there are other members, transfer admin or prevent leaving
      if (adminIds.contains(currentUserId) &&
          adminIds.length == 1 &&
          participants.length > 1) {
        // Find another participant to make admin
        final newAdmin = participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );

        if (newAdmin.isNotEmpty) {
          await _firestore.collection('chats').doc(groupChatId).update({
            'admin_ids': FieldValue.arrayUnion([newAdmin]),
          });
        }
      }

      final leaverName = await _getUserDisplayName(currentUserId!);

      // Remove from participants and admin_ids
      await _firestore.collection('chats').doc(groupChatId).update({
        'participants': FieldValue.arrayRemove([currentUserId]),
        'admin_ids': FieldValue.arrayRemove([currentUserId]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _sendSystemMessage(groupChatId, '$leaverName left');

      // If no participants left, delete the group
      final updatedDoc =
          await _firestore.collection('chats').doc(groupChatId).get();
      if (updatedDoc.exists) {
        final updatedParticipants =
            List<String>.from(updatedDoc.data()!['participants'] ?? []);
        if (updatedParticipants.isEmpty) {
          await _firestore.collection('chats').doc(groupChatId).delete();
        }
      }

      return true;
    } catch (e) {
      AppLogger.error('Error leaving group: $e');
      return false;
    }
  }

  // Get group members with their details
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupChatId) async {
    try {
      final groupDoc =
          await _firestore.collection('chats').doc(groupChatId).get();
      if (!groupDoc.exists) return [];

      final groupData = groupDoc.data()!;
      final participants = List<String>.from(groupData['participants'] ?? []);
      final adminIds = List<String>.from(groupData['admin_ids'] ?? []);
      final createdBy = groupData['created_by'] as String?;

      if (participants.isEmpty) return [];

      // Fetch user details in batches of 10 (Firestore whereIn limit)
      final members = <Map<String, dynamic>>[];

      for (var i = 0; i < participants.length; i += 10) {
        final batch = participants.skip(i).take(10).toList();
        final userDocs = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (var doc in userDocs.docs) {
          final data = doc.data();
          final presence = PresenceUtils.resolvePresence(data);
          members.add({
            'id': doc.id,
            'name':
                '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim(),
            'email': data['email'] ?? data['e-mail'] ?? '',
            'profilePicture':
                data['profile_picture_url'] ?? data['profile_picture'],
            'role': data['user_type'],
            'isOnline': presence.isOnline,
            'isAdmin': adminIds.contains(doc.id),
            'isCreator': doc.id == createdBy,
          });
        }
      }

      // Sort: creator first, then admins, then others
      members.sort((a, b) {
        if (a['isCreator'] == true) return -1;
        if (b['isCreator'] == true) return 1;
        if (a['isAdmin'] == true && b['isAdmin'] != true) return -1;
        if (b['isAdmin'] == true && a['isAdmin'] != true) return 1;
        return (a['name'] as String).compareTo(b['name'] as String);
      });

      return members;
    } catch (e) {
      AppLogger.error('Error getting group members: $e');
      return [];
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatIdOrUserId,
      {bool isGroupChat = false, bool isAdminSupportChat = false}) async {
    if (currentUserId == null) return;

    final String chatId;
    if (isGroupChat || isAdminSupportChat) {
      chatId = chatIdOrUserId;
    } else if (chatIdOrUserId.contains('_')) {
      chatId = chatIdOrUserId;
    } else {
      chatId = _generateChatId(currentUserId!, chatIdOrUserId);
    }
    // Get all messages and filter in client to avoid compound index requirement
    final messagesQuery = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('is_read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in messagesQuery.docs) {
      final data = doc.data();
      // Filter out current user's messages in client
      if (data['sender_id'] != currentUserId &&
          !_isMessageHiddenForCurrentUser(data)) {
        batch.update(doc.reference, {'is_read': true});
      }
    }
    await batch.commit();

    // Touch the chat doc so chat list listeners refresh unread counts.
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'last_read_by.$currentUserId': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Ignore if chat doc is missing or update fails.
    }
  }

  // Helper methods
  String _generateChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  Future<int> _getUnreadCount(String chatId) async {
    if (currentUserId == null) return 0;

    // Get unread messages and filter in client to avoid compound index requirement
    final unreadQuery = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('is_read', isEqualTo: false)
        .get();

    // Count messages not sent by current user
    int count = 0;
    for (var doc in unreadQuery.docs) {
      final data = doc.data();
      if (data['sender_id'] != currentUserId &&
          !_isMessageHiddenForCurrentUser(data)) {
        count++;
      }
    }
    return count;
  }

  Future<void> _touchChatVisibility(String chatId) async {
    if (currentUserId == null) return;
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'visibility_updated_at.$currentUserId': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Ignore missing chat docs or transient refresh failures.
    }
  }

  Future<void> _refreshLastMessage(String chatId) async {
    final latestMessage = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (latestMessage.docs.isNotEmpty) {
      await _firestore.collection('chats').doc(chatId).update({
        'last_message': latestMessage.docs.first.data(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } else {
      await _firestore.collection('chats').doc(chatId).update({
        'last_message': FieldValue.delete(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  bool isWithinDeleteForEveryoneWindow(DateTime timestamp) {
    return DateTime.now().difference(timestamp) <= deleteForEveryoneWindow;
  }

  bool _isUserOnline(dynamic lastLogin) {
    if (lastLogin == null) return false;
    try {
      DateTime lastLoginTime;
      if (lastLogin is Timestamp) {
        lastLoginTime = lastLogin.toDate();
      } else if (lastLogin is String) {
        lastLoginTime = DateTime.parse(lastLogin);
      } else {
        return false;
      }
      return DateTime.now().difference(lastLoginTime).inMinutes < 5;
    } catch (e) {
      return false;
    }
  }

  // Helper method to get user names by IDs
  Future<Map<String, String>> getUserNames(List<String> userIds) async {
    if (userIds.isEmpty) return {};

    try {
      AppLogger.debug('ChatService: getUserNames called with IDs: $userIds');

      final userDocs = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIds)
          .get();

      AppLogger.debug(
          'ChatService: Found ${userDocs.docs.length} user documents');

      final userNames = <String, String>{};
      for (var doc in userDocs.docs) {
        final data = doc.data();
        final firstName = data['first_name'] ?? '';
        final lastName = data['last_name'] ?? '';
        final email = data['email'] ?? data['e-mail'] ?? '';
        final fullName = '$firstName $lastName'.trim();
        final displayName = fullName.isNotEmpty
            ? fullName
            : (email.isNotEmpty ? email : 'Unknown User');

        userNames[doc.id] = displayName;
        AppLogger.debug(
            'ChatService: User ${doc.id} -> $displayName (firstName: $firstName, lastName: $lastName, email: $email)');
      }

      AppLogger.error('ChatService: Final userNames map: $userNames');
      return userNames;
    } catch (e) {
      AppLogger.error('Error fetching user names: $e');
      return {};
    }
  }

  // ============ MESSAGE OPERATIONS ============

  /// Delete a message for the current user only.
  Future<bool> deleteMessageForMe(String chatIdOrUserId, String messageId,
      {bool isGroupChat = false}) async {
    if (currentUserId == null) return false;

    try {
      final chatId = isGroupChat || chatIdOrUserId.contains('_')
          ? chatIdOrUserId
          : _generateChatId(currentUserId!, chatIdOrUserId);

      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) return false;
      await messageRef.update({
        'deleted_for_users.$currentUserId': true,
      });
      await _touchChatVisibility(chatId);

      return true;
    } catch (e) {
      AppLogger.error('Error deleting message for me: $e');
      return false;
    }
  }

  Future<bool> restoreDeletedMessageForMe(
      String chatIdOrUserId, String messageId,
      {bool isGroupChat = false}) async {
    if (currentUserId == null) return false;

    try {
      final chatId = isGroupChat || chatIdOrUserId.contains('_')
          ? chatIdOrUserId
          : _generateChatId(currentUserId!, chatIdOrUserId);

      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) return false;

      await messageRef.update({
        'deleted_for_users.$currentUserId': FieldValue.delete(),
      });
      await _touchChatVisibility(chatId);

      return true;
    } catch (e) {
      AppLogger.error('Error restoring deleted message for me: $e');
      return false;
    }
  }

  /// Delete a message for everyone using a WhatsApp-style placeholder.
  Future<bool> deleteMessage(String chatIdOrUserId, String messageId,
      {bool isGroupChat = false}) async {
    if (currentUserId == null) return false;

    try {
      final chatId = isGroupChat || chatIdOrUserId.contains('_')
          ? chatIdOrUserId
          : _generateChatId(currentUserId!, chatIdOrUserId);

      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) return false;

      final messageData = messageDoc.data()!;
      final senderId = messageData['sender_id']?.toString();
      final isSender = senderId == currentUserId;
      final isDeleted = messageData['deleted_for_everyone'] == true ||
          messageData['message_type'] == 'deleted';
      if (isDeleted) return false;

      final timestamp = messageData['timestamp'] is Timestamp
          ? (messageData['timestamp'] as Timestamp).toDate()
          : null;
      if (timestamp == null || !isWithinDeleteForEveryoneWindow(timestamp)) {
        return false;
      }

      bool isAdminDeletingOthers = false;
      if (!isSender) {
        if (!isGroupChat) {
          return false;
        }
        final isAdmin = await isGroupAdmin(chatId);
        if (!isAdmin) {
          return false;
        }
        isAdminDeletingOthers = true;
      }

      await messageRef.update({
        'content': '',
        'message_type': 'deleted',
        'metadata': <String, dynamic>{},
        'reactions': <String, dynamic>{},
        'is_edited': false,
        'edited_at': FieldValue.delete(),
        'deleted_for_everyone': true,
        'deleted_by': currentUserId,
        'deleted_by_name': await _getUserDisplayName(currentUserId!),
        'deleted_by_admin': isAdminDeletingOthers,
        'deleted_at': FieldValue.serverTimestamp(),
      });

      await _refreshLastMessage(chatId);

      return true;
    } catch (e) {
      AppLogger.error('Error deleting message for everyone: $e');
      return false;
    }
  }

  /// Forward a message to another chat
  Future<bool> forwardMessage(ChatMessage message, String targetChatIdOrUserId,
      {bool isTargetGroupChat = false}) async {
    if (currentUserId == null) return false;

    try {
      // Create forwarded message content
      String content = message.content;
      Map<String, dynamic>? metadata = message.metadata != null
          ? Map<String, dynamic>.from(message.metadata!)
          : null;

      // Add forwarded flag to metadata
      metadata ??= {};
      metadata['forwarded'] = true;
      metadata['original_sender'] = message.senderName;

      await sendMessage(
        targetChatIdOrUserId,
        content,
        messageType: message.messageType ?? 'text',
        metadata: metadata,
        isGroupChat: isTargetGroupChat,
      );

      return true;
    } catch (e) {
      AppLogger.error('Error forwarding message: $e');
      return false;
    }
  }

  /// Add a reaction to a message
  Future<bool> addReaction(
      String chatIdOrUserId, String messageId, String reaction,
      {bool isGroupChat = false}) async {
    if (currentUserId == null) return false;

    try {
      final chatId = isGroupChat || chatIdOrUserId.contains('_')
          ? chatIdOrUserId
          : _generateChatId(currentUserId!, chatIdOrUserId);

      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) return false;
      final messageData = messageDoc.data()!;
      if (messageData['deleted_for_everyone'] == true ||
          messageData['message_type'] == 'deleted') {
        return false;
      }

      // Add reaction (user can only have one reaction per message)
      await messageRef.update({
        'reactions.$currentUserId': reaction,
      });

      return true;
    } catch (e) {
      AppLogger.error('Error adding reaction: $e');
      return false;
    }
  }

  /// Remove a reaction from a message
  Future<bool> removeReaction(String chatIdOrUserId, String messageId,
      {bool isGroupChat = false}) async {
    if (currentUserId == null) return false;

    try {
      final chatId = isGroupChat || chatIdOrUserId.contains('_')
          ? chatIdOrUserId
          : _generateChatId(currentUserId!, chatIdOrUserId);

      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) return false;
      final messageData = messageDoc.data()!;
      if (messageData['deleted_for_everyone'] == true ||
          messageData['message_type'] == 'deleted') {
        return false;
      }

      await messageRef.update({
        'reactions.$currentUserId': FieldValue.delete(),
      });

      return true;
    } catch (e) {
      AppLogger.error('Error removing reaction: $e');
      return false;
    }
  }

  /// Clear all messages in a chat (deletes all messages)
  Future<bool> clearChat(String chatIdOrUserId,
      {bool isGroupChat = false}) async {
    if (currentUserId == null) return false;

    try {
      final chatId = isGroupChat || chatIdOrUserId.contains('_')
          ? chatIdOrUserId
          : _generateChatId(currentUserId!, chatIdOrUserId);

      // Get all messages
      final messagesQuery = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      // Delete in batches of 500 (Firestore batch limit)
      final batch = _firestore.batch();
      int count = 0;

      for (final doc in messagesQuery.docs) {
        batch.delete(doc.reference);
        count++;

        if (count >= 500) {
          await batch.commit();
          count = 0;
        }
      }

      if (count > 0) {
        await batch.commit();
      }

      // Clear last_message from chat document
      await _firestore.collection('chats').doc(chatId).update({
        'last_message': FieldValue.delete(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      AppLogger.error('Error clearing chat: $e');
      return false;
    }
  }

  /// Send a location message
  Future<void> sendLocationMessage(String chatIdOrUserId, double latitude,
      double longitude, String? locationName,
      {String? locationSubtitle, bool isGroupChat = false}) async {
    if (currentUserId == null) return;

    try {
      final displayName = locationName ?? 'Shared Location';

      await sendMessage(
        chatIdOrUserId,
        displayName,
        messageType: 'location',
        metadata: {
          'latitude': latitude,
          'longitude': longitude,
          'location_name': locationName,
          'location_subtitle': locationSubtitle,
        },
        isGroupChat: isGroupChat,
      );
    } catch (e) {
      AppLogger.error('Error sending location message: $e');
      rethrow;
    }
  }

  // ============ BLOCK USER OPERATIONS ============

  /// Block a user
  Future<bool> blockUser(String userIdToBlock) async {
    if (currentUserId == null) return false;

    try {
      await _firestore.collection('users').doc(currentUserId).update({
        'blocked_users': FieldValue.arrayUnion([userIdToBlock]),
      });
      return true;
    } catch (e) {
      AppLogger.error('Error blocking user: $e');
      return false;
    }
  }

  /// Unblock a user
  Future<bool> unblockUser(String userIdToUnblock) async {
    if (currentUserId == null) return false;

    try {
      await _firestore.collection('users').doc(currentUserId).update({
        'blocked_users': FieldValue.arrayRemove([userIdToUnblock]),
      });
      return true;
    } catch (e) {
      AppLogger.error('Error unblocking user: $e');
      return false;
    }
  }

  /// Check if a user is blocked
  Future<bool> isUserBlocked(String userId) async {
    if (currentUserId == null) return false;

    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      if (!userDoc.exists) return false;

      final blockedUsers =
          List<String>.from(userDoc.data()!['blocked_users'] ?? []);
      return blockedUsers.contains(userId);
    } catch (e) {
      AppLogger.error('Error checking blocked user: $e');
      return false;
    }
  }

  /// Get list of blocked users
  Future<List<String>> getBlockedUsers() async {
    if (currentUserId == null) return [];

    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      if (!userDoc.exists) return [];

      return List<String>.from(userDoc.data()!['blocked_users'] ?? []);
    } catch (e) {
      AppLogger.error('Error getting blocked users: $e');
      return [];
    }
  }
}
