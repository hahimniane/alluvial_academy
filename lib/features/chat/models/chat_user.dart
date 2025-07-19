class ChatUser {
  final String id;
  final String name;
  final String email;
  final String? profilePicture;
  final String? role;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  ChatUser({
    required this.id,
    required this.name,
    required this.email,
    this.profilePicture,
    this.role,
    this.isOnline = false,
    this.lastSeen,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory ChatUser.fromMap(Map<String, dynamic> map) {
    return ChatUser(
      id: map['id'] ?? '',
      name: '${map['first_name'] ?? ''} ${map['last_name'] ?? ''}'.trim(),
      email: map['email'] ?? map['e-mail'] ?? '',
      profilePicture: map['profile_picture'],
      role: map['user_type'],
      isOnline: map['is_online'] ?? false,
      lastSeen:
          map['last_seen'] != null ? DateTime.tryParse(map['last_seen']) : null,
      lastMessage: map['last_message'],
      lastMessageTime: map['last_message_time'] != null
          ? DateTime.tryParse(map['last_message_time'])
          : null,
      unreadCount: map['unread_count'] ?? 0,
    );
  }

  String get displayName => name.isEmpty ? email : name;

  String get initials {
    if (name.isEmpty) return email.isNotEmpty ? email[0].toUpperCase() : '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  String toString() {
    return 'ChatUser(id: $id, name: $name, email: $email, role: $role, isOnline: $isOnline)';
  }
}
