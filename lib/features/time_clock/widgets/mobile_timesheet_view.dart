import 'package:flutter/material.dart';
import '../../../core/enums/timesheet_enums.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/timesheet_entry.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Mobile-friendly timesheet view using cards instead of table
class MobileTimesheetView extends StatefulWidget {
  final List<dynamic>? clockInEntries;

  const MobileTimesheetView({
    super.key,
    this.clockInEntries,
  });

  @override
  State<MobileTimesheetView> createState() => _MobileTimesheetViewState();
}

class _MobileTimesheetViewState extends State<MobileTimesheetView> {
  List<TimesheetEntry> _timesheetData = [];
  bool _isLoading = true;
  String _selectedTimeFilter = 'All Time';
  String _selectedStatusFilter = 'All';

  final List<String> _timeFilterOptions = [
    'Today',
    'This Week',
    'This Month',
    'All Time',
  ];

  final List<String> _statusFilterOptions = [
    'All',
    'Draft',
    'Pending',
    'Approved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _loadTimesheetData();
  }

  TimesheetStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return TimesheetStatus.pending;
      case 'approved':
        return TimesheetStatus.approved;
      case 'rejected':
        return TimesheetStatus.rejected;
      default:
        return TimesheetStatus.draft;
    }
  }

  Future<void> _loadTimesheetData() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .where('teacher_id', isEqualTo: user.uid)
          .get();

      List<TimesheetEntry> entries = [];
      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final entry = TimesheetEntry(
            documentId: doc.id,
            date: data['date'] ?? '',
            subject: data['student_name'] ?? '',
            start: data['start_time'] ?? '',
            end: data['end_time'] ?? '',
            totalHours: data['total_hours'] ?? '00:00',
            description: data['description'] ?? '',
            status: _parseStatus(data['status'] ?? 'draft'),
            source: data['source'] as String?,
            clockInLatitude: data['clock_in_latitude'] as double?,
            clockInLongitude: data['clock_in_longitude'] as double?,
            clockInAddress: data['clock_in_address'] as String?,
            clockOutLatitude: data['clock_out_latitude'] as double?,
            clockOutLongitude: data['clock_out_longitude'] as double?,
            clockOutAddress: data['clock_out_address'] as String?,
          );
          entries.add(entry);
        } catch (e) {
          AppLogger.error('Error parsing entry: $e');
        }
      }

      // Sort by date (most recent first)
      entries.sort((a, b) {
        try {
          // Use correct date format: 'MMM dd, yyyy' (e.g., "Dec 15, 2024")
          final dateA = DateFormat('MMM dd, yyyy').parse(a.date);
          final dateB = DateFormat('MMM dd, yyyy').parse(b.date);
          return dateB.compareTo(dateA);
        } catch (e) {
          AppLogger.error(
              'MobileTimesheetView: Error parsing date "${a.date}" or "${b.date}": $e');
          return 0;
        }
      });

      AppLogger.error(
          'MobileTimesheetView: Loaded ${entries.length} total entries');

      // Apply filters
      entries = _applyFilters(entries);

      AppLogger.debug(
          'MobileTimesheetView: After filters (Time: $_selectedTimeFilter, Status: $_selectedStatusFilter): ${entries.length} entries');

      setState(() {
        _timesheetData = entries;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading timesheet: $e');
      setState(() => _isLoading = false);
    }
  }

  List<TimesheetEntry> _applyFilters(List<TimesheetEntry> entries) {
    // First apply status filter
    if (_selectedStatusFilter != 'All') {
      entries = entries.where((entry) {
        switch (_selectedStatusFilter) {
          case 'Draft':
            return entry.status == TimesheetStatus.draft;
          case 'Pending':
            return entry.status == TimesheetStatus.pending;
          case 'Approved':
            return entry.status == TimesheetStatus.approved;
          case 'Rejected':
            return entry.status == TimesheetStatus.rejected;
          default:
            return true;
        }
      }).toList();
    }

    // Then apply time filter
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_selectedTimeFilter) {
      case 'Today':
        final filtered = entries.where((entry) {
          try {
            final date = DateFormat('MMM dd, yyyy').parse(entry.date);
            final entryDate = DateTime(date.year, date.month, date.day);
            final match = entryDate.year == today.year &&
                entryDate.month == today.month &&
                entryDate.day == today.day;
            if (match) {
              AppLogger.error(
                  'MobileTimesheetView: Entry "${entry.date}" matches Today filter');
            }
            return match;
          } catch (e) {
            AppLogger.error(
                'MobileTimesheetView: Error parsing date "${entry.date}": $e');
            return false;
          }
        }).toList();
        return filtered;

      case 'This Week':
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return entries.where((entry) {
          try {
            final date = DateFormat('MMM dd, yyyy').parse(entry.date);
            return date.isAfter(weekStart.subtract(const Duration(days: 1)));
          } catch (e) {
            AppLogger.error(
                'MobileTimesheetView: Error parsing date "${entry.date}": $e');
            return false;
          }
        }).toList();

      case 'This Month':
        return entries.where((entry) {
          try {
            final date = DateFormat('MMM dd, yyyy').parse(entry.date);
            return date.year == today.year && date.month == today.month;
          } catch (e) {
            AppLogger.error(
                'MobileTimesheetView: Error parsing date "${entry.date}": $e');
            return false;
          }
        }).toList();

      case 'All Time':
      default:
        return entries;
    }
  }

  Color _getStatusColor(TimesheetStatus status) {
    switch (status) {
      case TimesheetStatus.approved:
        return const Color(0xff10B981);
      case TimesheetStatus.pending:
        return const Color(0xffF59E0B);
      case TimesheetStatus.rejected:
        return const Color(0xffEF4444);
      case TimesheetStatus.draft:
        return const Color(0xff6B7280);
    }
  }

  String _getStatusText(TimesheetStatus status) {
    switch (status) {
      case TimesheetStatus.draft:
        return 'Draft';
      case TimesheetStatus.pending:
        return 'Pending';
      case TimesheetStatus.approved:
        return 'Approved';
      case TimesheetStatus.rejected:
        return 'Rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with filter
        _buildHeader(),
        const SizedBox(height: 16),

        // Timesheet cards
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _timesheetData.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadTimesheetData,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _timesheetData.length,
                        itemBuilder: (context, index) {
                          return _buildTimesheetCard(_timesheetData[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Status filter
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.timesheetTitle,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff111827),
                ),
              ),
              const Spacer(),
              // Status filter dropdown
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedStatusFilter == 'All'
                      ? const Color(0xffF3F4F6)
                      : _getStatusColor(
                              _parseStatus(_selectedStatusFilter.toLowerCase()))
                          .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedStatusFilter == 'All'
                        ? Colors.transparent
                        : _getStatusColor(_parseStatus(
                                _selectedStatusFilter.toLowerCase()))
                            .withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: DropdownButton<String>(
                  value: _selectedStatusFilter,
                  underline: const SizedBox(),
                  isDense: true,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff374151),
                  ),
                  items: _statusFilterOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (value != 'All')
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                    _parseStatus(value.toLowerCase())),
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(value),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedStatusFilter = newValue;
                      });
                      _loadTimesheetData();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Time filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _timeFilterOptions.map((filter) {
                final isSelected = _selectedTimeFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      filter,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color:
                            isSelected ? Colors.white : const Color(0xff6B7280),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedTimeFilter = filter;
                        });
                        _loadTimesheetData();
                      }
                    },
                    backgroundColor: const Color(0xffF3F4F6),
                    selectedColor: const Color(0xff0386FF),
                    checkmarkColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimesheetCard(TimesheetEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main content - tappable to view details
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              onTap: () => _viewEntry(entry),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date and Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Color(0xff6B7280),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              entry.date,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff111827),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _getStatusColor(entry.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getStatusText(entry.status),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(entry.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Subject/Student
                    Text(
                      entry.subject,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff111827),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Time details
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoRow(
                            Icons.login,
                            'Clock In',
                            entry.start,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoRow(
                            Icons.logout,
                            'Clock Out',
                            entry.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Total hours
                    _buildInfoRow(
                      Icons.access_time,
                      'Total',
                      entry.totalHours,
                    ),

                    // Location if available
                    if (entry.clockInAddress?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.location_on,
                        'Location',
                        entry.clockInAddress ?? '',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Action buttons
          if (entry.status == TimesheetStatus.draft ||
              entry.status == TimesheetStatus.pending) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Submit button (only for drafts)
                  if (entry.status == TimesheetStatus.draft) ...[
                    TextButton.icon(
                      onPressed: () => _submitEntry(entry),
                      icon: const Icon(Icons.send, size: 18),
                      label: Text(
                        AppLocalizations.of(context)!.timesheetSubmit,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xff10B981),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Edit button (only for drafts)
                  if (entry.status == TimesheetStatus.draft)
                    TextButton.icon(
                      onPressed: () => _editEntry(entry),
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text(
                        AppLocalizations.of(context)!.commonEdit,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xff0386FF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),

                  // View button for submitted entries
                  if (entry.status != TimesheetStatus.draft)
                    TextButton.icon(
                      onPressed: () => _viewEntry(entry),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: Text(
                        AppLocalizations.of(context)!.commonView,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xff6B7280),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xff6B7280),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xff6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    String message = 'No timesheet entries found';
    String subtitle = 'Clock in to create your first entry';

    // Customize message based on active filters
    if (_selectedStatusFilter != 'All') {
      message = 'No ${_selectedStatusFilter.toLowerCase()} entries';
      subtitle = 'Try selecting a different status or time period';
    } else if (_selectedTimeFilter != 'All Time') {
      message = 'No entries for $_selectedTimeFilter';
      subtitle = 'Try selecting a different time period';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xffF3F4F6),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              _selectedStatusFilter != 'All'
                  ? Icons.filter_list_rounded
                  : Icons.access_time_rounded,
              size: 40,
              color: const Color(0xff9CA3AF),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xff6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  // Submit timesheet entry for review
  Future<void> _submitEntry(TimesheetEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.send, color: Color(0xff10B981)),
            SizedBox(width: 12),
            Text(
              AppLocalizations.of(context)!.submitTimesheet,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          AppLocalizations.of(context)!.timesheetSubmitConfirm,
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.commonCancel, style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff10B981),
            ),
            child: Text(AppLocalizations.of(context)!.timesheetSubmit, style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Update status to pending
      await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .doc(entry.documentId!)
          .update({
        'status': 'pending',
        'submitted_at': FieldValue.serverTimestamp(),
      });

      // Reload data and wait for it to complete
      await _loadTimesheetData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.timesheetSubmittedForReview,
                    style: GoogleFonts.inter()),
              ],
            ),
            backgroundColor: const Color(0xff10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorSubmittingE, style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Edit timesheet entry (placeholder - would open edit dialog)
  void _editEntry(TimesheetEntry entry) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.editFunctionalityComingSoonUseWeb,
          style: GoogleFonts.inter(),
        ),
        backgroundColor: const Color(0xff0386FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _viewEntry(TimesheetEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEntryDetails(entry),
    );
  }

  Widget _buildEntryDetails(TimesheetEntry entry) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xffE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                AppLocalizations.of(context)!.timesheetDetails2,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(height: 20),

              // Details
              _buildDetailRow('Date', entry.date),
              _buildDetailRow('Subject', entry.subject),
              _buildDetailRow('Start Time', entry.start),
              _buildDetailRow('End Time', entry.end),
              _buildDetailRow('Total Hours', entry.totalHours),

              if (entry.clockInAddress?.isNotEmpty ?? false)
                _buildDetailRow(
                    'Clock-in Location', entry.clockInAddress ?? ''),

              if (entry.clockOutAddress?.isNotEmpty ?? false)
                _buildDetailRow(
                    'Clock-out Location', entry.clockOutAddress ?? ''),

              if (entry.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.description,
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
                    color: const Color(0xffF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Close button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0386FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.commonClose,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xff111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
