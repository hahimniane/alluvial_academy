import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ChatUser>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .asyncMap((chatSnapshot) async {
      Set<String> chatUserIds = {};

      for (var doc in chatSnapshot.docs) {
        List<String> participants =
            List<String>.from(doc['participants'] ?? []);
        chatUserIds.addAll(participants.where((id) => id != userId));
      }

      if (chatUserIds.isEmpty) return [];

      final userSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chatUserIds.toList())
          .get();

      return userSnapshot.docs.map((doc) {
        final data = doc.data();
        return ChatUser(
          id: doc.id,
          name: '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim(),
          subtitle: data['email'] ?? '',
          icon: Icons.person,
          isOnline: _isUserOnline(data['last_login']),
        );
      }).toList();
    });
  }

  Stream<List<ChatMessage>> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> sendMessage(
      String chatId, String senderId, String message) async {
    final messageData = {
      'content': message,
      'sender_id': senderId,
      'timestamp': FieldValue.serverTimestamp(),
      'read_by': [senderId],
    };

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      await _firestore.collection('chats').doc(chatId).set({
        'chat_type': 'individual',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'participants': [senderId, chatId],
      });
    }

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    await _firestore.collection('chats').doc(chatId).update({
      'last_message': messageData,
      'updated_at': FieldValue.serverTimestamp(),
    });
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
