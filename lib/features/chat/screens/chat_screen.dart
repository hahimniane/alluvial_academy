import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chat_service.dart';
import '../models/chat_user.dart';
import '../models/chat_message.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final ChatUser chatUser;

  const ChatScreen({
    super.key,
    required this.chatUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _isComposing = false;
  ChatMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    // Mark messages as read when opening chat (only for individual chats)
    if (widget.chatUser.role != 'group') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _chatService.markMessagesAsRead(widget.chatUser.id);
      });
    }
  }

  void _onTextChanged() {
    setState(() {
      _isComposing = _messageController.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _buildMessagesList(),
          ),

          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Container(
        margin: const EdgeInsets.only(left: 16),
        child: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xffF1F5F9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xff374151),
            size: 20,
          ),
        ),
      ),
      title: Row(
        children: [
          // Enhanced Avatar
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.chatUser.isGroup
                      ? const Color(0xff059669).withOpacity(0.1)
                      : const Color(0xff0386FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.chatUser.isGroup
                        ? const Color(0xff059669).withOpacity(0.15)
                        : const Color(0xff0386FF).withOpacity(0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.chatUser.isGroup 
                          ? const Color(0xff059669) 
                          : const Color(0xff0386FF)).withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: widget.chatUser.profilePicture != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.chatUser.profilePicture!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildInitialsAvatar(),
                        ),
                      )
                    : _buildInitialsAvatar(),
              ),

              // Enhanced online indicator
              if (widget.chatUser.isOnline && !widget.chatUser.isGroup)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xff10B981),
                      borderRadius: BorderRadius.circular(7),
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
          ),

          const SizedBox(width: 16),

          // Enhanced User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chatUser.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                    height: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                _buildStatusIndicator(),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _buildActionButton(Icons.call, () {
          // TODO: Add call functionality
        }),
        _buildActionButton(Icons.videocam, () {
          // TODO: Add video call functionality
        }),
        PopupMenuButton<String>(
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xffF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.more_vert,
              color: Color(0xff64748B),
              size: 20,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            switch (value) {
              case 'clear_chat':
                _showClearChatDialog();
                break;
              case 'block_user':
                _showBlockUserDialog();
                break;
              case 'add_members':
                _showAddMembersDialog();
                break;
              case 'group_info':
                _showGroupInfoDialog();
                break;
            }
          },
          itemBuilder: (context) => _buildMenuItems(),
        ),
        const SizedBox(width: 16),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: const Color(0xffF1F5F9),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xffF1F5F9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(
          icon,
          color: const Color(0xff64748B),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (widget.chatUser.isGroup) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xff059669).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xff059669).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          widget.chatUser.email, // Group description or "Group chat"
          style: GoogleFonts.inter(
            fontSize: 10,
            color: const Color(0xff059669),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (widget.chatUser.isOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xff10B981).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xff10B981).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          'Online',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: const Color(0xff10B981),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (widget.chatUser.lastSeen != null) {
      return Text(
        'Last sent ${_formatLastSeen(widget.chatUser.lastSeen!)}',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: const Color(0xff94A3B8),
          fontWeight: FontWeight.w400,
        ),
      );
    }

    return Text(
      widget.chatUser.role != null
          ? _getRoleDisplayName(widget.chatUser.role!)
          : 'Offline',
      style: GoogleFonts.inter(
        fontSize: 12,
        color: const Color(0xff94A3B8),
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    if (widget.chatUser.isGroup) {
      return const Center(
        child: Icon(
          Icons.group,
          size: 22,
          color: Color(0xff059669),
        ),
      );
    }

    return Center(
      child: Text(
        widget.chatUser.initials,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xff0386FF),
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<List<ChatMessage>>(
      stream: _chatService.getChatMessages(widget.chatUser.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading messages',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xff374151),
                  ),
                ),
              ],
            ),
          );
        }

        final messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xff0386FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    size: 48,
                    color: Color(0xff0386FF),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Start the conversation',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Send a message to begin chatting with ${widget.chatUser.displayName}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isCurrentUser =
                message.senderId == _chatService.currentUserId;

            return MessageBubble(
              message: message,
              isCurrentUser: isCurrentUser,
              onReply: (message) => _setReplyMessage(message),
              onDelete: (message) => _deleteMessage(message),
              onForward: (message) => _forwardMessage(message),
              onReaction: (message, reaction) =>
                  _addReaction(message, reaction),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Reply preview
          if (_replyingTo != null) _buildReplyPreview(),

          // Message input row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment button
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.add,
                    color: Color(0xff6B7280),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) => _handleAttachment(value),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'photo',
                      child: Row(
                        children: [
                          const Icon(Icons.photo, color: Color(0xff059669)),
                          const SizedBox(width: 12),
                          Text(
                            'Photo',
                            style: GoogleFonts.inter(
                                color: const Color(0xff374151)),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'camera',
                      child: Row(
                        children: [
                          const Icon(Icons.camera_alt,
                              color: Color(0xff0386FF)),
                          const SizedBox(width: 12),
                          Text(
                            'Camera',
                            style: GoogleFonts.inter(
                                color: const Color(0xff374151)),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'file',
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file,
                              color: Color(0xff6366F1)),
                          const SizedBox(width: 12),
                          Text(
                            'Document',
                            style: GoogleFonts.inter(
                                color: const Color(0xff374151)),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'location',
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Color(0xffEF4444)),
                          const SizedBox(width: 12),
                          Text(
                            'Location',
                            style: GoogleFonts.inter(
                                color: const Color(0xff374151)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 8),

                // Message input field
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: const Color(0xffF9FAFB),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xffE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xff111827),
                      ),
                      decoration: InputDecoration(
                        hintText: _replyingTo != null
                            ? 'Reply to ${_replyingTo!.senderName}...'
                            : 'Type a message...',
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xff9CA3AF),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (value) => _sendMessage(),
                      onChanged: (text) {
                        setState(() {
                          _isComposing = text.trim().isNotEmpty;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Voice/Send button
                _isComposing
                    ? AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: IconButton(
                          onPressed: _sendMessage,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xff0386FF),
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                          ),
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      )
                    : IconButton(
                        onPressed: () => _handleVoiceMessage(),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xffE5E7EB),
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(
                          Icons.mic,
                          color: Color(0xff6B7280),
                          size: 20,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xffF3F4F6),
          borderRadius: BorderRadius.circular(12),
          border: const Border(
            left: BorderSide(
              color: Color(0xff0386FF),
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.reply,
                        size: 16,
                        color: const Color(0xff0386FF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Replying to ${_replyingTo!.senderName}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff0386FF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _replyingTo!.content,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xff6B7280),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _replyingTo = null;
                });
              },
              icon: const Icon(
                Icons.close,
                color: Color(0xff6B7280),
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAttachment(String type) {
    // TODO: Implement different attachment types
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$type attachment not yet implemented',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: const Color(0xffF59E0B),
      ),
    );
  }

  void _handleVoiceMessage() {
    // TODO: Implement voice message recording
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Voice messages not yet implemented',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: const Color(0xffF59E0B),
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Include reply information if replying
    Map<String, dynamic>? metadata;
    if (_replyingTo != null) {
      metadata = {
        'reply_to': {
          'message_id': _replyingTo!.id,
          'content': _replyingTo!.content,
          'sender_name': _replyingTo!.senderName,
        }
      };
    }

    _chatService.sendMessage(widget.chatUser.id, text, metadata: metadata);
    _messageController.clear();
    _messageFocusNode.requestFocus();

    // Clear reply
    setState(() {
      _replyingTo = null;
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _setReplyMessage(ChatMessage message) {
    setState(() {
      _replyingTo = message;
    });
    _messageFocusNode.requestFocus();
  }

  void _deleteMessage(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Message',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this message?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xff6B7280)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement delete message functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Message deletion not yet implemented',
                    style: GoogleFonts.inter(),
                  ),
                  backgroundColor: const Color(0xffF59E0B),
                ),
              );
            },
            child: Text(
              'Delete',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _forwardMessage(ChatMessage message) {
    // TODO: Implement forward message functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Message forwarding not yet implemented',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: const Color(0xffF59E0B),
      ),
    );
  }

  void _addReaction(ChatMessage message, String reaction) {
    // TODO: Implement reaction functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reaction added: $reaction',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: const Color(0xff10B981),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Clear Chat',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to clear this chat? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xff6B7280)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement clear chat functionality
            },
            child: Text(
              'Clear',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Block User',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to block ${widget.chatUser.displayName}? They will no longer be able to send you messages.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xff6B7280)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement block user functionality
            },
            child: Text(
              'Block',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems() {
    List<PopupMenuEntry<String>> items = [
      PopupMenuItem(
        value: 'clear_chat',
        child: Row(
          children: [
            const Icon(Icons.clear_all, color: Color(0xff6B7280)),
            const SizedBox(width: 12),
            Text(
              'Clear Chat',
              style: GoogleFonts.inter(color: const Color(0xff374151)),
            ),
          ],
        ),
      ),
    ];

    if (widget.chatUser.role == 'group') {
      // Group-specific options
      items.add(
        PopupMenuItem(
          value: 'group_info',
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xff6B7280)),
              const SizedBox(width: 12),
              Text(
                'Group Info',
                style: GoogleFonts.inter(color: const Color(0xff374151)),
              ),
            ],
          ),
        ),
      );

      // Add members option (will check admin status dynamically)
      items.add(
        PopupMenuItem(
          value: 'add_members',
          child: Row(
            children: [
              const Icon(Icons.person_add, color: Color(0xff059669)),
              const SizedBox(width: 12),
              Text(
                'Add Members',
                style: GoogleFonts.inter(color: const Color(0xff374151)),
              ),
            ],
          ),
        ),
      );
    } else {
      // Individual chat options
      items.add(
        PopupMenuItem(
          value: 'block_user',
          child: Row(
            children: [
              const Icon(Icons.block, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                'Block User',
                style: GoogleFonts.inter(color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }

    return items;
  }

  void _showAddMembersDialog() async {
    // Check if user is admin first
    if (widget.chatUser.role != 'group') return;

    final isAdmin = await _chatService.isGroupAdmin(widget.chatUser.id);
    if (!isAdmin) {
      _showMessage('Only group administrators can add members');
      return;
    }

    // Get all users except current group members
    final groupDetails = await _chatService.getGroupDetails(widget.chatUser.id);
    if (groupDetails == null) return;

    final currentParticipants =
        List<String>.from(groupDetails['participants'] ?? []);

    // Show user selection dialog
    showDialog(
      context: context,
      builder: (context) => _AddMembersDialog(
        chatService: _chatService,
        groupChatId: widget.chatUser.id,
        currentParticipants: currentParticipants,
        onMembersAdded: () {
          _showMessage('Members added successfully!');
        },
      ),
    );
  }

  void _showGroupInfoDialog() async {
    if (widget.chatUser.role != 'group') return;

    final groupDetails = await _chatService.getGroupDetails(widget.chatUser.id);
    if (groupDetails == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Group Information',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name: ${groupDetails['group_name']}',
              style: GoogleFonts.inter(),
            ),
            const SizedBox(height: 8),
            Text(
              'Description: ${groupDetails['group_description'] ?? 'No description'}',
              style: GoogleFonts.inter(),
            ),
            const SizedBox(height: 8),
            Text(
              'Members: ${(groupDetails['participants'] as List).length}',
              style: GoogleFonts.inter(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.inter(color: const Color(0xff0386FF)),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xff059669),
        behavior: SnackBarBehavior.floating,
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
      default:
        return role;
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

// Dialog widget for adding members to a group
class _AddMembersDialog extends StatefulWidget {
  final ChatService chatService;
  final String groupChatId;
  final List<String> currentParticipants;
  final VoidCallback onMembersAdded;

  const _AddMembersDialog({
    required this.chatService,
    required this.groupChatId,
    required this.currentParticipants,
    required this.onMembersAdded,
  });

  @override
  State<_AddMembersDialog> createState() => _AddMembersDialogState();
}

class _AddMembersDialogState extends State<_AddMembersDialog> {
  final List<String> _selectedUserIds = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Add Members',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: StreamBuilder<List<ChatUser>>(
          stream: widget.chatService.getAllUsers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
                ),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text('Error loading users'),
              );
            }

            final allUsers = snapshot.data ?? [];
            // Filter out users who are already in the group
            final availableUsers = allUsers
                .where((user) => !widget.currentParticipants.contains(user.id))
                .toList();

            if (availableUsers.isEmpty) {
              return const Center(
                child: Text('No users available to add'),
              );
            }

            return ListView.builder(
              itemCount: availableUsers.length,
              itemBuilder: (context, index) {
                final user = availableUsers[index];
                final isSelected = _selectedUserIds.contains(user.id);

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedUserIds.add(user.id);
                      } else {
                        _selectedUserIds.remove(user.id);
                      }
                    });
                  },
                  title: Text(
                    user.displayName,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    user.role ?? 'No role',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xff0386FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        user.initials,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff0386FF),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(color: const Color(0xff6B7280)),
          ),
        ),
        TextButton(
          onPressed: _selectedUserIds.isEmpty || _isLoading
              ? null
              : () async {
                  setState(() => _isLoading = true);

                  final success = await widget.chatService.addMembersToGroup(
                    widget.groupChatId,
                    _selectedUserIds,
                  );

                  setState(() => _isLoading = false);

                  if (success) {
                    widget.onMembersAdded();
                    if (mounted) Navigator.of(context).pop();
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to add members'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xff059669)),
                  ),
                )
              : Text(
                  'Add ${_selectedUserIds.length} Member${_selectedUserIds.length == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(color: const Color(0xff059669)),
                ),
        ),
      ],
    );
  }
}
