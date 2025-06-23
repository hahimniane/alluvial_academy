import '../screens/chat_page.dart';
import 'package:flutter/material.dart';

class ChatUser {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final bool isOnline;
  final List<ChatMessage> messages;

  ChatUser({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    this.isOnline = false,
    this.messages = const [],
  });

  @override
  String toString() {
    return 'ChatUser(id: $id, name: $name, subtitle: $subtitle, isOnline: $isOnline)';
  }
}
