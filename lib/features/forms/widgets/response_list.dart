import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class ResponseList extends StatefulWidget {
  final bool isLoading;
  final List<QueryDocumentSnapshot> responses;
  final Map<String, DocumentSnapshot> formTemplates;
  final Function(QueryDocumentSnapshot) onViewResponse;

  const ResponseList({
    super.key,
    required this.isLoading,
    required this.responses,
    required this.formTemplates,
    required this.onViewResponse,
  });

  @override
  State<ResponseList> createState() => _ResponseListState();
}

class _ResponseListState extends State<ResponseList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _hoveredIndex;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> get _filtered {
    if (_searchQuery.isEmpty) return widget.responses;
    final q = _searchQuery.toLowerCase();
    return widget.responses.where((r) {
      final data = r.data() as Map<String, dynamic>;
      final firstName = (data['userFirstName'] ?? '').toString().toLowerCase();
      final lastName = (data['userLastName'] ?? '').toString().toLowerCase();
      final email = (data['userEmail'] ?? '').toString().toLowerCase();
      final formId = (data['formId'] ?? '').toString();
      final templateData = widget.formTemplates[formId]?.data() as Map<String, dynamic>?;
      final title = templateData?['title']?.toString().toLowerCase() ?? '';
      return firstName.contains(q) ||
          lastName.contains(q) ||
          email.contains(q) ||
          title.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final filtered = _filtered;

    return Column(
      children: [
        // ── Compact toolbar: search + count ──────────────────────────────
        Container(
          height: 44,
          decoration: const BoxDecoration(
            color: Color(0xffF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.search, size: 16, color: Color(0xff9CA3AF)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff111827)),
                  decoration: InputDecoration(
                    hintText: l10n.searchByNameOrEmail,
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xff9CA3AF)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(Icons.close, size: 14, color: Color(0xff6B7280)),
                ),
              const SizedBox(width: 12),
              Text(
                '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff6B7280)),
              ),
            ],
          ),
        ),

        // ── Column header ─────────────────────────────────────────────────
        Container(
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0xffF1F5F9),
            border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const SizedBox(width: 28),
              Expanded(
                flex: 3,
                child: Text('Submitter', style: _headerStyle()),
              ),
              Expanded(
                flex: 3,
                child: Text('Form', style: _headerStyle()),
              ),
              SizedBox(
                width: 90,
                child: Text('Status', style: _headerStyle()),
              ),
              SizedBox(
                width: 80,
                child: Text('Date', style: _headerStyle(), textAlign: TextAlign.right),
              ),
              const SizedBox(width: 32),
            ],
          ),
        ),

        // ── List ───────────────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty(l10n)
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _buildRow(context, l10n, filtered[index], index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    AppLocalizations l10n,
    QueryDocumentSnapshot response,
    int index,
  ) {
    final data = response.data() as Map<String, dynamic>;
    final formId = data['formId']?.toString() ?? '';
    final templateData = widget.formTemplates[formId]?.data() as Map<String, dynamic>?;
    final title = templateData?['title']?.toString() ?? l10n.commonUnknownForm;
    final firstName = data['userFirstName']?.toString() ?? '';
    final lastName = data['userLastName']?.toString() ?? '';
    final email = data['userEmail']?.toString() ?? l10n.commonUnknownUser;
    final status = (data['status'] ?? 'unknown').toString();
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();

    final fullName = '$firstName $lastName'.trim();
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
    final isHovered = _hoveredIndex == index;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onViewResponse(response),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 44,
          decoration: BoxDecoration(
            color: isHovered ? const Color(0xffF0F7FF) : Colors.white,
            border: const Border(bottom: BorderSide(color: Color(0xffF1F5F9))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _avatarColor(initial).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _avatarColor(initial),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Name + email
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isEmpty ? email : fullName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (fullName.isNotEmpty)
                        Text(
                          email,
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xff6B7280)),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                    ],
                  ),
                ),
              ),

              // Form title
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff374151)),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),

              // Status chip
              SizedBox(
                width: 90,
                child: _StatusChip(status: status),
              ),

              // Date
              SizedBox(
                width: 80,
                child: Text(
                  submittedAt != null ? _formatDate(submittedAt) : '',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff6B7280)),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Action
              SizedBox(
                width: 32,
                child: AnimatedOpacity(
                  opacity: isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 100),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 12),
                    color: const Color(0xff0386FF),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.viewResponse,
                    onPressed: () => widget.onViewResponse(response),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(
            l10n.noFormResponsesFound,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xff6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.tryAdjustingYourFiltersOrSearch2,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff9CA3AF)),
          ),
        ],
      ),
    );
  }

  TextStyle _headerStyle() => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: const Color(0xff6B7280),
        letterSpacing: 0.5,
      );

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  Color _avatarColor(String initial) {
    const colors = [
      Color(0xff0386FF),
      Color(0xff10B981),
      Color(0xff8B5CF6),
      Color(0xffF59E0B),
      Color(0xffEF4444),
      Color(0xff06B6D4),
    ];
    if (initial.isEmpty) return colors[0];
    return colors[initial.codeUnitAt(0) % colors.length];
  }
}

// ── Compact status chip ───────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    final Color bg;
    final Color fg;
    switch (lower) {
      case 'completed':
        bg = const Color(0xffD1FAE5);
        fg = const Color(0xff065F46);
        break;
      case 'pending':
        bg = const Color(0xffFEF3C7);
        fg = const Color(0xff92400E);
        break;
      case 'draft':
        bg = const Color(0xffF3F4F6);
        fg = const Color(0xff374151);
        break;
      default:
        bg = const Color(0xffF3F4F6);
        fg = const Color(0xff6B7280);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
