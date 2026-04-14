import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import 'voice_message_player.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isCurrentUser;
  final bool isOtherAdmin;
  final String? currentUserId;
  final Function(ChatMessage)? onReply;
  final Function(ChatMessage)? onDelete;
  final Function(ChatMessage)? onForward;
  final Function(ChatMessage, String)? onReaction;
  final Function(String)? onImageTap;
  final Function(ChatMessage)? onEdit;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.isOtherAdmin = false,
    this.currentUserId,
    this.onReply,
    this.onDelete,
    this.onForward,
    this.onReaction,
    this.onImageTap,
    this.onEdit,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  static const String _moreReactionToken = '__more__';
  static const List<String> _quickReactions = <String>[
    '👍',
    '❤️',
    '😂',
    '🎉',
    '😮',
    '😢',
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.message.isSystem) {
      return _buildSystemMessage();
    }

    // Other admin messages align right (like current user) but with a distinct color
    final bool alignRight = widget.isCurrentUser || widget.isOtherAdmin;

    // Blue for current user, teal for other admin, white for regular user
    final Color bubbleColor = widget.isCurrentUser
        ? const Color(0xff0386FF)
        : widget.isOtherAdmin
            ? const Color(0xff0F766E)
            : Colors.white;

    return GestureDetector(
      onLongPress: () => _showMessageMenu(context),
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: alignRight ? 48 : 12,
          right: alignRight ? 12 : 48,
        ),
        child: Row(
          mainAxisAlignment: alignRight
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Profile picture for received messages
            if (!alignRight) ...[
              _buildAvatar(),
              const SizedBox(width: 8),
            ],

            Flexible(
              child: Column(
                crossAxisAlignment: alignRight
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Sender name (for received messages and other admin messages)
                  if (!widget.isCurrentUser &&
                      widget.message.senderName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        widget.message.senderName,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: widget.isOtherAdmin
                              ? const Color(0xff0F766E)
                              : const Color(0xff0386FF),
                        ),
                      ),
                    ),

                  // Reply preview
                  if (!widget.message.deletedForEveryone &&
                      widget.message.metadata != null &&
                      widget.message.metadata!['reply_to'] != null)
                    _buildReplyPreview(),

                  // Message bubble
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft:
                            Radius.circular(alignRight ? 20 : 4),
                        bottomRight:
                            Radius.circular(alignRight ? 4 : 20),
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
                        bottomLeft:
                            Radius.circular(widget.isCurrentUser ? 20 : 4),
                        bottomRight:
                            Radius.circular(widget.isCurrentUser ? 4 : 20),
                      ),
                      child: _buildMessageContent(),
                    ),
                  ),

                  // Message reactions display
                  if (widget.message.hasReactions) _buildReactionsDisplay(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessage() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB).withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          widget.message.content,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final profilePic = widget.message.senderProfilePicture;
    final initials = widget.message.senderName.isNotEmpty
        ? widget.message.senderName
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
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
    if (widget.message.deletedForEveryone) {
      return _buildDeletedMessage();
    } else if (widget.message.isImage) {
      return _buildImageMessage();
    } else if (widget.message.isVideo) {
      return _buildVideoMessage();
    } else if (widget.message.isLocation) {
      return _buildLocationMessage();
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
    final mimeType = widget.message.voiceMimeType;

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
            mimeType: mimeType,
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
          _buildRichText(widget.message.content),
          const SizedBox(height: 6),
          _buildTimestamp(),
        ],
      ),
    );
  }

  Widget _buildDeletedMessage() {
    final text = widget.message.deletedPreviewText(widget.currentUserId);
    final textColor = widget.isCurrentUser
        ? Colors.white.withValues(alpha: 0.88)
        : const Color(0xFF6B7280);
    final iconColor = widget.isCurrentUser
        ? Colors.white.withValues(alpha: 0.72)
        : const Color(0xFF9CA3AF);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block_outlined,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: textColor,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildTimestamp(),
        ],
      ),
    );
  }

  Widget _buildRichText(String text) {
    final mentionRegex = RegExp(r'@(\w[\w\s]*?)(?=\s@|\s[^@]|$)');
    final matches = mentionRegex.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: (widget.isCurrentUser || widget.isOtherAdmin) ? Colors.white : const Color(0xff2D3748),
          height: 1.4,
        ),
      );
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: widget.isCurrentUser
              ? const Color(0xFFBBDEFB)
              : const Color(0xFF0386FF),
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: 15,
          color: (widget.isCurrentUser || widget.isOtherAdmin) ? Colors.white : const Color(0xff2D3748),
          height: 1.4,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildImageMessage() {
    final imageUrl = widget.message.fileUrl;
    final caption = widget.message.metadata?['caption'] as String?;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (caption != null && caption.isNotEmpty) ...[
                _buildRichText(caption),
                const SizedBox(height: 4),
              ],
              _buildTimestamp(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoMessage() {
    final videoUrl = widget.message.fileUrl;
    final caption = widget.message.metadata?['caption'] as String?;
    final videoWidth =
        math.min(MediaQuery.of(context).size.width * 0.62, 250.0);
    final videoHeight = videoWidth * 0.72;

    if (videoUrl == null || videoUrl.isEmpty) {
      return _buildTextMessage();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _openVideoPlayer(videoUrl, caption: caption),
          child: SizedBox(
            width: videoWidth,
            height: videoHeight,
            child: _InlineChatVideoPlayer(
              key: ValueKey('${widget.message.id}:$videoUrl'),
              videoUrl: videoUrl,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_rounded,
                    size: 14,
                    color: widget.isCurrentUser
                        ? Colors.white.withValues(alpha: 0.85)
                        : const Color(0xff6B7280),
                  ),
                  if (widget.message.fileSizeFormatted.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      widget.message.fileSizeFormatted,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: widget.isCurrentUser
                            ? Colors.white.withValues(alpha: 0.8)
                            : const Color(0xff6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              if (caption != null && caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildRichText(caption),
                const SizedBox(height: 4),
              ],
              _buildTimestamp(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationMessage() {
    final latitude = widget.message.latitude;
    final longitude = widget.message.longitude;
    final title = widget.message.locationName ?? 'Shared location';
    final subtitle = widget.message.locationSubtitle;
    final canOpenMap = latitude != null && longitude != null;
    final coordinateText = canOpenMap
        ? '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}'
        : null;
    final bool isDarkBubble = widget.isCurrentUser || widget.isOtherAdmin;
    final accentColor = isDarkBubble
        ? const Color(0xFF7DD3FC)
        : const Color(0xFF0891B2);
    final primaryTextColor =
        isDarkBubble ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDarkBubble
        ? Colors.white.withValues(alpha: 0.78)
        : const Color(0xFF6B7280);

    return InkWell(
      onTap: canOpenMap
          ? () => _openLocation(
                latitude,
                longitude,
                title,
                subtitle: subtitle,
              )
          : null,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 252,
        decoration: BoxDecoration(
          color: widget.isCurrentUser
              ? const Color(0xFF082F49)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: widget.isCurrentUser
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 126,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(21),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isCurrentUser
                      ? const [
                          Color(0xFF0C4A6E),
                          Color(0xFF075985),
                          Color(0xFF0369A1),
                        ]
                      : const [
                          Color(0xFFE2E8F0),
                          Color(0xFFF8FAFC),
                          Color(0xFFE2E8F0),
                        ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 14,
                    top: 20,
                    right: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: widget.isCurrentUser
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Pinned location',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: widget.isCurrentUser
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  canOpenMap
                                      ? 'Tap to choose a map app'
                                      : 'Location unavailable',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: widget.isCurrentUser
                                        ? Colors.white.withValues(alpha: 0.74)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 72,
                    child: Transform.rotate(
                      angle: -0.32,
                      child: Container(
                        width: 108,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 22,
                    top: 78,
                    child: Transform.rotate(
                      angle: 0.48,
                      child: Container(
                        width: 92,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 126,
                    top: 50,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.place_rounded,
                        color: accentColor,
                        size: 24,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 112,
                    bottom: 18,
                    child: Container(
                      width: 68,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                      height: 1.25,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: secondaryTextColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (coordinateText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      coordinateText,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isCurrentUser
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 14,
                              color: widget.isCurrentUser
                                  ? Colors.white
                                  : const Color(0xFF0369A1),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Choose map app',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: widget.isCurrentUser
                                    ? Colors.white
                                    : const Color(0xFF0369A1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _buildTimestamp(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                color: widget.isCurrentUser
                    ? Colors.white
                    : const Color(0xff0386FF),
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
                      color: widget.isCurrentUser
                          ? Colors.white
                          : const Color(0xff2D3748),
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
    if (fileName.endsWith('.doc') || fileName.endsWith('.docx'))
      return Icons.description;
    if (fileName.endsWith('.xls') || fileName.endsWith('.xlsx'))
      return Icons.table_chart;
    if (fileName.endsWith('.ppt') || fileName.endsWith('.pptx'))
      return Icons.slideshow;
    if (fileName.endsWith('.zip') || fileName.endsWith('.rar'))
      return Icons.folder_zip;
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

  Future<void> _openVideoPlayer(String videoUrl, {String? caption}) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ChatVideoPlayerScreen(
          videoUrl: videoUrl,
          caption: caption,
        ),
      ),
    );
  }

  Future<void> _openLocation(double latitude, double longitude, String label,
      {String? subtitle}) async {
    if (kIsWeb) {
      await _openLocationFallback(latitude, longitude);
      return;
    }

    try {
      final availableMaps = await MapLauncher.installedMaps;
      if (!mounted) return;

      if (availableMaps.isEmpty) {
        await _openLocationFallback(latitude, longitude);
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.map_rounded,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Open location',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: availableMaps.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final map = availableMaps[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              Navigator.of(sheetContext).pop();
                              await map.showMarker(
                                coords: Coords(latitude, longitude),
                                title: label,
                                description: subtitle,
                              );
                            },
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SvgPicture.asset(
                                    map.icon,
                                    width: 28,
                                    height: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      map.mapName,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (_) {
      await _openLocationFallback(latitude, longitude);
    }
  }

  Future<void> _openLocationFallback(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildTimestamp() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.message.isEdited) ...[
          Text(
            'edited ',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: widget.isCurrentUser
                  ? Colors.white.withOpacity(0.6)
                  : const Color(0xff9CA3AF),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
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

  Future<void> _showReactionPicker() async {
    final selectedReaction = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final currentUserReaction = widget.currentUserId == null
            ? null
            : widget.message.reactions?[widget.currentUserId!];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          AppLocalizations.of(context)!.chatReact,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 58,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _quickReactions.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            if (index == _quickReactions.length) {
                              return InkWell(
                                onTap: () => Navigator.of(
                                  sheetContext,
                                ).pop(_moreReactionToken),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.add_reaction_outlined,
                                        color: Color(0xFF0386FF),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'More',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF374151),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final reaction = _quickReactions[index];
                            final isSelected = currentUserReaction == reaction;
                            return InkWell(
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(reaction),
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 54,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFE0F2FE)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF0386FF)
                                        : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  reaction,
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    String? resolvedReaction = selectedReaction;
    if (selectedReaction == _moreReactionToken) {
      resolvedReaction = await _showFullReactionPicker();
    }

    if (resolvedReaction != null) {
      widget.onReaction?.call(widget.message, resolvedReaction);
    }
  }

  Future<String?> _showFullReactionPicker() {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              height: 380,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.chatReact,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: emoji_picker.EmojiPicker(
                      onEmojiSelected: (_, emoji) =>
                          Navigator.of(sheetContext).pop(emoji.emoji),
                      config: const emoji_picker.Config(
                        height: 320,
                        emojiViewConfig: emoji_picker.EmojiViewConfig(
                          backgroundColor: Colors.white,
                          columns: 8,
                          emojiSizeMax: 28,
                        ),
                        categoryViewConfig: emoji_picker.CategoryViewConfig(
                          backgroundColor: Colors.white,
                          indicatorColor: Color(0xFF0386FF),
                          iconColor: Color(0xFF94A3B8),
                          iconColorSelected: Color(0xFF0386FF),
                          backspaceColor: Color(0xFF0386FF),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReactionsDisplay() {
    final reactionCounts = widget.message.reactionCounts;
    if (reactionCounts.isEmpty) return const SizedBox.shrink();
    final currentUserReaction = widget.currentUserId == null
        ? null
        : widget.message.reactions?[widget.currentUserId!];

    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Wrap(
        children: reactionCounts.entries.map((entry) {
          final emoji = entry.key;
          final count = entry.value;
          final isSelected = currentUserReaction == emoji;
          return Container(
            margin: const EdgeInsets.only(right: 4, top: 2),
            child: InkWell(
              onTap: () => widget.onReaction?.call(widget.message, emoji),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE0F2FE) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0386FF)
                        : const Color(0xffE5E7EB),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 12)),
                    if (count > 1) ...[
                      const SizedBox(width: 4),
                      Text(
                        count.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xff6B7280),
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
    final canEdit = widget.isCurrentUser &&
        !widget.message.deletedForEveryone &&
        (widget.message.messageType == 'text' ||
            widget.message.messageType == null);
    final canReact = !widget.message.deletedForEveryone;
    final canReply = !widget.message.deletedForEveryone;
    final canCopy = !widget.message.deletedForEveryone &&
        (widget.message.messageType == 'text' ||
            widget.message.messageType == null);
    final canForward = !widget.message.deletedForEveryone;
    final menuItems = <PopupMenuEntry<String>>[
      if (canReact)
        PopupMenuItem(
          value: 'react',
          child: Row(
            children: [
              const Icon(Icons.emoji_emotions, color: Color(0xff6B7280)),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.chatReact,
                style: GoogleFonts.inter(color: const Color(0xff374151)),
              ),
            ],
          ),
        ),
      if (canReply)
        PopupMenuItem(
          value: 'reply',
          child: Row(
            children: [
              const Icon(Icons.reply, color: Color(0xff6B7280)),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.chatReply,
                style: GoogleFonts.inter(color: const Color(0xff374151)),
              ),
            ],
          ),
        ),
      if (canCopy)
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy, color: Color(0xff6B7280)),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.commonCopy,
                style: GoogleFonts.inter(color: const Color(0xff374151)),
              ),
            ],
          ),
        ),
      if (canForward)
        PopupMenuItem(
          value: 'forward',
          child: Row(
            children: [
              const Icon(Icons.forward, color: Color(0xff6B7280)),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.chatForward,
                style: GoogleFonts.inter(color: const Color(0xff374151)),
              ),
            ],
          ),
        ),
      if (canEdit)
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit, color: Color(0xff6B7280)),
              const SizedBox(width: 12),
              Text(
                'Edit',
                style: GoogleFonts.inter(color: const Color(0xff374151)),
              ),
            ],
          ),
        ),
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.red),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context)!.commonDelete,
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ],
        ),
      ),
    ];

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + size.width,
        offset.dy + size.height + 100,
      ),
      items: menuItems,
    ).then((value) {
      if (value != null) {
        _handleMenuAction(value);
      }
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'react':
        _showReactionPicker();
        break;
      case 'reply':
        widget.onReply?.call(widget.message);
        break;
      case 'copy':
        Clipboard.setData(ClipboardData(text: widget.message.content));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.chatCopied,
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
      case 'edit':
        widget.onEdit?.call(widget.message);
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

class _InlineChatVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const _InlineChatVideoPlayer({super.key, required this.videoUrl});

  @override
  State<_InlineChatVideoPlayer> createState() => _InlineChatVideoPlayerState();
}

class _InlineChatVideoPlayerState extends State<_InlineChatVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = _buildController(widget.videoUrl);
    _initializeController();
  }

  @override
  void didUpdateWidget(covariant _InlineChatVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller.dispose();
      _isInitialized = false;
      _hasError = false;
      _controller = _buildController(widget.videoUrl);
      _initializeController();
    }
  }

  VideoPlayerController _buildController(String url) {
    return VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
      ),
    );
  }

  Future<void> _initializeController() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(false);
      await _controller.setVolume(0);
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildFallback(
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              color: Colors.white70,
              size: 38,
            ),
            SizedBox(height: 8),
            Text(
              'Open video',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return _buildFallback(
        child: const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1 / 0.72,
      child: _buildVideoFrame(),
    );
  }

  Widget _buildVideoFrame() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: Colors.black,
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final videoSize = value.isInitialized ? value.size : Size.zero;

            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: videoSize.isEmpty
                      ? const SizedBox.shrink()
                      : ClipRect(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: videoSize.width,
                              height: videoSize.height,
                              child: VideoPlayer(_controller),
                            ),
                          ),
                        ),
                ),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                    child: LinearProgressIndicator(
                      value: value.isInitialized &&
                              value.duration.inMilliseconds > 0
                          ? value.position.inMilliseconds /
                              value.duration.inMilliseconds
                          : 0,
                      minHeight: 3,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF0386FF),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFallback({required Widget child}) {
    return Container(
      height: 200,
      width: 250,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _ChatVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String? caption;

  const _ChatVideoPlayerScreen({
    required this.videoUrl,
    this.caption,
  });

  @override
  State<_ChatVideoPlayerScreen> createState() => _ChatVideoPlayerScreenState();
}

class _ChatVideoPlayerScreenState extends State<_ChatVideoPlayerScreen> {
  late final VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(false);
      await _controller.setVolume(1.0);
      await _controller.play();
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
      });
    }
  }

  bool _isFinished(VideoPlayerValue value) {
    if (!value.isInitialized || value.duration == Duration.zero) {
      return false;
    }
    return value.position >= value.duration - const Duration(milliseconds: 300);
  }

  Future<void> _togglePlayback() async {
    if (!_isInitialized) return;
    final value = _controller.value;
    if (_isFinished(value)) {
      await _controller.seekTo(Duration.zero);
      await _controller.play();
      return;
    }
    if (value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _hasError
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                            size: 44,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Unable to play this video.',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : !_isInitialized
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: _controller,
                          builder: (context, value, _) {
                            final isFinished = _isFinished(value);
                            final showOverlay = !value.isPlaying;

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: value.aspectRatio <= 0
                                          ? 16 / 9
                                          : value.aspectRatio,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Positioned.fill(
                                            child: VideoPlayer(_controller),
                                          ),
                                          Positioned.fill(
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: _togglePlayback,
                                              child: Container(
                                                color: Colors.transparent,
                                              ),
                                            ),
                                          ),
                                          if (showOverlay)
                                            Container(
                                              width: 68,
                                              height: 68,
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withValues(alpha: 0.42),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isFinished
                                                    ? Icons.replay_rounded
                                                    : Icons.play_arrow_rounded,
                                                color: Colors.white,
                                                size: 42,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 0, 20, 28),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      VideoProgressIndicator(
                                        _controller,
                                        allowScrubbing: true,
                                        colors: const VideoProgressColors(
                                          playedColor: Color(0xFF38BDF8),
                                          bufferedColor: Colors.white38,
                                          backgroundColor: Colors.white24,
                                        ),
                                      ),
                                      if (widget.caption != null &&
                                          widget.caption!
                                              .trim()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        Text(
                                          widget.caption!.trim(),
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
