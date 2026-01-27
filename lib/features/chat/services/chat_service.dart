import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../../../core/services/user_role_service.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;
  String? get currentUserEmail => _auth.currentUser?.email;

  // Get all users for browsing (except current user)
  Stream<List<ChatUser>> getAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) => snapshot
            .docs
            .where((doc) => doc.data()['email'] != currentUserEmail)
            .map((doc) {
          final data = doc.data();
          return ChatUser(
            id: doc.id,
            name:
                '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim(),
            email: data['email'] ?? data['e-mail'] ?? '',
            profilePicture: data['profile_picture_url'] ?? data['profile_picture'],
            role: data['user_type'],
            isOnline: _isUserOnline(data['last_login']),
            lastSeen: data['last_login'] != null
                ? (data['last_login'] as Timestamp?)?.toDate()
                : null,
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
        final allUserIds = <String>{};
        final chatFutures = <Future<ChatUser>>[];

        for (var chatDoc in chatSnapshot.docs) {
          final chatData = chatDoc.data();
          final participants =
              List<String>.from(chatData['participants'] ?? []);

          if (chatData['chat_type'] == 'group') {
            chatFutures
                .add(Future.value(_createGroupChatUser(chatDoc, chatData)));
          } else {
            final otherUserId = participants
                .firstWhere((id) => id != currentUserId, orElse: () => '');
            if (otherUserId.isNotEmpty) {
              allUserIds.add(otherUserId);
            }
          }
        }

        final usersData = await _fetchUsersDataInBatch(allUserIds);

        for (var chatDoc in chatSnapshot.docs) {
          final chatData = chatDoc.data();
          if (chatData['chat_type'] != 'group') {
            final participants =
                List<String>.from(chatData['participants'] ?? []);
            final otherUserId = participants
                .firstWhere((id) => id != currentUserId, orElse: () => '');
            if (otherUserId.isNotEmpty && usersData.containsKey(otherUserId)) {
              chatFutures.add(Future.value(_createIndividualChatUser(
                  chatDoc, otherUserId, usersData[otherUserId]!)));
            }
          }
        }

        final chatUsers = await Future.wait(chatFutures);
        chatUsers.sort((a, b) => (b.lastMessageTime ?? DateTime(0))
            .compareTo(a.lastMessageTime ?? DateTime(0)));

        return chatUsers;
      } catch (e) {
        AppLogger.error('Error in getUserChats: $e');
        return <ChatUser>[];
      }
    });
  }

  Future<Map<String, Map<String, dynamic>>> _fetchUsersDataInBatch(
      Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final usersData = <String, Map<String, dynamic>>{};
    final userDocs = await _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: userIds.toList())
        .get();
    for (var doc in userDocs.docs) {
      usersData[doc.id] = doc.data();
    }
    return usersData;
  }

  ChatUser _createGroupChatUser(
      DocumentSnapshot chatDoc, Map<String, dynamic> chatData) {
    final lastMessage = chatData['last_message'] as Map<String, dynamic>?;
    final participants = List<String>.from(chatData['participants'] ?? []);

    return ChatUser(
      id: chatDoc.id,
      name: chatData['group_name'] ?? 'Unnamed Group',
      email: chatData['group_description'] ?? 'Group chat',
      isGroup: true,
      participants: participants,
      createdBy: chatData['created_by'],
      participantCount: participants.length,
      lastMessage: lastMessage?['content'] ?? '',
      lastMessageTime: (lastMessage?['timestamp'] as Timestamp?)?.toDate() ??
          (chatData['created_at'] as Timestamp?)?.toDate(),
    );
  }

  ChatUser _createIndividualChatUser(
      DocumentSnapshot chatDoc, String userId, Map<String, dynamic> userData) {
    final chatData = chatDoc.data() as Map<String, dynamic>;
    final lastMessage = chatData['last_message'] as Map<String, dynamic>?;

    return ChatUser(
      id: userId,
      name: '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'
          .trim(),
      email: userData['email'] ?? userData['e-mail'] ?? '',
      profilePicture: userData['profile_picture_url'] ?? userData['profile_picture'],
      role: userData['user_type'],
      isOnline: _isUserOnline(userData['last_login']),
      lastSeen: (userData['last_login'] as Timestamp?)?.toDate(),
      lastMessage: lastMessage?['content'] ?? '',
      lastMessageTime: lastMessage != null
          ? (lastMessage['timestamp'] as Timestamp?)?.toDate()
          : (chatData['created_at'] as Timestamp?)
              ?.toDate(), // Use creation time if no messages yet
    );
  }

  // Get messages for a specific chat (handles both individual and group chats)
  Stream<List<ChatMessage>> getChatMessages(String chatIdOrUserId, {bool isGroupChat = false}) {
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

  // Send a message (handles both individual and group chats)
  Future<void> sendMessage(String chatIdOrUserId, String content,
      {String messageType = 'text', Map<String, dynamic>? metadata, bool isGroupChat = false}) async {
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
        await chatDocRef.set({
          'participants': [currentUserId, chatIdOrUserId],
          'chat_type': 'individual',
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
          'last_message': messageData,
        });
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
  Future<void> sendImageMessage(String chatIdOrUserId, File imageFile,
      {bool isGroupChat = false}) async {
    if (currentUserId == null) return;

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(currentUserId!)
          .child(fileName);

      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      final fileSize = await imageFile.length();

      await sendMessage(
        chatIdOrUserId,
        '📷 Photo',
        messageType: 'image',
        metadata: {
          'file_url': downloadUrl,
          'file_name': fileName,
          'file_size': fileSize,
          'mime_type': 'image/${fileName.split('.').last}',
        },
        isGroupChat: isGroupChat,
      );
    } catch (e) {
      AppLogger.error('Error sending image message: $e');
      rethrow;
    }
  }

  /// Upload a file and send as a message
  Future<void> sendFileMessage(String chatIdOrUserId, File file, String originalFileName,
      {bool isGroupChat = false}) async {
    if (currentUserId == null) return;

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$originalFileName';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_files')
          .child(currentUserId!)
          .child(fileName);

      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      final fileSize = await file.length();

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
  Future<void> sendVoiceMessage(String chatIdOrUserId, File audioFile, int durationSeconds,
      {bool isGroupChat = false}) async {
    if (currentUserId == null) return;

    try {
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_voice')
          .child(currentUserId!)
          .child(fileName);

      final uploadTask = await ref.putFile(audioFile);
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
        },
        isGroupChat: isGroupChat,
      );
    } catch (e) {
      AppLogger.error('Error sending voice message: $e');
      rethrow;
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

      AppLogger.error('ChatService: Group created successfully with ID: ${groupDoc.id}');
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

  // Add members to an existing group (admin only)
  Future<bool> addMembersToGroup(
      String groupChatId, List<String> newMemberIds) async {
    if (currentUserId == null) return false;

    try {
      // Check if current user is admin of the group
      final groupDoc =
          await _firestore.collection('chats').doc(groupChatId).get();
      if (!groupDoc.exists) return false;

      final groupData = groupDoc.data()!;
      final adminIds = List<String>.from(groupData['admin_ids'] ?? []);
      final currentParticipants =
          List<String>.from(groupData['participants'] ?? []);

      // Check if user is admin
      if (!adminIds.contains(currentUserId)) {
        throw Exception('Only group administrators can add members');
      }

      // Filter out members who are already in the group
      final membersToAdd = newMemberIds
          .where((id) => !currentParticipants.contains(id))
          .toList();

      if (membersToAdd.isEmpty) return true; // No new members to add

      // Add new members to the group
      await _firestore.collection('chats').doc(groupChatId).update({
        'participants': FieldValue.arrayUnion(membersToAdd),
        'updated_at': FieldValue.serverTimestamp(),
      });

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

      return adminIds.contains(currentUserId);
    } catch (e) {
      return false;
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String otherUserId) async {
    if (currentUserId == null) return;

    final chatId = _generateChatId(currentUserId!, otherUserId);
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
      if (data['sender_id'] != currentUserId) {
        batch.update(doc.reference, {'is_read': true});
      }
    }
    await batch.commit();
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
      if (data['sender_id'] != currentUserId) {
        count++;
      }
    }
    return count;
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

      AppLogger.debug('ChatService: Found ${userDocs.docs.length} user documents');

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
}
