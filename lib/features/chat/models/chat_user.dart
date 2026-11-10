class ChatUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? profilePicture;
  final String? role;

  /// Job title from the user doc's `title` field (edited on the admin
  /// Edit User screen).
  final String? jobTitle;
  final bool isOnline;
  final DateTime? lastSeen;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isGroup;
  final String? groupImageUrl;
  final List<String>? participants; // For group chats
  final String? createdBy; // For group chats
  final int? participantCount; // For group chats

  ChatUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.profilePicture,
    this.role,
    this.jobTitle,
    this.isOnline = false,
    this.lastSeen,
    this.lastMessage = '',
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isGroup = false,
    this.groupImageUrl,
    this.participants,
    this.createdBy,
    this.participantCount,
  });

  factory ChatUser.fromMap(Map<String, dynamic> map) {
    return ChatUser(
      id: map['id'] ?? '',
      name: '${map['first_name'] ?? ''} ${map['last_name'] ?? ''}'.trim(),
      email: map['email'] ?? map['e-mail'] ?? '',
      phone: map['phone_number'] ??
          map['phoneNumber'] ??
          map['mobile_phone'] ??
          map['mobilePhone'] ??
          map['phone'] ??
          '',
      profilePicture: map['profile_picture_url'] ?? map['profile_picture'],
      role: map['user_type'],
      jobTitle: map['title']?.toString(),
      isOnline: map['is_online'] ?? false,
      lastSeen:
          map['last_seen'] != null ? DateTime.tryParse(map['last_seen']) : null,
      lastMessage: map['last_message'] ?? '',
      lastMessageTime: map['last_message_time'] != null
          ? DateTime.tryParse(map['last_message_time'])
          : null,
      unreadCount: map['unread_count'] ?? 0,
      isGroup: map['is_group'] ?? false,
      groupImageUrl: map['group_image_url'],
      participants: List<String>.from(map['participants'] ?? []),
      createdBy: map['created_by'],
      participantCount: map['participant_count'],
    );
  }

  String get displayName => name.isNotEmpty ? name : email;

  /// A leader's job title to show under their name in chat, or null when the
  /// generic role label should be shown instead.
  String? get leaderTitle => leaderTitleFor(role: role, title: jobTitle);

  static const Set<String> _leaderRoles = {
    'admin',
    'super_admin',
    'ceo',
    'founder',
  };

  /// Only leaders (admin user types) show a job title, and only one that says
  /// more than the role itself ("Admin" / "Administrator", any case).
  static String? leaderTitleFor({String? role, String? title}) {
    if (!_leaderRoles.contains((role ?? '').trim().toLowerCase())) return null;
    final trimmed = (title ?? '').trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (lower == 'admin' || lower == 'administrator') return null;
    return trimmed;
  }

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
