import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import '../constants/app_constants.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get chat messages stream
  Stream<List<ChatMessage>> getChatMessages() {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data()))
          .toList();
    });
  }

  // Send new message
  Future<void> sendMessage(ChatMessage message) async {
    await _firestore
        .collection(AppConstants.chatsCollection)
        .add(message.toMap());
  }

  // Mark message as read
  Future<void> markAsRead(String messageId) async {
    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(messageId)
        .update({'isRead': true});
  }
}
