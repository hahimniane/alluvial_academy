import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_user.dart';

class ChatUserListItem extends StatelessWidget {
  final ChatUser user;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool showLastMessage;

  const ChatUserListItem({
    super.key,
    required this.user,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.showLastMessage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xff0386FF).withOpacity(0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(
                color: const Color(0xff0386FF).withOpacity(0.2), width: 1.5)
            : Border.all(color: const Color(0xffF1F5F9), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Enhanced Avatar
                _buildModernAvatar(),
                const SizedBox(width: 16),

                // User info with improved spacing
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and unread count row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.displayName,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff111827),
                                height: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.unreadCount > 0) _buildUnreadBadge(),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Role, email, or online status
                      _buildSubtitleInfo(),

                      // Last message and time (conditional)
                      if (showLastMessage && user.lastMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildLastMessageRow(),
                      ] else if (!user.isOnline &&
                          user.lastMessageTime != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Last sent ${_formatLastSeen(user.lastMessageTime!)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xff94A3B8),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
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

  Widget _buildModernAvatar() {
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: user.isGroup
                ? const Color(0xff059669).withOpacity(0.1)
                : const Color(0xff0386FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: user.isGroup
                  ? const Color(0xff059669).withOpacity(0.15)
                  : const Color(0xff0386FF).withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (user.isGroup
                        ? const Color(0xff059669)
                        : const Color(0xff0386FF))
                    .withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: user.profilePicture != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    user.profilePicture!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildInitialsAvatar(),
                  ),
                )
              : _buildInitialsAvatar(),
        ),

        // Enhanced online indicator
        if (user.isOnline && !user.isGroup)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xff10B981),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff10B981).withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitialsAvatar() {
    if (user.isGroup) {
      return Center(
        child: Icon(
          Icons.group,
          size: 28,
          color: const Color(0xff059669),
        ),
      );
    }

    return Center(
      child: Text(
        user.initials,
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xff0386FF),
        ),
      ),
    );
  }

  Widget _buildUnreadBadge() {
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xff0386FF),
            const Color(0xff0366D6),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0386FF).withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        user.unreadCount > 99 ? '99+' : user.unreadCount.toString(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSubtitleInfo() {
    if (user.isGroup) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xff059669).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xff059669).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              'Group Chat',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xff059669),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (user.participantCount != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xff6B7280).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${user.participantCount} members',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xff6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      );
    }

    if (user.role != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _getRoleColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _getRoleColor().withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          _getRoleDisplayName(user.role!),
          style: GoogleFonts.inter(
            fontSize: 11,
            color: _getRoleColor(),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Text(
      user.email,
      style: GoogleFonts.inter(
        fontSize: 13,
        color: const Color(0xff64748B),
        fontWeight: FontWeight.w400,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildLastMessageRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            user.lastMessage,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff64748B),
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
        if (user.lastMessageTime != null) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xffF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xffE2E8F0),
                width: 1,
              ),
            ),
            child: Text(
              _formatLastMessageTime(user.lastMessageTime!),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xff94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _getRoleColor() {
    switch (user.role?.toLowerCase()) {
      case 'admin':
        return const Color(0xffDC2626);
      case 'teacher':
        return const Color(0xff0386FF);
      case 'student':
        return const Color(0xff059669);
      case 'parent':
        return const Color(0xffF59E0B);
      default:
        return const Color(0xff6B7280);
    }
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
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
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
      return 'on ${lastSeen.day}/${lastSeen.month}';
    }
  }
}
