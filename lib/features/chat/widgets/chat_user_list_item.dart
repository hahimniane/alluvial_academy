import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_user.dart';

class ChatUserListItem extends StatelessWidget {
  final ChatUser user;
  final VoidCallback onTap;
  final bool isSelected;
  final bool showLastMessage;

  const ChatUserListItem({
    super.key,
    required this.user,
    required this.onTap,
    this.isSelected = false,
    this.showLastMessage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xff0386FF).withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(
                color: const Color(0xff0386FF).withOpacity(0.3), width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: user.role == 'group'
                            ? const Color(0xff059669).withOpacity(0.1)
                            : const Color(0xff0386FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: user.role == 'group'
                              ? const Color(0xff059669).withOpacity(0.2)
                              : const Color(0xff0386FF).withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: user.profilePicture != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.network(
                                user.profilePicture!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildInitialsAvatar(),
                              ),
                            )
                          : _buildInitialsAvatar(),
                    ),

                    // Online indicator
                    if (user.isOnline)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xff10B981),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 12),

                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and unread count
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.displayName,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff111827),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xff0386FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                user.unreadCount > 99
                                    ? '99+'
                                    : user.unreadCount.toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 2),

                      // Role or email
                      if (user.role != null)
                        Text(
                          _getRoleDisplayName(user.role!),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xff0386FF),
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        Text(
                          user.email,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xff6B7280),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),

                      // Last message and time (only if showLastMessage is true)
                      if (showLastMessage && user.lastMessage != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.lastMessage!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xff6B7280),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (user.lastMessageTime != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                _formatLastMessageTime(user.lastMessageTime!),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xff9CA3AF),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ] else if (!user.isOnline && user.lastSeen != null)
                        Text(
                          'Last seen ${_formatLastSeen(user.lastSeen!)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xff9CA3AF),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    if (user.role == 'group') {
      return const Center(
        child: Icon(
          Icons.group,
          size: 24,
          color: Color(0xff059669),
        ),
      );
    }

    return Center(
      child: Text(
        user.initials,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xff0386FF),
        ),
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrator';
      case 'teacher':
        return 'Teacher';
      case 'student':
        return 'Student';
      case 'parent':
        return 'Parent';
      case 'group':
        return 'Group Chat';
      default:
        return role;
    }
  }

  String _formatLastMessageTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return 'on ${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
    }
  }
}
