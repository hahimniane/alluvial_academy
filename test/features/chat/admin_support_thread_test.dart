import 'package:alluwalacademyadmin/features/chat/services/chat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin Support thread', () {
    test('thread id matches what the member\'s own app opens', () {
      expect(ChatService.adminSupportChatIdFor('T1'), 'T1_admin_support');
      expect(ChatService.adminSupportChatIdFor('zz9'), 'admin_support_zz9');
      expect(
        ChatService.humanUserIdFromAdminSupportChatDocId(
            ChatService.adminSupportChatIdFor('zz9')),
        'zz9',
      );
    });

    test('one admin opening the thread never reads another admin\'s reply', () {
      const chat = 'T1_admin_support';
      // Admin B is viewing: admin A's reply is not waiting on B ...
      expect(ChatService.isIncomingFor(chatId: chat, senderId: 'ADMIN_A', viewerId: 'ADMIN_B'), isFalse);
      // ... but the teacher's message is.
      expect(ChatService.isIncomingFor(chatId: chat, senderId: 'T1', viewerId: 'ADMIN_B'), isTrue);
    });

    test('the teacher reads every reply from the school', () {
      const chat = 'T1_admin_support';
      expect(ChatService.isIncomingFor(chatId: chat, senderId: 'ADMIN_A', viewerId: 'T1'), isTrue);
      expect(ChatService.isIncomingFor(chatId: chat, senderId: 'T1', viewerId: 'T1'), isFalse);
    });

    test('ordinary chats keep the usual rule', () {
      expect(ChatService.isIncomingFor(chatId: 'A_B', senderId: 'B', viewerId: 'A'), isTrue);
      expect(ChatService.isIncomingFor(chatId: 'A_B', senderId: 'A', viewerId: 'A'), isFalse);
    });
  });
}
