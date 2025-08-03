import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../../../core/services/user_role_service.dart';

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
        print('Error in getUserChats: $e');
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
      profilePicture: userData['profile_picture'],
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
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      print(
          'ChatService: Creating group chat - Name: $groupName, Participants: ${participantIds.length}');

      // Use UserRoleService to get the current active role (respects role switching)
      final userRole = await UserRoleService.getCurrentUserRole();

      print('ChatService: Current user active role: $userRole');

      // Also check the actual Firestore document for debugging
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      if (currentUserDoc.exists) {
        final userData = currentUserDoc.data() ?? {};
        print(
            'ChatService: User document data - user_type: ${userData['user_type']}, is_admin_teacher: ${userData['is_admin_teacher']}');
        print('ChatService: User UID: $currentUserId');
      } else {
        print(
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

      print('ChatService: Final participants list: $participantIds');

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

      print('ChatService: Group created successfully with ID: ${groupDoc.id}');
      return groupDoc.id;
    } catch (e) {
      print('ChatService: Error creating group chat: $e');
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
      print('ChatService: getUserNames called with IDs: $userIds');

      final userDocs = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIds)
          .get();

      print('ChatService: Found ${userDocs.docs.length} user documents');

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
        print(
            'ChatService: User ${doc.id} -> $displayName (firstName: $firstName, lastName: $lastName, email: $email)');
      }

      print('ChatService: Final userNames map: $userNames');
      return userNames;
    } catch (e) {
      print('Error fetching user names: $e');
      return {};
    }
  }
}
