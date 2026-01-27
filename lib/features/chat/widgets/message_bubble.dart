import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import 'voice_message_player.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isCurrentUser;
  final Function(ChatMessage)? onReply;
  final Function(ChatMessage)? onDelete;
  final Function(ChatMessage)? onForward;
  final Function(ChatMessage, String)? onReaction;
  final Function(String)? onImageTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onReply,
    this.onDelete,
    this.onForward,
    this.onReaction,
    this.onImageTap,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showReactions = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showMessageMenu(context),
      onTap: () {
        if (_showReactions) {
          setState(() {
            _showReactions = false;
          });
        }
      },
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: widget.isCurrentUser ? 48 : 12,
          right: widget.isCurrentUser ? 12 : 48,
        ),
        child: Row(
          mainAxisAlignment: widget.isCurrentUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Profile picture for received messages
            if (!widget.isCurrentUser) ...[
              _buildAvatar(),
              const SizedBox(width: 8),
            ],
            
            Flexible(
              child: Column(
                crossAxisAlignment: widget.isCurrentUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Sender name (only for received messages)
                  if (!widget.isCurrentUser && widget.message.senderName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        widget.message.senderName,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff0386FF),
                        ),
                      ),
                    ),

                  // Reply preview
                  if (widget.message.metadata != null &&
                      widget.message.metadata!['reply_to'] != null)
                    _buildReplyPreview(),

                  // Message bubble
                  Stack(
                    children: [
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isCurrentUser
                              ? const Color(0xff0386FF)
                              : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(widget.isCurrentUser ? 20 : 4),
                            bottomRight: Radius.circular(widget.isCurrentUser ? 4 : 20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(widget.isCurrentUser ? 20 : 4),
                            bottomRight: Radius.circular(widget.isCurrentUser ? 4 : 20),
                          ),
                          child: _buildMessageContent(),
                        ),
                      ),
                      if (_showReactions) _buildReactionPicker(),
                    ],
                  ),

                  // Message reactions display
                  if (widget.message.metadata != null &&
                      widget.message.metadata!['reactions'] != null)
                    _buildReactionsDisplay(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final profilePic = widget.message.senderProfilePicture;
    final initials = widget.message.senderName.isNotEmpty
        ? widget.message.senderName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : '?';

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xff0386FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xff0386FF).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: profilePic != null && profilePic.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                profilePic,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildInitials(initials),
              ),
            )
          : _buildInitials(initials),
    );
  }

  Widget _buildInitials(String initials) {
    return Center(
      child: Text(
        initials,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xff0386FF),
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    if (widget.message.isImage) {
      return _buildImageMessage();
    } else if (widget.message.isVoice) {
      return _buildVoiceMessage();
    } else if (widget.message.isFile) {
      return _buildFileMessage();
    } else {
      return _buildTextMessage();
    }
  }
  
  Widget _buildVoiceMessage() {
    final audioUrl = widget.message.fileUrl;
    final duration = widget.message.voiceDuration ?? 0;
    
    if (audioUrl == null || audioUrl.isEmpty) {
      return _buildTextMessage(); // Fallback to text if no audio URL
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VoiceMessagePlayer(
            audioUrl: audioUrl,
            durationSeconds: duration,
            isFromMe: widget.isCurrentUser,
          ),
          const SizedBox(height: 6),
          _buildTimestamp(),
        ],
      ),
    );
  }

  Widget _buildTextMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message.content,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: widget.isCurrentUser ? Colors.white : const Color(0xff2D3748),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          _buildTimestamp(),
        ],
      ),
    );
  }

  Widget _buildImageMessage() {
    final imageUrl = widget.message.fileUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrl != null)
          GestureDetector(
            onTap: () => widget.onImageTap?.call(imageUrl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 150,
                    width: 200,
                    color: Colors.grey.shade200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        color: const Color(0xff0386FF),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 100,
                  width: 150,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _buildTimestamp(),
        ),
      ],
    );
  }

  Widget _buildFileMessage() {
    return InkWell(
      onTap: () => _openFile(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.isCurrentUser
                    ? Colors.white.withOpacity(0.2)
                    : const Color(0xff0386FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getFileIcon(),
                color: widget.isCurrentUser ? Colors.white : const Color(0xff0386FF),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.message.fileName ?? 'File',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.isCurrentUser ? Colors.white : const Color(0xff2D3748),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.message.fileSizeFormatted,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: widget.isCurrentUser
                          ? Colors.white.withOpacity(0.7)
                          : const Color(0xff9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildTimestamp(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon() {
    final fileName = widget.message.fileName?.toLowerCase() ?? '';
    if (fileName.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (fileName.endsWith('.doc') || fileName.endsWith('.docx')) return Icons.description;
    if (fileName.endsWith('.xls') || fileName.endsWith('.xlsx')) return Icons.table_chart;
    if (fileName.endsWith('.ppt') || fileName.endsWith('.pptx')) return Icons.slideshow;
    if (fileName.endsWith('.zip') || fileName.endsWith('.rar')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Future<void> _openFile() async {
    final url = widget.message.fileUrl;
    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Widget _buildTimestamp() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTimestamp(widget.message.timestamp),
          style: GoogleFonts.inter(
            fontSize: 11,
            color: widget.isCurrentUser
                ? Colors.white.withOpacity(0.7)
                : const Color(0xff9CA3AF),
            fontWeight: FontWeight.w400,
          ),
        ),
        if (widget.isCurrentUser) ...[
          const SizedBox(width: 6),
          Icon(
            widget.message.isRead ? Icons.done_all : Icons.done,
            size: 14,
            color: widget.message.isRead
                ? const Color(0xff10B981)
                : Colors.white.withOpacity(0.7),
          ),
        ],
      ],
    );
  }

  Widget _buildReplyPreview() {
    final replyData =
        widget.message.metadata!['reply_to'] as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.isCurrentUser
            ? const Color(0xff0386FF).withOpacity(0.2)
            : const Color(0xffF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: widget.isCurrentUser
                ? const Color(0xff0386FF)
                : const Color(0xff6B7280),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyData['sender_name'] ?? 'User',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.isCurrentUser
                  ? const Color(0xff0386FF)
                  : const Color(0xff374151),
            ),
          ),
          Text(
            replyData['content'] ?? '',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: widget.isCurrentUser
                  ? const Color(0xff374151)
                  : const Color(0xff6B7280),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReactionPicker() {
    final reactions = ['👍', '❤️', '😂', '😮', '😢', '😡'];

    return Positioned(
      top: -50,
      right: widget.isCurrentUser ? 0 : null,
      left: widget.isCurrentUser ? null : 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: reactions
              .map(
                (reaction) => GestureDetector(
                  onTap: () {
                    widget.onReaction?.call(widget.message, reaction);
                    setState(() {
                      _showReactions = false;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      reaction,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildReactionsDisplay() {
    final reactions =
        widget.message.metadata!['reactions'] as Map<String, dynamic>;
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Wrap(
        children: reactions.entries.map((entry) {
          final reaction = entry.key;
          final count = entry.value as int;
          return Container(
            margin: const EdgeInsets.only(right: 4, top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(reaction, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 2),
                Text(
                  count.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showMessageMenu(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + size.width,
        offset.dy + size.height + 100,
      ),
      items: [
        PopupMenuItem(
          value: 'react',
          child: Row(
            children: [
              const Icon(Icons.emoji_emotions, color: Color(0xff6B7280)),
              const SizedBox(width: 12),
              Text(
                'React',
                style: GoogleFonts.inter(color: const Color(0xff374151)),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'reply',
          child: Row(
            children: [
              const Icon(Icons.reply, color: Color(0xff6B7280)),
              const SizedBox(width: 12),
              Text(
                'Reply',
                style: GoogleFonts.inter(color: const Color(0xff374151)),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy, color: Color(0xff6B7280)),
              const SizedBox(width: 12),
              Text(
                'Copy',
                style: GoogleFonts.inter(color: const Color(0xff374151)),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'forward',
          child: Row(
            children: [
              const Icon(Icons.forward, color: Color(0xff6B7280)),
              const SizedBox(width: 12),
              Text(
                'Forward',
                style: GoogleFonts.inter(color: const Color(0xff374151)),
              ),
            ],
          ),
        ),
        // Delete functionality disabled - messages are permanent
        // if (widget.isCurrentUser)
        //   PopupMenuItem(
        //     value: 'delete',
        //     child: Row(
        //       children: [
        //         const Icon(Icons.delete, color: Colors.red),
        //         const SizedBox(width: 12),
        //         Text(
        //           'Delete',
        //           style: GoogleFonts.inter(color: Colors.red),
        //         ),
        //       ],
        //     ),
        //   ),
      ],
    ).then((value) {
      if (value != null) {
        _handleMenuAction(value);
      }
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'react':
        setState(() {
          _showReactions = !_showReactions;
        });
        break;
      case 'reply':
        widget.onReply?.call(widget.message);
        break;
      case 'copy':
        Clipboard.setData(ClipboardData(text: widget.message.content));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Message copied to clipboard',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xff10B981),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case 'forward':
        widget.onForward?.call(widget.message);
        break;
      case 'delete':
        widget.onDelete?.call(widget.message);
        break;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      // Today - show time only
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Yesterday
      return 'Yesterday ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      // Older - show date and time
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
