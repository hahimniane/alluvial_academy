import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'user_selection_dialog.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

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
  bool _showFormFilter = true;
  bool _showStatusFilter = true;
  bool _showCreatorFilter = true;
  bool _showDateFilter = true;
  bool _showUserFilter = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          TextField(
            controller: widget.searchController,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchByNameOrEmail,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          SizedBox(height: 24),

          // Form filter
          _buildFilterSection(
            title: AppLocalizations.of(context)!.form,
            isExpanded: _showFormFilter,
            onToggle: () => setState(() => _showFormFilter = !_showFormFilter),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffE2E8F0)),
              ),
              child: DropdownButton<String>(
                value: widget.selectedFormId.isEmpty
                    ? null
                    : widget.selectedFormId,
                hint: Text(AppLocalizations.of(context)!.allForms),
                isExpanded: true,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(AppLocalizations.of(context)!.allForms),
                  ),
                  ...widget.formTemplates.entries.map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        entry.value['title'] ?? 'Untitled Form',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => widget.onFormSelected(value ?? ''),
              ),
            ),
          ),
          SizedBox(height: 24),

          // Status filter
          _buildFilterSection(
            title: AppLocalizations.of(context)!.userStatus,
            isExpanded: _showStatusFilter,
            onToggle: () =>
                setState(() => _showStatusFilter = !_showStatusFilter),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffE2E8F0)),
              ),
              child: DropdownButton<String>(
                value: widget.selectedStatus,
                isExpanded: true,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: 'All', child: Text(AppLocalizations.of(context)!.allStatus)),
                  DropdownMenuItem(
                      value: 'Completed', child: Text(AppLocalizations.of(context)!.formCompleted)),
                  DropdownMenuItem(value: 'Draft', child: Text(AppLocalizations.of(context)!.timesheetDraft)),
                  DropdownMenuItem(value: 'Pending', child: Text(AppLocalizations.of(context)!.timesheetPending)),
                ],
                onChanged: (value) => widget.onStatusSelected(value ?? 'All'),
              ),
            ),
          ),
          SizedBox(height: 24),

          // Creator filter
          _buildFilterSection(
            title: AppLocalizations.of(context)!.createdBy,
            isExpanded: _showCreatorFilter,
            onToggle: () =>
                setState(() => _showCreatorFilter = !_showCreatorFilter),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffE2E8F0)),
              ),
              child: DropdownButton<String>(
                value: widget.selectedCreator,
                isExpanded: true,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: 'All', child: Text(AppLocalizations.of(context)!.allForms)),
                  DropdownMenuItem(
                      value: 'Admin', child: Text(AppLocalizations.of(context)!.adminCreated)),
                  DropdownMenuItem(value: 'Self', child: Text(AppLocalizations.of(context)!.createdByMe)),
                ],
                onChanged: (value) => widget.onCreatorSelected(value ?? 'All'),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Date range
          _buildFilterSection(
            title: AppLocalizations.of(context)!.dateRange,
            isExpanded: _showDateFilter,
            onToggle: () => setState(() => _showDateFilter = !_showDateFilter),
            child: Material(
              elevation: 0,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: widget.startDate != null && widget.endDate != null
                        ? const Color(0xff0386FF)
                        : const Color(0xffE2E8F0),
                    width: widget.startDate != null && widget.endDate != null
                        ? 2
                        : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: widget.startDate != null && widget.endDate != null
                      ? const Color(0xff0386FF).withOpacity(0.05)
                      : Colors.white,
                ),
                child: InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final currentMonthStart = DateTime(now.year, now.month, 1);
                    final currentMonthEnd =
                        DateTime(now.year, now.month + 1, 0);

                    final result = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(now.year + 5),
                      initialDateRange:
                          widget.startDate != null && widget.endDate != null
                              ? DateTimeRange(
                                  start: widget.startDate!,
                                  end: widget.endDate!)
                              : DateTimeRange(
                                  start: currentMonthStart,
                                  end: currentMonthEnd,
                                ),
                      currentDate: now,
                      helpText: AppLocalizations.of(context)!.selectDateRangeForFormResponses,
                      cancelText: 'Cancel',
                      confirmText: 'Apply Filter',
                      saveText: 'Apply',
                      builder: (context, child) {
                        return Center(
                          child: SingleChildScrollView(
                            child: Container(
                              constraints: const BoxConstraints(
                                maxWidth: 400,
                                maxHeight: 800,
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme:
                                      Theme.of(context).colorScheme.copyWith(
                                            primary: const Color(0xff0386FF),
                                          ),
                                ),
                                child: child!,
                              ),
                            ),
                          ),
                        );
                      },
                    );

                    if (result != null) {
                      widget.onDateRangeSelected(result.start, result.end);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xff0386FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Color(0xff0386FF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.startDate != null && widget.endDate != null
                                ? '${widget.startDate!.toLocal().toString().split(' ')[0]} - ${widget.endDate!.toLocal().toString().split(' ')[0]}'
                                : AppLocalizations.of(context)!.selectDateRange,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xff374151),
                            ),
                          ),
                        ),
                        if (widget.startDate != null && widget.endDate != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () =>
                                widget.onDateRangeSelected(null, null),
                            tooltip: AppLocalizations.of(context)!.clearDateRange,
                            color: Colors.grey,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // User selection
          _buildFilterSection(
            title: AppLocalizations.of(context)!.navUsers,
            isExpanded: _showUserFilter,
            onToggle: () => setState(() => _showUserFilter = !_showUserFilter),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.selectedUserIds.isEmpty
                      ? const Color(0xffE2E8F0)
                      : const Color(0xff0386FF),
                  width: widget.selectedUserIds.isEmpty ? 1 : 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => UserSelectionDialog(
                          selectedUserIds: widget.selectedUserIds,
                          onUsersSelected: widget.onUsersSelected,
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_add),
                    label: Text(AppLocalizations.of(context)!.selectUsers2),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xff0386FF),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                    ),
                  ),
                  if (widget.selectedUserIds.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${widget.selectedUserIds.length} users selected',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff374151),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: const Color(0xff6B7280),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 8),
          child,
        ],
      ],
    );
  }
}
