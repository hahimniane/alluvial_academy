// lib/services/chat_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new chat between users
  Future<String> createChat({
    required List<String> participantIds,
    required String chatType, // 'individual' or 'group'
    String? groupName, // Optional, only for group chats
  }) async {
    try {
      final chatData = {
        'chat_type': chatType,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'participants': participantIds,
        'last_message': null,
      };

      if (chatType == 'group' && groupName != null) {
        chatData['group_name'] = groupName;
      }

      final DocumentReference chatRef =
          await _firestore.collection('chats').add(chatData);

      // Update users' active_chats
      for (String userId in participantIds) {
        await _firestore.collection('users').doc(userId).update({
          'active_chats': FieldValue.arrayUnion([
            {
              'chat_id': chatRef.id,
              'last_read': FieldValue.serverTimestamp(),
            }
          ])
        });
      }

      return chatRef.id;
    } catch (e) {
      print('Error creating chat: $e');
      rethrow;
    }
  }

  // Send a message in a chat
  Future<void> sendMessage({
    required String chatId,
    required String content,
    required String senderId,
  }) async {
    try {
      final messageData = {
        'content': content,
        'sender_id': senderId,
        'timestamp': FieldValue.serverTimestamp(),
        'read_by': [senderId],
      };

      // Add message to the messages subcollection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update the chat's last message and timestamp
      await _firestore.collection('chats').doc(chatId).update({
        'last_message': messageData,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Stream to listen to a specific chat's messages
  Stream<QuerySnapshot> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  // Stream to listen to user's chats
  Stream<QuerySnapshot> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('updated_at', descending: true)
        .snapshots();
  }

  // Mark message as read
  Future<void> markMessageAsRead({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'read_by': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      print('Error marking message as read: $e');
      rethrow;
    }
  }
}
