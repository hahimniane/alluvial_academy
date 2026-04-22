import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../view_models/timesheet_review_view_model.dart';

/// Compact 3-row admin timesheet inbox toolbar (title + export + filters menu;
/// status strip with counts; search + dates + select pending).
class TimesheetReviewToolbar extends StatelessWidget {
  const TimesheetReviewToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.statusOptions,
    required this.onStatusChanged,
    required this.onExport,
    required this.onSelectAllPendingVisible,
    required this.onPresetThisWeek,
    required this.onPresetLastWeek,
    required this.onPresetThisMonth,
    required this.onClearDateRange,
    required this.onPickDateRange,
    required this.hasDateRange,
    required this.dateRangeSummary,
    required this.onTeacherChanged,
    required this.onEditedOnlyChanged,
    required this.onNeedsAttentionChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<String> statusOptions;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onExport;
  final VoidCallback onSelectAllPendingVisible;
  final VoidCallback onPresetThisWeek;
  final VoidCallback onPresetLastWeek;
  final VoidCallback onPresetThisMonth;
  final VoidCallback onClearDateRange;
  final VoidCallback onPickDateRange;
  final bool hasDateRange;
  final String dateRangeSummary;
  final ValueChanged<String?> onTeacherChanged;
  final ValueChanged<bool> onEditedOnlyChanged;
  final ValueChanged<bool> onNeedsAttentionChanged;

  String _statusSegmentLabel(
    AppLocalizations l10n,
    String key,
    int count,
  ) {
    switch (key) {
      case 'All':
        return '${l10n.commonAll} ($count)';
      case 'Pending':
        return '${l10n.timesheetPending} ($count)';
      case 'Approved':
        return '${l10n.timesheetApproved} ($count)';
      case 'Rejected':
        return '${l10n.timesheetRejected} ($count)';
      case 'Draft':
        return '${l10n.timesheetDraft} ($count)';
      default:
        return '$key ($count)';
    }
  }

  Future<void> _openFiltersSheet(
    BuildContext context,
    TimesheetReviewViewModel vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.filters,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use — controlled selection from view model
                  value: vm.filterState.teacherFilter,
                  isDense: true,
                  decoration: InputDecoration(
                    labelText: l10n.filterByTeacher,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  hint: Text(l10n.allTeachers, style: GoogleFonts.inter(fontSize: 12)),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(l10n.allTeachers,
                          style: GoogleFonts.inter(fontSize: 12)),
                    ),
                    ...vm.availableTeachers.map(
                      (t) => DropdownMenuItem<String>(
                        value: t,
                        child: Text(
                          t,
                          style: GoogleFonts.inter(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: onTeacherChanged,
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.timesheetReviewEditedOnly,
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                  value: vm.filterState.editedOnly,
                  onChanged: onEditedOnlyChanged,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.timesheetReviewNeedsAttention,
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                  value: vm.filterState.needsAttention,
                  onChanged: onNeedsAttentionChanged,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.commonClose),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<TimesheetReviewViewModel>();
    final counts = vm.statusCounts();
    final statusFilter = vm.filterState.statusFilter;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.timesheetReview,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openFiltersSheet(context, vm),
                icon: const Icon(Icons.tune, size: 20),
                label: Text(l10n.filters, style: GoogleFonts.inter(fontSize: 13)),
              ),
              IconButton.filledTonal(
                tooltip: l10n.commonExport,
                onPressed: onExport,
                icon: const Icon(Icons.file_download_outlined, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in statusOptions)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(
                        _statusSegmentLabel(l10n, s, counts[s] ?? 0),
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                      selected: statusFilter == s,
                      onSelected: (_) => onStatusChanged(s),
                      visualDensity: VisualDensity.compact,
                      selectedColor: const Color(0xff0386FF),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: statusFilter == s
                            ? Colors.white
                            : const Color(0xff0386FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.timesheetReviewShowingCount(vm.filteredTimesheets.length),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.timesheetReviewSearchHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onSelectAllPendingVisible,
                icon: const Icon(Icons.select_all, size: 18),
                label: Text(
                  l10n.timesheetReviewSelectAllPendingVisible,
                  style: GoogleFonts.inter(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  label: Text(l10n.timesheetThisWeek),
                  onPressed: onPresetThisWeek,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: Text(l10n.timesheetReviewLastWeek),
                  onPressed: onPresetLastWeek,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: Text(l10n.timesheetThisMonth),
                  onPressed: onPresetThisMonth,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: onPickDateRange,
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(
                    hasDateRange ? dateRangeSummary : l10n.dateRange,
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                  ),
                ),
                if (hasDateRange) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: l10n.clearFilter,
                    onPressed: onClearDateRange,
                    icon: const Icon(Icons.clear, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
