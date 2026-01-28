import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chat_service.dart';
import '../services/chat_permission_service.dart';
import '../models/chat_user.dart';
import '../widgets/chat_user_list_item.dart';
import '../widgets/group_info_dialog.dart';
import '../screens/chat_screen.dart';
import '../screens/group_creation_screen.dart';
import '../../../core/services/user_role_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../l10n/app_localizations.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final ChatService _chatService = ChatService();
  final ChatPermissionService _permissionService = ChatPermissionService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isAdmin = false;
  Map<String, List<ChatUser>> _groupedContacts = {};
  bool _loadingContacts = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAdminStatus();
    _loadEligibleContacts();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await UserRoleService.isAdmin();
    setState(() {
      _isAdmin = isAdmin;
    });
  }

  Future<void> _loadEligibleContacts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _loadingContacts = false);
      return;
    }
    
    try {
      final contacts = await _permissionService.getEligibleContactsGrouped(userId);
      if (mounted) {
        setState(() {
          _groupedContacts = contacts;
          _loadingContacts = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading eligible contacts: $e');
      if (mounted) {
        setState(() => _loadingContacts = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Compact tab bar at top
            _buildCompactTabBar(),

            // Search bar
            _buildCompactSearchBar(),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRecentChats(),
                  _buildMyContacts(),
                ],
              ),
            ),
          ],
        ),
      ),

      // Floating action button for group creation
      floatingActionButton: _isAdmin ? _buildModernCreateGroupFAB() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildCompactTabBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade100,
            width: 1,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xffF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: const Color(0xff0386FF),
          unselectedLabelColor: const Color(0xff64748B),
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(
              height: 36,
              text: AppLocalizations.of(context)?.chatRecentChats ?? 'Recent',
            ),
            Tab(
              height: 36,
              text: AppLocalizations.of(context)?.chatMyContacts ?? 'Contacts',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSearchBar() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: const Color(0xff111827),
        ),
        decoration: InputDecoration(
          hintText: l10n?.chatSearchConversations ?? 'Search conversations...',
          hintStyle: GoogleFonts.inter(
            fontSize: 15,
            color: const Color(0xff9CA3AF),
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xff9CA3AF),
            size: 22,
          ),
          filled: true,
          fillColor: const Color(0xffF3F4F6),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xff0386FF), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentChats() {
    return StreamBuilder<List<ChatUser>>(
      stream: _chatService.getUserChats(),
      builder: (context, snapshot) {
        // Check auth state before processing
        if (FirebaseAuth.instance.currentUser == null) {
          return _buildEmptyState(
            'Please sign in',
            'Authentication required to view chats',
            Icons.login,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          // Handle permission errors gracefully
          if (snapshot.error.toString().contains('permission-denied')) {
            return _buildEmptyState(
              'Access denied',
              'Please sign in to view chats',
              Icons.lock,
            );
          }
          return _buildErrorState('Error loading chats');
        }

        final chats = snapshot.data ?? [];
        final filteredChats = _searchQuery.isEmpty
            ? chats
            : chats
                .where((chat) =>
                    chat.displayName.toLowerCase().contains(_searchQuery) ||
                    chat.email.toLowerCase().contains(_searchQuery))
                .toList();

        if (filteredChats.isEmpty) {
          final l10n = AppLocalizations.of(context);
          return _buildEmptyState(
            _searchQuery.isEmpty 
                ? (l10n?.chatNoConversations ?? 'No conversations yet') 
                : (l10n?.chatNoChatsFound ?? 'No chats found'),
            _searchQuery.isEmpty
                ? (l10n?.chatStartConversation ?? 'Start a conversation by browsing all users')
                : (l10n?.chatTryDifferentSearch ?? 'Try a different search term'),
            Icons.chat_bubble_outline,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          itemCount: filteredChats.length,
          itemBuilder: (context, index) {
            final chat = filteredChats[index];
            return ChatUserListItem(
              user: chat,
              onTap: () => _openChat(chat),
              onLongPress: chat.isGroup ? () => _showGroupInfo(chat) : null,
              showLastMessage: true,
            );
          },
        );
      },
    );
  }

  Widget _buildMyContacts() {
    // Check auth state before processing
    if (FirebaseAuth.instance.currentUser == null) {
      return _buildEmptyState(
        'Please sign in',
        'Authentication required to view contacts',
        Icons.login,
      );
    }

    if (_loadingContacts) {
      return _buildLoadingState();
    }

    if (_groupedContacts.isEmpty) {
      return _buildEmptyState(
        'No contacts available',
        'Your teachers, students, or administrators will appear here based on your classes',
        Icons.people_outline,
      );
    }

    // Filter contacts based on search query
    final filteredGroups = <String, List<ChatUser>>{};
    for (final entry in _groupedContacts.entries) {
      final filteredUsers = _searchQuery.isEmpty
          ? entry.value
          : entry.value
              .where((user) =>
                  user.displayName.toLowerCase().contains(_searchQuery) ||
                  user.email.toLowerCase().contains(_searchQuery))
              .toList();
      if (filteredUsers.isNotEmpty) {
        filteredGroups[entry.key] = filteredUsers;
      }
    }

    if (filteredGroups.isEmpty) {
      return _buildEmptyState(
        'No contacts match your search',
        'Try a different search term',
        Icons.search_off,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEligibleContacts,
      color: const Color(0xff0386FF),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        itemCount: filteredGroups.length,
        itemBuilder: (context, groupIndex) {
          final groupName = filteredGroups.keys.elementAt(groupIndex);
          final users = filteredGroups[groupName]!;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                child: Row(
                  children: [
                    _getGroupIcon(groupName),
                    const SizedBox(width: 8),
                    Text(
                      groupName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xffF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${users.length}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Users in this group
              ...users.map((user) => ChatUserListItem(
                user: user,
                onTap: () => _openChat(user),
                showLastMessage: false,
              )),
            ],
          );
        },
      ),
    );
  }

  Widget _getGroupIcon(String groupName) {
    IconData icon;
    Color color;
    
    switch (groupName) {
      case 'Administrators':
        icon = Icons.admin_panel_settings;
        color = const Color(0xffEF4444);
        break;
      case 'Teachers':
        icon = Icons.school;
        color = const Color(0xff0386FF);
        break;
      case 'Students':
        icon = Icons.person;
        color = const Color(0xff10B981);
        break;
      case 'Parents':
        icon = Icons.family_restroom;
        color = const Color(0xffF59E0B);
        break;
      default:
        icon = Icons.people;
        color = const Color(0xff6B7280);
    }
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xff0386FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.loadingMessages,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xff64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xff0386FF).withOpacity(0.1),
                    const Color(0xff0386FF).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(
                  color: const Color(0xff0386FF).withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                size: 48,
                color: const Color(0xff0386FF),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xff6B7280),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              AppLocalizations.of(context)!.somethingWentWrong,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xff6B7280),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCreateGroupFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0386FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xff0386FF).withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        heroTag: "createGroupFAB",
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const GroupCreationScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xff0386FF),
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: const Icon(Icons.group_add, size: 22),
        label: Text(
          AppLocalizations.of(context)?.chatCreateGroup ?? 'Create Group',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  void _openChat(ChatUser user) async {
    // For individual chats, ensure the conversation is created so it appears in Recent Chats
    if (!user.isGroup) {
      try {
        await _chatService.getOrCreateIndividualChat(user.id);
      } catch (e) {
        AppLogger.error('Error creating chat: $e');
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(chatUser: user),
      ),
    );
  }

  void _showGroupInfo(ChatUser groupChat) {
    showDialog(
      context: context,
      builder: (context) => GroupInfoDialog(groupChat: groupChat),
    );
  }
}
