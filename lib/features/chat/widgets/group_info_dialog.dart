import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chat_service.dart';
import '../models/chat_user.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class GroupInfoDialog extends StatefulWidget {
  final ChatUser groupChat;

  const GroupInfoDialog({
    super.key,
    required this.groupChat,
  });

  @override
  State<GroupInfoDialog> createState() => _GroupInfoDialogState();
}

class _GroupInfoDialogState extends State<GroupInfoDialog> {
  final ChatService _chatService = ChatService();
  Map<String, String> memberNames = {};
  String? creatorName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemberInfo();
  }

  Future<void> _loadMemberInfo() async {
    if (widget.groupChat.participants != null) {
      AppLogger.debug('GroupInfoDialog: Loading member info for ${widget.groupChat.participants!.length} participants');
      AppLogger.debug('GroupInfoDialog: Participant IDs: ${widget.groupChat.participants!}');
      
      final names = await _chatService.getUserNames(widget.groupChat.participants!);
      
      AppLogger.debug('GroupInfoDialog: Fetched names: $names');
      
      setState(() {
        memberNames = names;
        creatorName = widget.groupChat.createdBy != null 
            ? names[widget.groupChat.createdBy!] 
            : null;
        isLoading = false;
      });
      
      AppLogger.debug('GroupInfoDialog: Creator name: $creatorName');
    } else {
      AppLogger.debug('GroupInfoDialog: No participants found');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xff059669).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xff059669).withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.group,
                    size: 32,
                    color: Color(0xff059669),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.groupChat.name,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff111827),
                        ),
                      ),
                      if (widget.groupChat.email.isNotEmpty)
                        Text(
                          widget.groupChat.email,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xff6B7280),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Creator info
            if (creatorName != null && !isLoading) ...[
              Text(
                AppLocalizations.of(context)!.createdBy,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xffF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xffE2E8F0),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xff0386FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 18,
                        color: Color(0xff0386FF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      creatorName!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff111827),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Members section
            Text(
              'Members (${widget.groupChat.participantCount ?? 0})',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff374151),
              ),
            ),
            const SizedBox(height: 12),

            // Members list
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.groupChat.participants?.length ?? 0,
                  itemBuilder: (context, index) {
                    final participantId = widget.groupChat.participants![index];
                    final participantName =
                        memberNames[participantId] ?? AppLocalizations.of(context)!.commonUnknownUser;
                    final isCreator = participantId == widget.groupChat.createdBy;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCreator 
                            ? const Color(0xff059669).withOpacity(0.1)
                            : const Color(0xffF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCreator
                              ? const Color(0xff059669).withOpacity(0.2)
                              : const Color(0xffE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isCreator
                                  ? const Color(0xff059669).withOpacity(0.2)
                                  : const Color(0xff0386FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isCreator ? Icons.admin_panel_settings : Icons.person,
                              size: 18,
                              color: isCreator
                                  ? const Color(0xff059669)
                                  : const Color(0xff0386FF),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              participantName,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff111827),
                              ),
                            ),
                          ),
                          if (isCreator)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xff059669),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.admin,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
} 
