import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:html' show window;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

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

  @override
  String toString() {
    return 'ChatUser(id: $id, name: $name, subtitle: $subtitle, isOnline: $isOnline)';
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _chatScrollController = ScrollController();

  // Add stream subscriptions for proper disposal
  StreamSubscription<QuerySnapshot>? _chatsSubscription;
  StreamSubscription<QuerySnapshot>? _usersSubscription;

  String _hoveredChatId = '';
  bool _isSearchFocused = false;
  String _selectedTab = 'All';
  final String _currentUserId =
      'ySm53rwQszPGceGjBQaYLOMAEet1'; // Simulating current user
  ChatUser? _selectedChat;
  final List<ChatMessage> _currentMessages = [];

  // Replace the mock _allChats list with a real-time users stream
  List<ChatUser> _allChats = [];

  List<ChatUser> _filteredChats = [];

  bool _showAllUsers = false;

  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onSearchFocusChange);
    _filteredChats = [];
    _loadUsers();
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {
      _isComposing = _messageController.text.isNotEmpty;
    });
  }

  // Add this method to load users from Firestore
  void _loadUsers() {
    print('Starting _loadUsers method...');
    try {
      // Always load users with chat history first
      _chatsSubscription = FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _currentUserId)
          .snapshots()
          .listen((chatSnapshot) {
        if (!mounted) return; // Check if widget is still mounted

        Set<String> chatUserIds = {};

        for (var doc in chatSnapshot.docs) {
          List<String> participants =
              List<String>.from(doc['participants'] ?? []);
          chatUserIds.addAll(participants.where((id) => id != _currentUserId));
        }

        if (chatUserIds.isEmpty) {
          if (mounted) {
            setState(() {
              _allChats = [];
              _filteredChats = [];
            });
          }
          return;
        }

        // Cancel previous users subscription if it exists
        _usersSubscription?.cancel();

        // Fetch user details for chat participants
        _usersSubscription = FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chatUserIds.toList())
            .snapshots()
            .listen((userSnapshot) {
          if (!mounted) return; // Check if widget is still mounted

          setState(() {
            _allChats = userSnapshot.docs.map((doc) {
              final data = doc.data();
              return ChatUser(
                id: doc.id,
                name: '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'
                    .trim(),
                subtitle: data['email']?.toString() ?? '',
                icon: Icons.person,
                isOnline: _isUserOnline(data['last_login']),
              );
            }).toList();

            _filteredChats = List.from(_allChats);

            // If a chat is selected, make sure it stays selected
            if (_selectedChat != null) {
              final updatedSelectedChat = _allChats.firstWhere(
                (chat) => chat.id == _selectedChat!.id,
                orElse: () => _selectedChat!,
              );
              _selectedChat = updatedSelectedChat;
            }
          });
        });
      });
    } catch (e) {
      print('Error setting up snapshot listener: $e');
    }
  }

  // Add this helper method to check online status
  bool _isUserOnline(dynamic lastLogin) {
    if (lastLogin == null) return false;
    try {
      DateTime lastLoginTime;
      if (lastLogin is Timestamp) {
        lastLoginTime = lastLogin.toDate();
      } else if (lastLogin is String) {
        lastLoginTime = DateTime.parse(lastLogin);
      } else {
        return false;
      }
      return DateTime.now().difference(lastLoginTime).inMinutes < 5;
    } catch (e) {
      return false;
    }
  }

  // Extract user snapshot handling to separate method
  void _handleUserSnapshot(QuerySnapshot snapshot) {
    setState(() {
      _allChats = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            // Skip the current user
            if (doc.id == _currentUserId) return null;

            // Handle last_login conversion
            bool isOnline = false;
            if (data['last_login'] != null) {
              try {
                DateTime lastLogin;
                if (data['last_login'] is Timestamp) {
                  lastLogin = (data['last_login'] as Timestamp).toDate();
                } else if (data['last_login'] is String) {
                  lastLogin = DateTime.parse(data['last_login']);
                } else {
                  lastLogin = DateTime.now();
                }
                isOnline = DateTime.now().difference(lastLogin).inMinutes < 5;
              } catch (e) {
                print('Error parsing last_login: $e');
              }
            }

            return ChatUser(
              id: doc.id,
              name: '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'
                  .trim(),
              subtitle: data['email']?.toString() ?? '',
              icon: Icons.person,
              isOnline: isOnline,
            );
          })
          .whereType<ChatUser>()
          .toList();

      _filteredChats = List.from(_allChats);
    });
  }

  // Update _selectChat method to load messages
  void _selectChat(ChatUser chat) {
    setState(() {
      _selectedChat = chat;
      // Messages will be loaded through StreamBuilder
    });
  }

  @override
  void dispose() {
    // Cancel stream subscriptions to prevent setState after dispose
    _chatsSubscription?.cancel();
    _usersSubscription?.cancel();

    _messageController.dispose();
    _searchFocus.removeListener(_onSearchFocusChange);
    _searchFocus.dispose();
    _scrollController.dispose();
    _chatScrollController.dispose();
    _messageController.removeListener(_onTextChanged);
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

  void _sendMessage(String text) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty || _selectedChat == null) return;

    // Send message
    _messageController.clear();

    // Send text message directly
    FirebaseFirestore.instance.collection('chats').add({
      'content': trimmedText,
      'timestamp': FieldValue.serverTimestamp(),
      'sender_id': _currentUserId,
    });
  }

  // Helper method to send message to Firestore
  Future<void> _sendMessageToFirestore(Map<String, dynamic> messageData) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_selectedChat!.id)
          .collection('messages')
          .add(messageData);

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_selectedChat!.id)
          .update({
        'last_message': messageData,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  // Add this method to show the user selection dialog
  void _showUserSelectionDialog() {
    String searchTerm = ''; // Move searchTerm outside StatefulBuilder

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              child: Container(
                width: 400,
                height: 500,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'New chat',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      autofocus: true, // Add this to focus the search field
                      onChanged: (value) {
                        setDialogState(() {
                          searchTerm = value.trim().toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search users...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Contacts label
                    const Text(
                      'Contacts',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .orderBy('first_name')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          // First get all chat participants
                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('chats')
                                .where('participants',
                                    arrayContains: _currentUserId)
                                .snapshots(),
                            builder: (context, chatSnapshot) {
                              if (!chatSnapshot.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              // Get all users that current user has chatted with
                              Set<String> existingChatUserIds = {};
                              for (var doc in chatSnapshot.data!.docs) {
                                List<String> participants = List<String>.from(
                                    doc['participants'] ?? []);
                                existingChatUserIds.addAll(participants
                                    .where((id) => id != _currentUserId));
                              }

                              // Filter users to show only those without existing chats
                              final allUsers = snapshot.data!.docs
                                  .map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;

                                    // Skip current user and users with existing chats
                                    if (doc.id == _currentUserId ||
                                        existingChatUserIds.contains(doc.id)) {
                                      return null;
                                    }

                                    final name =
                                        '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'
                                            .trim();
                                    final email =
                                        data['email']?.toString() ?? '';

                                    // Apply search filter
                                    if (searchTerm.isNotEmpty &&
                                        !name
                                            .toLowerCase()
                                            .contains(searchTerm) &&
                                        !email
                                            .toLowerCase()
                                            .contains(searchTerm)) {
                                      return null;
                                    }

                                    return ChatUser(
                                      id: doc.id,
                                      name: name,
                                      subtitle: email,
                                      icon: Icons.person,
                                    );
                                  })
                                  .whereType<ChatUser>()
                                  .toList();

                              if (allUsers.isEmpty) {
                                return Center(
                                  child: Text(
                                    searchTerm.isEmpty
                                        ? 'No new users to chat with'
                                        : 'No matches found for "$searchTerm"',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                );
                              }

                              return ListView.builder(
                                itemCount: allUsers.length,
                                itemBuilder: (context, index) {
                                  final user = allUsers[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Text(user.name[0].toUpperCase()),
                                    ),
                                    title: Text(user.name),
                                    subtitle: Text(user.subtitle),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _selectChat(user);
                                    },
                                  );
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
            );
          },
        );
      },
    );
  }

  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji,
    );
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.baseOffset + emoji.length,
      ),
    );
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji.emoji,
    );
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.baseOffset + emoji.emoji.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Building FeedScreen');
    print('_filteredChats length: ${_filteredChats.length}');

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
                      onPressed: _showUserSelectionDialog,
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
                        print('Building chat item at index $index');
                        final chat = _filteredChats[index];
                        print('Chat data: ${chat.name}, ${chat.subtitle}');
                        print("debugging chat: ${chat.toString()}");

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
                // Add a back button when showing all users
                if (_showAllUsers)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showAllUsers = false;
                          _loadUsers();
                        });
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to chats'),
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

                                      try {
                                        return messageData['timestamp'] != null
                                            ? _buildMessageBubble(
                                                messageData, isCurrentUser)
                                            : null;
                                      } catch (e) {
                                        return null;
                                      }
                                    },
                                  ),
                                );
                              },
                            )),
                ),

                // Message Input Area
                Column(
                  children: [
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
                            child: TextField(
                              controller: _messageController,
                              focusNode: _messageFocusNode,
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                border: InputBorder.none,
                              ),
                              onSubmitted: (text) => _sendMessage(text),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.send,
                              color: Color(0xff4A5BF6),
                            ),
                            onPressed: _isComposing
                                ? () => _sendMessage(_messageController.text)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (event) {
        if (mounted) {
          setState(() => _hoveredChatId = id);
        }
      },
      onExit: (event) {
        if (mounted) {
          setState(() => _hoveredChatId = '');
        }
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xffEEF2FF)
                : _hoveredChatId == id
                    ? Colors.grey.shade50
                    : Colors.transparent,
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
                  child: Text(
                    title.isNotEmpty ? title[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
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
              overflow: TextOverflow.ellipsis,
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

  Widget _buildMessageBubble(dynamic messageData, bool isCurrentUser) {
    final data = messageData as Map<String, dynamic>;
    final isAttachment = data['type'] == 'attachment';

    DateTime getDateTime(dynamic timestamp) {
      if (timestamp == null) return DateTime.now();
      if (timestamp is Timestamp) return timestamp.toDate();
      return DateTime.now();
    }

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
            if (isAttachment) ...[
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    // For web, we can directly open the URL in a new tab
                    final url = data['file_url'];
                    window.open(url, '_blank');
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getFileIcon(data['file_type']),
                            color: isCurrentUser ? Colors.white : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              data['file_name'],
                              style: TextStyle(
                                color: isCurrentUser
                                    ? Colors.white
                                    : Colors.black87,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (data['file_size'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatFileSize(data['file_size']),
                          style: TextStyle(
                            color: isCurrentUser
                                ? Colors.white.withOpacity(0.7)
                                : Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else ...[
              Text(
                data['content'],
                style: TextStyle(
                  color: isCurrentUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _formatTime(getDateTime(data['timestamp'])),
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

  IconData _getFileIcon(String? fileType) {
    if (fileType == null) return Icons.attachment;

    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      default:
        return Icons.attachment;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
