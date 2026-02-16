import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:geolocator/geolocator.dart';
import '../services/chat_service.dart';
import '../services/chat_permission_service.dart';
import '../models/chat_user.dart';
import '../models/chat_message.dart';
import '../widgets/message_bubble.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/services/livekit_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../l10n/app_localizations.dart';

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
  final ChatPermissionService _permissionService = ChatPermissionService();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _isComposing = false;
  ChatMessage? _replyingTo;
  bool _hasPermission = true;
  bool _checkingPermission = true;
  String? _relationshipContext;
  bool _isUploading = false;
  
  final ImagePicker _imagePicker = ImagePicker();
  
  // Voice recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  String? _recordingPath;
  
  // Cache the messages stream to prevent rebuilding on every setState
  late Stream<List<ChatMessage>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _checkPermissionAndContext();
    
    // Set the current open chat to suppress notifications for this chat
    NotificationService.setCurrentOpenChat(widget.chatUser.id);
    
    // Initialize the messages stream once to prevent rebuilding on every setState
    _messagesStream = _chatService.getChatMessages(
      widget.chatUser.id,
      isGroupChat: widget.chatUser.isGroup,
    );
    
    // Mark messages as read when opening chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatService.markMessagesAsRead(
        widget.chatUser.id,
        isGroupChat: widget.chatUser.isGroup,
      );
    });
  }

  Future<void> _checkPermissionAndContext() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || widget.chatUser.isGroup) {
      setState(() {
        _checkingPermission = false;
        _hasPermission = widget.chatUser.isGroup; // Groups have their own permission logic
      });
      return;
    }

    try {
      final canMessage = await _permissionService.canMessage(currentUserId, widget.chatUser.id);
      final context = await _permissionService.getRelationshipContext(currentUserId, widget.chatUser.id);
      
      if (mounted) {
        setState(() {
          _hasPermission = canMessage;
          _relationshipContext = context;
          _checkingPermission = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error checking chat permission: $e');
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _checkingPermission = false;
        });
      }
    }
  }

  void _onTextChanged() {
    setState(() {
      _isComposing = _messageController.text.trim().isNotEmpty;
    });
  }

  @override
  @override
  void dispose() {
    // Clear the current open chat so notifications resume
    NotificationService.setCurrentOpenChat(null);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
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
        // Call buttons hidden for now - will implement WhatsApp-style calling later
        // _buildActionButton(Icons.call, () => _startAudioCall()),
        // _buildActionButton(Icons.videocam, () => _startVideoCall()),
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
              case 'edit_group':
                _showEditGroupDialog();
                break;
              case 'manage_members':
                _showManageMembersDialog();
                break;
              case 'leave_group':
                _showLeaveGroupDialog();
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
          AppLocalizations.of(context)!.chatOnline,
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
      stream: _messagesStream,
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
                  AppLocalizations.of(context)!.chatErrorLoadingMessages,
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
        if (messages.isNotEmpty) {
          final hasUnread = messages.any(
            (message) =>
                !message.isRead &&
                message.senderId != _chatService.currentUserId,
          );
          if (hasUnread) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _chatService.markMessagesAsRead(
                widget.chatUser.id,
                isGroupChat: widget.chatUser.isGroup,
              );
            });
          }
        }

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
                  AppLocalizations.of(context)!.startTheConversation,
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
              onImageTap: (url) => _showImagePreview(url),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageInput() {
    // Show permission denied message
    if (!widget.chatUser.isGroup && !_hasPermission && !_checkingPermission) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xffFEF2F2),
          border: Border(
            top: BorderSide(color: const Color(0xffFECACA), width: 1),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: Color(0xffEF4444), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.chatTeachingRelationshipOnly,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xffDC2626),
                ),
              ),
            ),
          ],
        ),
      );
    }

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
          // Relationship context indicator
          if (_relationshipContext != null && !widget.chatUser.isGroup)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xffF0F9FF),
              child: Row(
                children: [
                  Icon(
                    _getRelationshipIcon(),
                    size: 14,
                    color: const Color(0xff0369A1),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _relationshipContext!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xff0369A1),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
          // Reply preview
          if (_replyingTo != null) _buildReplyPreview(),

          // Message input row
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isRecording
                ? _buildRecordingControls()
                : Row(
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
                                  AppLocalizations.of(context)!.chatPhoto,
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
                                  AppLocalizations.of(context)!.chatCamera,
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
                                  AppLocalizations.of(context)!.chatDocument,
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
                                  AppLocalizations.of(context)!.chatLocation,
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
                          : GestureDetector(
                              onLongPressStart: (_) => _startRecording(),
                              onLongPressEnd: (_) => _stopRecordingAndSend(),
                              onTap: () => _showRecordingHint(),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Color(0xffE5E7EB),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.mic,
                                  color: Color(0xff6B7280),
                                  size: 20,
                                ),
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
                      const Icon(
                        Icons.reply,
                        size: 16,
                        color: Color(0xff0386FF),
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

  Future<void> _handleAttachment(String type) async {
    if (_isUploading) return;

    try {
      switch (type) {
        case 'photo':
          await _pickImage(ImageSource.gallery);
          break;
        case 'camera':
          await _pickImage(ImageSource.camera);
          break;
        case 'file':
          await _pickFile();
          break;
        case 'location':
          await _sendLocation();
          break;
      }
    } catch (e) {
      AppLogger.error('Error handling attachment: $e');
      _showMessage('Failed to send attachment');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() => _isUploading = true);
      _showMessage('Sending image...', isError: false);

      try {
        await _chatService.sendImageMessage(
          widget.chatUser.id,
          File(pickedFile.path),
          isGroupChat: widget.chatUser.isGroup,
        );
        _showMessage('Image sent!', isError: false);
      } catch (e) {
        _showMessage('Failed to send image');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'zip', 'rar'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isUploading = true);
      _showMessage('Sending file...', isError: false);

      try {
        await _chatService.sendFileMessage(
          widget.chatUser.id,
          File(result.files.single.path!),
          result.files.single.name,
          isGroupChat: widget.chatUser.isGroup,
        );
        _showMessage('File sent!', isError: false);
      } catch (e) {
        _showMessage('Failed to send file');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _sendLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage('Location permission is required');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage('Location permission permanently denied. Please enable in settings.');
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Please enable location services');
        return;
      }

      _showMessage('Getting your location...', isError: false);

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Send location message
      await _chatService.sendLocationMessage(
        widget.chatUser.id,
        position.latitude,
        position.longitude,
        'My Location',
        isGroupChat: widget.chatUser.isGroup,
      );

      _showMessage('Location sent!', isError: false);
    } catch (e) {
      AppLogger.error('Error sending location: $e');
      _showMessage('Failed to get location');
    }
  }

  Widget _buildRecordingControls() {
    return Row(
      children: [
        // Cancel button
        IconButton(
          onPressed: _cancelRecording,
          style: IconButton.styleFrom(
            backgroundColor: Colors.red.shade50,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12),
          ),
          icon: Icon(
            Icons.delete,
            color: Colors.red.shade400,
            size: 22,
          ),
        ),
        
        // Recording indicator - takes remaining space
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing red dot
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  builder: (context, value, child) {
                    return Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(value),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(value * 0.5),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    );
                  },
                  onEnd: () {
                    // This creates a continuous animation effect
                    if (mounted && _isRecording) {
                      setState(() {});
                    }
                  },
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.chatRecording,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatRecordingDuration(_recordingDuration),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Send button
        IconButton(
          onPressed: _stopRecordingAndSend,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xff0386FF),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12),
          ),
          icon: const Icon(
            Icons.send,
            color: Colors.white,
            size: 22,
          ),
        ),
      ],
    );
  }
  
  String _formatRecordingDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  void _showRecordingHint() {
    _showMessage('Hold to record a voice message', isError: false);
  }
  
  Future<void> _startRecording() async {
    try {
      // Check microphone permission
      if (!await _audioRecorder.hasPermission()) {
        _showMessage('Microphone permission is required');
        return;
      }
      
      // Get temp directory for recording
      final tempDir = await path_provider.getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${tempDir.path}/voice_$timestamp.m4a';
      
      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );
      
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });
      
      // Start duration timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _isRecording) {
          setState(() {
            _recordingDuration++;
          });
          
          // Auto-stop after 2 minutes
          if (_recordingDuration >= 120) {
            _stopRecordingAndSend();
          }
        }
      });
      
    } catch (e) {
      AppLogger.error('Error starting recording: $e');
      _showMessage('Failed to start recording');
    }
  }
  
  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    
    _recordingTimer?.cancel();
    
    try {
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
      });
      
      if (path == null || _recordingDuration < 1) {
        _showMessage('Recording too short', isError: false);
        return;
      }
      
      // Upload and send voice message
      await _sendVoiceMessage(path, _recordingDuration);
      
    } catch (e) {
      AppLogger.error('Error stopping recording: $e');
      _showMessage('Failed to send voice message');
      setState(() {
        _isRecording = false;
      });
    }
  }
  
  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    
    try {
      await _audioRecorder.stop();
      
      // Delete the temp file
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      AppLogger.error('Error canceling recording: $e');
    }
    
    setState(() {
      _isRecording = false;
      _recordingDuration = 0;
      _recordingPath = null;
    });
  }
  
  Future<void> _sendVoiceMessage(String filePath, int durationSeconds) async {
    setState(() {
      _isUploading = true;
    });
    
    try {
      final file = File(filePath);
      
      // Send voice message using ChatService
      await _chatService.sendVoiceMessage(
        widget.chatUser.id,
        file,
        durationSeconds,
        isGroupChat: widget.chatUser.isGroup,
      );
      
      // Clean up temp file
      if (await file.exists()) {
        await file.delete();
      }
      
    } catch (e) {
      AppLogger.error('Error sending voice message: $e');
      _showMessage('Failed to send voice message');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _startAudioCall() {
    if (widget.chatUser.isGroup) {
      _showMessage('Group calls are not supported yet');
      return;
    }
    
    // Start audio-only call via LiveKit
    LiveKitService.startCall(
      context,
      recipientId: widget.chatUser.id,
      recipientName: widget.chatUser.displayName,
      isAudioOnly: true,
    );
  }

  void _startVideoCall() {
    if (widget.chatUser.isGroup) {
      _showMessage('Group calls are not supported yet');
      return;
    }
    
    // Start video call via LiveKit
    LiveKitService.startCall(
      context,
      recipientId: widget.chatUser.id,
      recipientName: widget.chatUser.displayName,
      isAudioOnly: false,
    );
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(imageUrl),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Check permission before sending (for non-group chats)
    if (!widget.chatUser.isGroup && !_hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.youDonTHavePermissionTo,
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(0xffEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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

    _chatService.sendMessage(
      widget.chatUser.id,
      text,
      metadata: metadata,
      isGroupChat: widget.chatUser.isGroup,
    );
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

  IconData _getRelationshipIcon() {
    if (_relationshipContext == null) return Icons.person;
    if (_relationshipContext!.contains('teacher')) return Icons.school;
    if (_relationshipContext!.contains('Parent')) return Icons.family_restroom;
    if (_relationshipContext!.contains('Administrator')) return Icons.admin_panel_settings;
    return Icons.person;
  }

  void _setReplyMessage(ChatMessage message) {
    setState(() {
      _replyingTo = message;
    });
    _messageFocusNode.requestFocus();
  }

  void _deleteMessage(ChatMessage message) {
    // Check if user is the sender
    if (message.senderId != _chatService.currentUserId) {
      _showMessage('You can only delete your own messages');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.chatDeleteMessage,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          AppLocalizations.of(context)!.chatDeleteMessageConfirm,
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.commonCancel,
              style: GoogleFonts.inter(color: const Color(0xff6B7280)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await _chatService.deleteMessage(
                widget.chatUser.id,
                message.id,
                isGroupChat: widget.chatUser.isGroup,
              );
              if (success) {
                _showMessage('Message deleted', isError: false);
              } else {
                _showMessage('Failed to delete message');
              }
            },
            child: Text(
              AppLocalizations.of(context)!.commonDelete,
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _forwardMessage(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => _ForwardMessageDialog(
        chatService: _chatService,
        message: message,
        currentChatId: widget.chatUser.id,
        onMessageForwarded: () {
          _showMessage('Message forwarded', isError: false);
        },
      ),
    );
  }

  void _addReaction(ChatMessage message, String reaction) async {
    final success = await _chatService.addReaction(
      widget.chatUser.id,
      message.id,
      reaction,
      isGroupChat: widget.chatUser.isGroup,
    );

    if (success) {
      _showMessage('$reaction added', isError: false);
    } else {
      _showMessage('Failed to add reaction');
    }
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.chatClearChat,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          AppLocalizations.of(context)!.chatClearChatConfirm,
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.commonCancel,
              style: GoogleFonts.inter(color: const Color(0xff6B7280)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await _chatService.clearChat(
                widget.chatUser.id,
                isGroupChat: widget.chatUser.isGroup,
              );
              if (success) {
                _showMessage('Chat cleared', isError: false);
              } else {
                _showMessage('Failed to clear chat');
              }
            },
            child: Text(
              AppLocalizations.of(context)!.commonClear,
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockUserDialog() async {
    // First check if user is already blocked
    final isBlocked = await _chatService.isUserBlocked(widget.chatUser.id);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isBlocked ? 'Unblock User' : AppLocalizations.of(context)!.chatBlockUser,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          isBlocked
              ? 'Are you sure you want to unblock ${widget.chatUser.displayName}? They will be able to send you messages again.'
              : 'Are you sure you want to block ${widget.chatUser.displayName}? They will no longer be able to send you messages.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.commonCancel,
              style: GoogleFonts.inter(color: const Color(0xff6B7280)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              bool success;
              if (isBlocked) {
                success = await _chatService.unblockUser(widget.chatUser.id);
                if (success) {
                  _showMessage('${widget.chatUser.displayName} unblocked', isError: false);
                }
              } else {
                success = await _chatService.blockUser(widget.chatUser.id);
                if (success) {
                  _showMessage('${widget.chatUser.displayName} blocked', isError: false);
                }
              }
              if (!success) {
                _showMessage('Failed to ${isBlocked ? 'unblock' : 'block'} user');
              }
            },
            child: Text(
              isBlocked ? 'Unblock' : AppLocalizations.of(context)!.block,
              style: GoogleFonts.inter(color: isBlocked ? const Color(0xff059669) : Colors.red),
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
              AppLocalizations.of(context)!.chatClearChat,
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
                AppLocalizations.of(context)!.groupInfo,
                style: GoogleFonts.inter(color: const Color(0xff374151)),
              ),
            ],
          ),
        ),
      );

      // Edit group option (admin only - will check dynamically)
      items.add(
        PopupMenuItem(
          value: 'edit_group',
          child: Row(
            children: [
              const Icon(Icons.edit, color: Color(0xff0386FF)),
              const SizedBox(width: 12),
              Text(
                'Edit Group',
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
                AppLocalizations.of(context)!.chatAddMembers,
                style: GoogleFonts.inter(color: const Color(0xff374151)),
              ),
            ],
          ),
        ),
      );

      // Manage members option (admin only - view/remove members)
      items.add(
        PopupMenuItem(
          value: 'manage_members',
          child: Row(
            children: [
              const Icon(Icons.group, color: Color(0xff6366F1)),
              const SizedBox(width: 12),
              Text(
                'Manage Members',
                style: GoogleFonts.inter(color: const Color(0xff374151)),
              ),
            ],
          ),
        ),
      );

      // Leave group option
      items.add(
        PopupMenuItem(
          value: 'leave_group',
          child: Row(
            children: [
              const Icon(Icons.exit_to_app, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                'Leave Group',
                style: GoogleFonts.inter(color: Colors.red),
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
                AppLocalizations.of(context)!.chatBlockUser,
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
          AppLocalizations.of(context)!.chatGroupInfo,
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
              AppLocalizations.of(context)!.commonClose,
              style: GoogleFonts.inter(color: const Color(0xff0386FF)),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditGroupDialog() async {
    if (widget.chatUser.role != 'group') return;

    final isAdmin = await _chatService.isGroupAdmin(widget.chatUser.id);
    if (!isAdmin) {
      _showMessage('Only group administrators can edit group info');
      return;
    }

    final groupDetails = await _chatService.getGroupDetails(widget.chatUser.id);
    if (groupDetails == null) return;

    showDialog(
      context: context,
      builder: (context) => _EditGroupDialog(
        chatService: _chatService,
        groupChatId: widget.chatUser.id,
        currentName: groupDetails['group_name'] ?? '',
        currentDescription: groupDetails['group_description'] ?? '',
        onGroupUpdated: () {
          _showMessage('Group updated successfully!', isError: false);
        },
      ),
    );
  }

  void _showManageMembersDialog() async {
    if (widget.chatUser.role != 'group') return;

    final isAdmin = await _chatService.isGroupAdmin(widget.chatUser.id);

    showDialog(
      context: context,
      builder: (context) => _ManageMembersDialog(
        chatService: _chatService,
        groupChatId: widget.chatUser.id,
        isAdmin: isAdmin,
        currentUserId: _chatService.currentUserId ?? '',
        onMemberRemoved: () {
          _showMessage('Member removed from group', isError: false);
        },
      ),
    );
  }

  void _showLeaveGroupDialog() async {
    if (widget.chatUser.role != 'group') return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Leave Group',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to leave "${widget.chatUser.displayName}"? You will no longer receive messages from this group.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.commonCancel,
              style: GoogleFonts.inter(color: const Color(0xff6B7280)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await _chatService.leaveGroup(widget.chatUser.id);
              if (success) {
                _showMessage('You have left the group', isError: false);
                // Navigate back to chat list
                if (mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                _showMessage('Failed to leave group');
              }
            },
            child: Text(
              'Leave',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xffEF4444) : const Color(0xff059669),
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
        AppLocalizations.of(context)!.chatAddMembers,
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
              return Center(
                child: Text(AppLocalizations.of(context)!.errorLoadingUsers),
              );
            }

            final allUsers = snapshot.data ?? [];
            // Filter out users who are already in the group
            final availableUsers = allUsers
                .where((user) => !widget.currentParticipants.contains(user.id))
                .toList();

            if (availableUsers.isEmpty) {
              return Center(
                child: Text(AppLocalizations.of(context)!.noUsersAvailableToAdd),
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
            AppLocalizations.of(context)!.commonCancel,
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
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.failedToAddMembers),
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

// Dialog widget for editing group info
class _EditGroupDialog extends StatefulWidget {
  final ChatService chatService;
  final String groupChatId;
  final String currentName;
  final String currentDescription;
  final VoidCallback onGroupUpdated;

  const _EditGroupDialog({
    required this.chatService,
    required this.groupChatId,
    required this.currentName,
    required this.currentDescription,
    required this.onGroupUpdated,
  });

  @override
  State<_EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<_EditGroupDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _descriptionController = TextEditingController(text: widget.currentDescription);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Edit Group',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: GoogleFonts.inter(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
                ),
              ),
              style: GoogleFonts.inter(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: GoogleFonts.inter(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
                ),
              ),
              style: GoogleFonts.inter(),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            AppLocalizations.of(context)!.commonCancel,
            style: GoogleFonts.inter(color: const Color(0xff6B7280)),
          ),
        ),
        TextButton(
          onPressed: _isLoading || _nameController.text.trim().isEmpty
              ? null
              : () async {
                  setState(() => _isLoading = true);

                  final success = await widget.chatService.updateGroupInfo(
                    widget.groupChatId,
                    name: _nameController.text.trim(),
                    description: _descriptionController.text.trim(),
                  );

                  setState(() => _isLoading = false);

                  if (success) {
                    widget.onGroupUpdated();
                    if (mounted) Navigator.of(context).pop();
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to update group'),
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
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
                  ),
                )
              : Text(
                  'Save',
                  style: GoogleFonts.inter(color: const Color(0xff0386FF)),
                ),
        ),
      ],
    );
  }
}

// Dialog widget for managing group members
class _ManageMembersDialog extends StatefulWidget {
  final ChatService chatService;
  final String groupChatId;
  final bool isAdmin;
  final String currentUserId;
  final VoidCallback onMemberRemoved;

  const _ManageMembersDialog({
    required this.chatService,
    required this.groupChatId,
    required this.isAdmin,
    required this.currentUserId,
    required this.onMemberRemoved,
  });

  @override
  State<_ManageMembersDialog> createState() => _ManageMembersDialogState();
}

class _ManageMembersDialogState extends State<_ManageMembersDialog> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  String? _removingMemberId;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final members = await widget.chatService.getGroupMembers(widget.groupChatId);
    if (mounted) {
      setState(() {
        _members = members;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeMember(String memberId, String memberName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove Member',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to remove $memberName from this group?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              AppLocalizations.of(context)!.commonCancel,
              style: GoogleFonts.inter(color: const Color(0xff6B7280)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Remove',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _removingMemberId = memberId);

    final success = await widget.chatService.removeMemberFromGroup(
      widget.groupChatId,
      memberId,
    );

    if (success) {
      widget.onMemberRemoved();
      await _loadMembers();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove member'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _removingMemberId = null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Group Members',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
                ),
              )
            : _members.isEmpty
                ? Center(
                    child: Text(
                      'No members found',
                      style: GoogleFonts.inter(color: const Color(0xff6B7280)),
                    ),
                  )
                : ListView.builder(
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final isCurrentUser = member['id'] == widget.currentUserId;
                      final isAdmin = member['isAdmin'] == true;
                      final isCreator = member['isCreator'] == true;
                      final canRemove = widget.isAdmin && !isCurrentUser && !isAdmin;

                      return ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xff0386FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: member['profilePicture'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Image.network(
                                    member['profilePicture'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Text(
                                        _getInitials(member['name'] ?? ''),
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xff0386FF),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    _getInitials(member['name'] ?? ''),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xff0386FF),
                                    ),
                                  ),
                                ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                member['name'] ?? 'Unknown',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrentUser)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xff6B7280).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'You',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xff6B7280),
                                  ),
                                ),
                              ),
                            if (isCreator)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xff059669).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Creator',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xff059669),
                                  ),
                                ),
                              )
                            else if (isAdmin)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xff0386FF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Admin',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xff0386FF),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          member['role'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xff6B7280),
                          ),
                        ),
                        trailing: canRemove
                            ? _removingMemberId == member['id']
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                    onPressed: () => _removeMember(
                                      member['id'],
                                      member['name'] ?? 'this member',
                                    ),
                                    tooltip: 'Remove from group',
                                  )
                            : null,
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            AppLocalizations.of(context)!.commonClose,
            style: GoogleFonts.inter(color: const Color(0xff0386FF)),
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

// Dialog widget for forwarding messages
class _ForwardMessageDialog extends StatefulWidget {
  final ChatService chatService;
  final ChatMessage message;
  final String currentChatId;
  final VoidCallback onMessageForwarded;

  const _ForwardMessageDialog({
    required this.chatService,
    required this.message,
    required this.currentChatId,
    required this.onMessageForwarded,
  });

  @override
  State<_ForwardMessageDialog> createState() => _ForwardMessageDialogState();
}

class _ForwardMessageDialogState extends State<_ForwardMessageDialog> {
  String? _selectedChatId;
  bool _isForwarding = false;
  bool _isGroupChat = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Forward Message',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // Message preview
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xffF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.message.content,
                    style: GoogleFonts.inter(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              'Select a chat:',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff374151),
              ),
            ),
            const SizedBox(height: 8),
            // Chat list
            Expanded(
              child: StreamBuilder<List<ChatUser>>(
                stream: widget.chatService.getUserChats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
                      ),
                    );
                  }

                  final chats = snapshot.data ?? [];
                  // Filter out current chat
                  final availableChats = chats.where((chat) => chat.id != widget.currentChatId).toList();

                  if (availableChats.isEmpty) {
                    return Center(
                      child: Text(
                        'No other chats available',
                        style: GoogleFonts.inter(color: const Color(0xff6B7280)),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: availableChats.length,
                    itemBuilder: (context, index) {
                      final chat = availableChats[index];
                      final isSelected = _selectedChatId == chat.id;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: const Color(0xff0386FF).withValues(alpha: 0.1),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: chat.isGroup
                                ? const Color(0xff059669).withValues(alpha: 0.1)
                                : const Color(0xff0386FF).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: chat.profilePicture != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Image.network(
                                    chat.profilePicture!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: chat.isGroup
                                          ? const Icon(Icons.group, size: 20, color: Color(0xff059669))
                                          : Text(
                                              chat.initials,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xff0386FF),
                                              ),
                                            ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: chat.isGroup
                                      ? const Icon(Icons.group, size: 20, color: Color(0xff059669))
                                      : Text(
                                          chat.initials,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xff0386FF),
                                          ),
                                        ),
                                ),
                        ),
                        title: Text(
                          chat.displayName,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: chat.isGroup
                            ? Text(
                                'Group',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xff059669),
                                ),
                              )
                            : Text(
                                chat.role ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xff6B7280),
                                ),
                              ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Color(0xff0386FF))
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedChatId = chat.id;
                            _isGroupChat = chat.isGroup;
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            AppLocalizations.of(context)!.commonCancel,
            style: GoogleFonts.inter(color: const Color(0xff6B7280)),
          ),
        ),
        TextButton(
          onPressed: _selectedChatId == null || _isForwarding
              ? null
              : () async {
                  setState(() => _isForwarding = true);

                  final success = await widget.chatService.forwardMessage(
                    widget.message,
                    _selectedChatId!,
                    isTargetGroupChat: _isGroupChat,
                  );

                  setState(() => _isForwarding = false);

                  if (success) {
                    widget.onMessageForwarded();
                    if (mounted) Navigator.of(context).pop();
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to forward message'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
          child: _isForwarding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
                  ),
                )
              : Text(
                  'Forward',
                  style: GoogleFonts.inter(color: const Color(0xff0386FF)),
                ),
        ),
      ],
    );
  }
}
