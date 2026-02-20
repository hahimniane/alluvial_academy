import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'user_selection_dialog.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Compact horizontal filter bar — replaces the old wide vertical sidebar.
/// Drops into any Column as a single row with 30px-tall chips.
class FilterPanel extends StatefulWidget {
  final TextEditingController searchController;
  final String selectedFormId;
  final String selectedStatus;
  final String selectedCreator;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> selectedUserIds;
  final Map<String, DocumentSnapshot> formTemplates;
  final Function(String) onFormSelected;
  final Function(String) onStatusSelected;
  final Function(String) onCreatorSelected;
  final Function(DateTime?, DateTime?) onDateRangeSelected;
  final Function(List<String>) onUsersSelected;

  const FilterPanel({
    super.key,
    required this.searchController,
    required this.selectedFormId,
    required this.selectedStatus,
    required this.selectedCreator,
    required this.startDate,
    required this.endDate,
    required this.selectedUserIds,
    required this.formTemplates,
    required this.onFormSelected,
    required this.onStatusSelected,
    required this.onCreatorSelected,
    required this.onDateRangeSelected,
    required this.onUsersSelected,
  });

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasDate = widget.startDate != null && widget.endDate != null;
    final hasUsers = widget.selectedUserIds.isNotEmpty;
    final hasForm = widget.selectedFormId.isNotEmpty;

    final templateData = widget.formTemplates[widget.selectedFormId]?.data() as Map<String, dynamic>?;
    final selectedFormTitle = templateData?['title']?.toString() ?? l10n.allForms;

    // Active filter count badge
    int activeFilters = 0;
    if (widget.selectedFormId.isNotEmpty) activeFilters++;
    if (widget.selectedStatus != 'All') activeFilters++;
    if (widget.selectedCreator != 'All') activeFilters++;
    if (hasDate) activeFilters++;
    if (hasUsers) activeFilters++;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xffF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // ── Form dropdown ─────────────────────────────────────────────
            _CompactDropdown<String>(
              icon: Icons.description_outlined,
              label: hasForm ? selectedFormTitle : l10n.allForms,
              isActive: hasForm,
              items: [
                DropdownMenuItem(value: '', child: Text(l10n.allForms)),
                ...widget.formTemplates.entries.map(
                  (e) {
                    final data = e.value.data() as Map<String, dynamic>?;
                    final title = data?['title']?.toString() ?? 'Untitled';
                    return DropdownMenuItem(
                      value: e.key,
                      child: Text(title, overflow: TextOverflow.ellipsis),
                    );
                  },
                ),
              ],
              value: widget.selectedFormId.isEmpty ? null : widget.selectedFormId,
              onChanged: (v) => widget.onFormSelected(v ?? ''),
            ),
            const SizedBox(width: 6),

            // ── Status dropdown ────────────────────────────────────────────
            _CompactDropdown<String>(
              icon: Icons.circle_outlined,
              label: widget.selectedStatus == 'All' ? l10n.allStatus : widget.selectedStatus,
              isActive: widget.selectedStatus != 'All',
              items: [
                DropdownMenuItem(value: 'All', child: Text(l10n.allStatus)),
                DropdownMenuItem(value: 'Completed', child: Text(l10n.formCompleted)),
                DropdownMenuItem(value: 'Draft', child: Text(l10n.timesheetDraft)),
                DropdownMenuItem(value: 'Pending', child: Text(l10n.timesheetPending)),
              ],
              value: widget.selectedStatus,
              onChanged: (v) => widget.onStatusSelected(v ?? 'All'),
            ),
            const SizedBox(width: 6),

            // ── Creator dropdown ───────────────────────────────────────────
            _CompactDropdown<String>(
              icon: Icons.person_outline,
              label: widget.selectedCreator == 'All' ? l10n.createdBy : widget.selectedCreator,
              isActive: widget.selectedCreator != 'All',
              items: [
                DropdownMenuItem(value: 'All', child: Text(l10n.allForms)),
                DropdownMenuItem(value: 'Admin', child: Text(l10n.adminCreated)),
                DropdownMenuItem(value: 'Self', child: Text(l10n.createdByMe)),
              ],
              value: widget.selectedCreator,
              onChanged: (v) => widget.onCreatorSelected(v ?? 'All'),
            ),
            const SizedBox(width: 6),

            // ── Date range button ──────────────────────────────────────────
            _FilterChip(
              icon: Icons.calendar_today_outlined,
              label: hasDate
                  ? '${_fmt(widget.startDate!)} – ${_fmt(widget.endDate!)}'
                  : l10n.dateRange,
              isActive: hasDate,
              onTap: () => _pickDateRange(context),
              onClear: hasDate ? () => widget.onDateRangeSelected(null, null) : null,
            ),
            const SizedBox(width: 6),

            // ── Users button ───────────────────────────────────────────────
            _FilterChip(
              icon: Icons.group_outlined,
              label: hasUsers ? '${widget.selectedUserIds.length} users' : l10n.navUsers,
              isActive: hasUsers,
              onTap: () => showDialog(
                context: context,
                builder: (_) => UserSelectionDialog(
                  selectedUserIds: widget.selectedUserIds,
                  onUsersSelected: widget.onUsersSelected,
                ),
              ),
              onClear: hasUsers ? () => widget.onUsersSelected([]) : null,
            ),

            // ── Active filters indicator / clear all ───────────────────────
            if (activeFilters > 0) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  widget.onFormSelected('');
                  widget.onStatusSelected('All');
                  widget.onCreatorSelected('All');
                  widget.onDateRangeSelected(null, null);
                  widget.onUsersSelected([]);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(0xff0386FF),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$activeFilters',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.adminSubmissionsClearFilters,
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff0386FF)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      initialDateRange: widget.startDate != null && widget.endDate != null
          ? DateTimeRange(start: widget.startDate!, end: widget.endDate!)
          : DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: now,
            ),
      currentDate: now,
      helpText: AppLocalizations.of(context)!.selectDateRangeForFormResponses,
      cancelText: 'Cancel',
      confirmText: 'Apply',
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 700),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: const Color(0xff0386FF),
                  ),
            ),
            child: child!,
          ),
        ),
      ),
    );
    if (result != null) widget.onDateRangeSelected(result.start, result.end);
  }

  String _fmt(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
}

// ── Shared compact chip ────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xff0386FF).withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xff0386FF) : const Color(0xffD1D5DB),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? const Color(0xff0386FF) : const Color(0xff6B7280),
            ),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? const Color(0xff0386FF) : const Color(0xff374151),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive && onClear != null) ...[
              const SizedBox(width: 5),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 12, color: Color(0xff0386FF)),
              ),
            ] else ...[
              const SizedBox(width: 3),
              const Icon(Icons.expand_more, size: 13, color: Color(0xff9CA3AF)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Compact dropdown chip ──────────────────────────────────────────────────────
class _CompactDropdown<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?> onChanged;

  const _CompactDropdown({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xff0386FF).withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? const Color(0xff0386FF) : const Color(0xffD1D5DB),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: const Color(0xff6B7280)),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff374151)),
              ),
            ],
          ),
          icon: const Icon(Icons.expand_more, size: 13, color: Color(0xff9CA3AF)),
          isDense: true,
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff374151)),
          borderRadius: BorderRadius.circular(8),
          elevation: 2,
          selectedItemBuilder: (_) => items.map((item) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 13,
                      color: isActive ? const Color(0xff0386FF) : const Color(0xff6B7280),
                    ),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive ? const Color(0xff0386FF) : const Color(0xff374151),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              }).toList(),
        ),
      ),
    );
  }
}
