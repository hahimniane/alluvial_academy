import 'package:alluwalacademyadmin/const.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// /// Feed Screen widget
// class FeedScreen extends StatelessWidget {
//   const FeedScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Text(
//         "this is the Feed screenn",
//         style: openSansHebrewTextStyle,
//       ),
//     );
//   }
// }

// class FeedScreen extends StatelessWidget {
//   const FeedScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         useMaterial3: true,
//         colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff4A5BF6)),
//         scaffoldBackgroundColor: const Color(0xFFF0F4F9),
//       ),
//       home: const ChatScreen(),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Models
class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });
}

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
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<FeedScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _chatScrollController = ScrollController();

  String _hoveredChatId = '';
  bool _isSearchFocused = false;
  String _selectedTab = 'All';
  final String _currentUserId =
      'ySm53rwQszPGceGjBQaYLOMAEet1'; // Simulating current user
  ChatUser? _selectedChat;
  List<ChatMessage> _currentMessages = [];

  // Mock data
  final List<ChatUser> _allChats = [
    ChatUser(
      id: 'team',
      name: "All users' team chat",
      subtitle: '2 Members',
      icon: Icons.group,
      messages: [
        ChatMessage(
          id: '1',
          senderId: 'user1',
          text: 'Hello team!',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
        ),
        ChatMessage(
          id: '2',
          senderId: 'currentUser',
          text: 'Hi everyone, how are you?',
          timestamp: DateTime.now().subtract(const Duration(hours: 23)),
        ),
      ],
    ),
    ChatUser(
      id: 'sulaiman',
      name: 'Sulaiman Barry',
      subtitle: 'Designer',
      icon: Icons.person,
      isOnline: true,
      messages: [
        ChatMessage(
          id: '3',
          senderId: 'sulaiman',
          text: 'Can you review the latest design?',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        ChatMessage(
          id: '4',
          senderId: 'currentUser',
          text: 'Sure, I\'ll take a look now',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ],
    ),
    ChatUser(
      id: 'tips',
      name: 'Connecteam Tips',
      subtitle: 'Videos',
      icon: Icons.play_circle_outlined,
      messages: [],
    ),
  ];

  List<ChatUser> _filteredChats = [];

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onSearchFocusChange);
    _filteredChats = _allChats;
    _selectedChat = _allChats[0];
    _currentMessages = _selectedChat!.messages;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchFocus.removeListener(_onSearchFocusChange);
    _searchFocus.dispose();
    _scrollController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _onSearchFocusChange() {
    setState(() {
      _isSearchFocused = _searchFocus.hasFocus;
    });
  }

  void _filterChats(String searchTerm) {
    setState(() {
      _filteredChats = _allChats
          .where((chat) =>
              chat.name.toLowerCase().contains(searchTerm.toLowerCase()) ||
              chat.subtitle.toLowerCase().contains(searchTerm.toLowerCase()))
          .toList();
    });
  }

  void _selectTab(String tab) {
    setState(() {
      _selectedTab = tab;
      switch (tab) {
        case 'Unread':
          _filteredChats = _allChats
              .where((chat) =>
                  chat.messages.isNotEmpty &&
                  chat.messages.last.senderId != _currentUserId)
              .toList();
          break;
        case 'Teams':
          _filteredChats =
              _allChats.where((chat) => chat.icon == Icons.group).toList();
          break;
        default:
          _filteredChats = _allChats;
      }
    });
  }

  void _selectChat(ChatUser chat) {
    setState(() {
      _selectedChat = chat;
      _currentMessages = chat.messages;
    });
  }

  void _sendMessage(String text) async {
    // Remove any trailing newlines and whitespace
    final trimmedText = text.trim();

    // Don't send if empty
    if (trimmedText.isEmpty) return;

    // Don't send if no chat is selected
    if (_selectedChat == null) return;

    // Clear the input field first
    _messageController.clear();

    try {
      // First check if chat document exists
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_selectedChat!.id)
          .get();

      // If chat doesn't exist, create it first
      if (!chatDoc.exists) {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(_selectedChat!.id)
            .set({
          'chat_type': 'individual', // or 'group' based on your needs
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
          'participants': [_currentUserId, _selectedChat!.id], // Add both users
        });
      }

      // Create message data
      final messageData = {
        'content': trimmedText,
        'sender_id': _currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'read_by': [_currentUserId],
      };

      // Add message to Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_selectedChat!.id)
          .collection('messages')
          .add(messageData);

      // Update the chat's last_message and timestamp
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_selectedChat!.id)
          .update({
        'last_message': messageData,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Scroll to bottom
      // Future.delayed(const Duration(milliseconds: 100), () {
      //   if (_chatScrollController.hasClients) {
      //     _chatScrollController.animateTo(
      //       _chatScrollController.position.maxScrollExtent,
      //       duration: const Duration(milliseconds: 300),
      //       curve: Curves.easeOut,
      //     );
      //   }
      // }
      // );
    } catch (e) {
      print('Error sending message: $e');
      // You might want to show an error message to the user
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: [
                // Add New Chat Button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff51ABFF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    focusNode: _searchFocus,
                    onChanged: _filterChats,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: const TextStyle(fontSize: 14),
                      prefixIcon: Icon(
                        Icons.search,
                        color: _isSearchFocused
                            ? const Color(0xff4A5BF6)
                            : Colors.grey,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xff4A5BF6)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Navigation Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      _buildNavTab('All', _selectedTab == 'All'),
                      _buildNavTab('Unread', _selectedTab == 'Unread'),
                      _buildNavTab('Teams', _selectedTab == 'Teams'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Chat List
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _filteredChats.length,
                      itemBuilder: (context, index) {
                        final chat = _filteredChats[index];
                        return _buildChatItem(
                          chat.id,
                          chat.name,
                          chat.subtitle,
                          _selectedChat?.id == chat.id,
                          chat.icon,
                          isOnline: chat.isOnline,
                          lastMessageTime: chat.messages.isNotEmpty
                              ? _formatDate(chat.messages.last.timestamp)
                              : null,
                          onTap: () => _selectChat(chat),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main Chat Area

          Expanded(
            child: Column(
              children: [
                // Chat Header
                if (_selectedChat != null) _buildChatHeader(_selectedChat!),

                // Messages Area
                Expanded(
                  child: Container(
                      color: const Color(0xFFF0F4F9),
                      child: _selectedChat == null
                          ? const Center(
                              child: Text('Select a chat to start messaging'))
                          : StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('chats')
                                  .doc(_selectedChat!.id)
                                  .collection('messages')
                                  .orderBy('timestamp', descending: true)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return Center(
                                      child: Text('Error: ${snapshot.error}'));
                                }

                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                final messages = snapshot.data?.docs ?? [];

                                return Align(
                                  // Add this
                                  alignment: Alignment.topCenter, // Add this
                                  child: ListView.builder(
                                    controller: _chatScrollController,
                                    reverse: true,
                                    padding: const EdgeInsets.all(16),
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      final messageData = messages[index].data()
                                          as Map<String, dynamic>;
                                      final isCurrentUser =
                                          messageData['sender_id'] ==
                                              _currentUserId;

                                      DateTime messageTime;
                                      try {
                                        messageTime =
                                            messageData['timestamp'] != null
                                                ? (messageData['timestamp']
                                                        as Timestamp)
                                                    .toDate()
                                                : DateTime.now();
                                      } catch (e) {
                                        messageTime = DateTime.now();
                                      }

                                      return _buildMessageBubble(
                                        ChatMessage(
                                          id: messages[index].id,
                                          senderId:
                                              messageData['sender_id'] ?? '',
                                          text: messageData['content'] ?? '',
                                          timestamp: messageTime,
                                        ),
                                        isCurrentUser,
                                      );
                                    },
                                  ),
                                );
                              },
                            )),
                ),

                // Message Input Area
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: KeyboardListener(
                          focusNode: FocusNode(),
                          onKeyEvent: (KeyEvent event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey == LogicalKeyboardKey.enter &&
                                !HardwareKeyboard.instance.isControlPressed &&
                                !HardwareKeyboard.instance.isShiftPressed) {
                              _sendMessage(_messageController.text);
                            }
                          },
                          child: TextField(
                            controller: _messageController,
                            maxLines: 4,
                            minLines: 1,
                            keyboardType: TextInputType.multiline,
                            decoration: InputDecoration(
                              hintText: 'Write something...',
                              hintStyle: const TextStyle(fontSize: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide:
                                    const BorderSide(color: Color(0xff4A5BF6)),
                              ),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.emoji_emotions_outlined),
                                    onPressed: () {},
                                    splashRadius: 20,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.attach_file),
                                    onPressed: () {},
                                    splashRadius: 20,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.gif_box_outlined),
                                    onPressed: () {},
                                    splashRadius: 20,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.send),
                                    onPressed: () {
                                      if (_messageController.text
                                          .trim()
                                          .isNotEmpty) {
                                        _sendMessage(_messageController.text);
                                      }
                                    },
                                    splashRadius: 20,
                                    color: const Color(0xff4A5BF6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNavTab(String text, bool isSelected) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _selectTab(text),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color:
                      isSelected ? const Color(0xff4A5BF6) : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? const Color(0xff4A5BF6) : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(
    String id,
    String title,
    String subtitle,
    bool isSelected,
    IconData icon, {
    bool isOnline = false,
    String? lastMessageTime,
    required Function() onTap,
  }) {
    bool isHovered = _hoveredChatId == id;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredChatId = id),
      onExit: (_) => setState(() => _hoveredChatId = ''),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xff4A5BF6).withOpacity(0.1)
                : isHovered
                    ? Colors.grey.withOpacity(0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor:
                      isSelected ? const Color(0xff4A5BF6) : Colors.grey,
                  radius: 16,
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lastMessageTime != null)
                  Text(
                    lastMessageTime,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                if (isSelected || isHovered)
                  const Icon(Icons.more_vert, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatHeader(ChatUser chat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xff4A5BF6),
            child: Icon(chat.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chat.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                chat.subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Row(
              children: [
                Icon(Icons.share, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Share',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isCurrentUser) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrentUser ? const Color(0xff4A5BF6) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: isCurrentUser
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey.shade600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return _formatTime(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}
