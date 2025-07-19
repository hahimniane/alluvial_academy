import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';

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
            profilePicture: data['profile_picture'],
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

    // Remove orderBy to avoid compound index requirement, sort in client instead
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .asyncMap((chatSnapshot) async {
      List<ChatUser> chatUsers = [];

      try {
        for (var chatDoc in chatSnapshot.docs) {
          try {
            final chatData = chatDoc.data();
            final participants =
                List<String>.from(chatData['participants'] ?? []);
            final lastMessage =
                chatData['last_message'] as Map<String, dynamic>?;

            // Handle group chats
            if (chatData['chat_type'] == 'group') {
              final groupName = chatData['group_name'] ?? 'Unnamed Group';
              final groupDescription = chatData['group_description'] ?? '';

              chatUsers.add(ChatUser(
                id: chatDoc.id, // Use chat document ID for groups
                name: groupName,
                email: groupDescription.isNotEmpty
                    ? groupDescription
                    : 'Group chat',
                profilePicture: null, // Groups don't have profile pictures
                role: 'group', // Special role for groups
                isOnline: false, // Groups don't have online status
                lastSeen: null,
                lastMessage: lastMessage?['content'] ?? '',
                lastMessageTime: lastMessage?['timestamp'] != null
                    ? (lastMessage!['timestamp'] as Timestamp).toDate()
                    : chatData['created_at'] != null
                        ? (chatData['created_at'] as Timestamp).toDate()
                        : DateTime.now(),
                unreadCount: await _getUnreadCount(chatDoc.id),
              ));
              continue;
            }

            // Handle individual chats
            final otherUserId = participants.firstWhere(
              (id) => id != currentUserId,
              orElse: () => '',
            );

            if (otherUserId.isEmpty) continue;

            // Get user details
            final userDoc =
                await _firestore.collection('users').doc(otherUserId).get();
            if (!userDoc.exists) continue;

            final userData = userDoc.data()!;

            chatUsers.add(ChatUser(
              id: otherUserId,
              name:
                  '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'
                      .trim(),
              email: userData['email'] ?? userData['e-mail'] ?? '',
              profilePicture: userData['profile_picture'],
              role: userData['user_type'],
              isOnline: _isUserOnline(userData['last_login']),
              lastSeen: userData['last_login'] != null
                  ? (userData['last_login'] as Timestamp?)?.toDate()
                  : null,
              lastMessage: lastMessage?['content'] ?? '',
              lastMessageTime: lastMessage?['timestamp'] != null
                  ? (lastMessage!['timestamp'] as Timestamp).toDate()
                  : null,
              unreadCount: await _getUnreadCount(chatDoc.id),
            ));
          } catch (e) {
            // Skip this chat if there's an error processing it
            continue;
          }
        }

        // Sort by last message time in client to avoid compound index
        chatUsers.sort((a, b) {
          if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
          if (a.lastMessageTime == null) return 1;
          if (b.lastMessageTime == null) return -1;
          return b.lastMessageTime!.compareTo(a.lastMessageTime!);
        });

        return chatUsers;
      } catch (e) {
        // Return empty list if there's a general error
        return <ChatUser>[];
      }
    });
  }

  // Get messages for a specific chat (handles both individual and group chats)
  Stream<List<ChatMessage>> getChatMessages(String chatIdOrUserId) {
    if (currentUserId == null) return Stream.value([]);

    String chatId;
    // Check if this is already a generated chat ID (contains underscore)
    // or a Firestore document ID (long string without underscore for groups)
    // or a user ID (short string for individual chats)
    if (chatIdOrUserId.contains('_')) {
      // Already a generated chat ID for individual chat
      chatId = chatIdOrUserId;
    } else if (chatIdOrUserId.length > 15) {
      // Group chat - use the provided Firestore document ID directly
      chatId = chatIdOrUserId;
    } else {
      // Individual chat - generate chat ID from user ID
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

  // Send a message (handles both individual and group chats)
  Future<void> sendMessage(String chatIdOrUserId, String content,
      {String messageType = 'text', Map<String, dynamic>? metadata}) async {
    if (currentUserId == null) return;

    String chatId;
    bool isGroupChat = false;

    // Check if this is already a generated chat ID, group chat ID, or user ID
    if (chatIdOrUserId.contains('_')) {
      // Already a generated chat ID for individual chat
      chatId = chatIdOrUserId;
    } else if (chatIdOrUserId.length > 15) {
      // Group chat - use the provided Firestore document ID directly
      chatId = chatIdOrUserId;
      isGroupChat = true;
    } else {
      // Individual chat - generate chat ID from user ID
      chatId = _generateChatId(currentUserId!, chatIdOrUserId);
    }

    final currentUserDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final currentUserData = currentUserDoc.data() ?? {};
    final senderName =
        '${currentUserData['first_name'] ?? ''} ${currentUserData['last_name'] ?? ''}'
            .trim();

    final messageData = ChatMessage(
      id: '',
      senderId: currentUserId!,
      senderName:
          senderName.isNotEmpty ? senderName : currentUserEmail ?? 'Unknown',
      content: content,
      timestamp: DateTime.now(),
      messageType: messageType,
      metadata: metadata,
    ).toMap();

    // Handle chat document creation/update
    final chatDocRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatDocRef.get();

    if (!chatDoc.exists) {
      if (isGroupChat) {
        // For group chats, don't create new document - it should already exist
        // This might happen if we're using wrong chat ID, so just add the message
        await chatDocRef.collection('messages').add(messageData);
        return;
      } else {
        // Create individual chat document
        await chatDocRef.set({
          'participants': [currentUserId, chatIdOrUserId],
          'chat_type': 'individual',
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
          'last_message': messageData,
        });
      }
    } else {
      // Update existing chat document
      await chatDocRef.update({
        'updated_at': FieldValue.serverTimestamp(),
        'last_message': messageData,
      });
    }

    // Add message to subcollection
    await chatDocRef.collection('messages').add(messageData);
  }

  // Create a group chat (admin only)
  Future<String?> createGroupChat(
      String groupName, List<String> participantIds, String description) async {
    if (currentUserId == null) return null;

    try {
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final currentUserData = currentUserDoc.data() ?? {};
      final userRole = currentUserData['user_type'];

      // Check if user is admin
      if (userRole?.toLowerCase() != 'admin') {
        throw Exception('Only administrators can create group chats');
      }

      // Add current user to participants if not already included
      if (!participantIds.contains(currentUserId)) {
        participantIds.add(currentUserId!);
      }

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

      return groupDoc.id;
    } catch (e) {
      // Handle error silently or throw
      return null;
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
}
