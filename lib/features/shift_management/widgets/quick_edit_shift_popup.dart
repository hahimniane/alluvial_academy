import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../core/utils/timezone_utils.dart';
import '../../../core/widgets/timezone_selector_field.dart';
import '../../../core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Quick edit popup for modifying shift times and basic info
/// More streamlined than the full CreateShiftDialog
class QuickEditShiftPopup extends StatefulWidget {
  final TeachingShift shift;
  final VoidCallback onSaved;
  final VoidCallback onDeleted;
  final VoidCallback onOpenFullEditor;

  const QuickEditShiftPopup({
    super.key,
    required this.shift,
    required this.onSaved,
    required this.onDeleted,
    required this.onOpenFullEditor,
  });

  @override
  State<QuickEditShiftPopup> createState() => _QuickEditShiftPopupState();
}

class _QuickEditShiftPopupState extends State<QuickEditShiftPopup> {
  late DateTime _shiftDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late TextEditingController _notesController;
  bool _isLoading = false;
  String _selectedTimezone = 'UTC';

  @override
  void initState() {
    super.initState();
    // Default to the shift's scheduling timezone (admin timezone), matching
    // the create/edit shift form behavior.
    final shiftTz = widget.shift.adminTimezone.trim();
    _selectedTimezone =
        shiftTz.isNotEmpty ? shiftTz : widget.shift.teacherTimezone;

    // Convert shift times from UTC to selected timezone for display
    final startLocal = TimezoneUtils.convertToTimezone(
      widget.shift.shiftStart.toUtc(),
      _selectedTimezone,
    );
    final endLocal = TimezoneUtils.convertToTimezone(
      widget.shift.shiftEnd.toUtc(),
      _selectedTimezone,
    );

    _shiftDate = DateTime(
      startLocal.year,
      startLocal.month,
      startLocal.day,
    );
    _startTime = TimeOfDay.fromDateTime(startLocal);
    _endTime = TimeOfDay.fromDateTime(endLocal);
    _notesController = TextEditingController(text: widget.shift.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xff0386FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_calendar,
                    color: Color(0xff0386FF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.quickEdit,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff111827),
                        ),
                      ),
                      Text(
                        widget.shift.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xff6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  splashRadius: 16,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Teacher info (read-only)
            _buildInfoRow(
              AppLocalizations.of(context)!.roleTeacher,
              widget.shift.teacherName ?? AppLocalizations.of(context)!.commonUnknown,
              Icons.person,
            ),
            const SizedBox(height: 12),

            // Subject/Category info (read-only)
            _buildInfoRow(
              widget.shift.category == ShiftCategory.teaching
                  ? AppLocalizations.of(context)!.shiftSubject
                  : AppLocalizations.of(context)!.userRole,
              widget.shift.subjectDisplayName ??
                  widget.shift.leaderRole ??
                  'N/A',
              widget.shift.category == ShiftCategory.teaching
                  ? Icons.school
                  : Icons.admin_panel_settings,
            ),
            const SizedBox(height: 16),

            // Date selector
            _buildDateSelector(),
            const SizedBox(height: 12),

            // Timezone selector
            _buildTimezoneSelector(),
            const SizedBox(height: 12),

            // Time selectors
            Row(
              children: [
                Expanded(
                    child: _buildTimeSelector(AppLocalizations.of(context)!.shiftStartTime, _startTime, (time) {
                  setState(() => _startTime = time);
                })),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildTimeSelector(AppLocalizations.of(context)!.shiftEndTime, _endTime, (time) {
                  setState(() => _endTime = time);
                })),
              ],
            ),
            const SizedBox(height: 12),

            // Notes
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.shiftNotes,
                labelStyle: GoogleFonts.inter(fontSize: 13),
                hintText: AppLocalizations.of(context)!.shiftAddNotes,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              style: GoogleFonts.inter(fontSize: 13),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                // Delete button
                OutlinedButton.icon(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.red),
                  label: Text(AppLocalizations.of(context)!.commonDelete,
                      style:
                          GoogleFonts.inter(fontSize: 12, color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const Spacer(),
                // More options
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onOpenFullEditor();
                  },
                  child: Text(
                    AppLocalizations.of(context)!.moreOptions,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: const Color(0xff6B7280)),
                  ),
                ),
                const SizedBox(width: 8),
                // Save button
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0386FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(AppLocalizations.of(context)!.commonSave,
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xff9CA3AF)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xff6B7280),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xff374151),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _shiftDate,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) {
          setState(() => _shiftDate = date);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffD1D5DB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 16, color: Color(0xff6B7280)),
            const SizedBox(width: 8),
            Text(
              DateFormat('EEE, MMM d, yyyy').format(_shiftDate),
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xff374151)),
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: Color(0xff6B7280)),
          ],
        ),
      ),
    );
  }

  void _handleTimezoneChange(String newValue) {
    if (newValue == _selectedTimezone) return;

    setState(() {
      // Get current times in old timezone as naive DateTime
      final currentStart = DateTime(
        _shiftDate.year,
        _shiftDate.month,
        _shiftDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final currentEnd = DateTime(
        _shiftDate.year,
        _shiftDate.month,
        _shiftDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      // Convert to UTC using old timezone, then to new timezone
      final utcStart =
          TimezoneUtils.convertToUtc(currentStart, _selectedTimezone);
      final utcEnd = TimezoneUtils.convertToUtc(currentEnd, _selectedTimezone);
      final newStartLocal = TimezoneUtils.convertToTimezone(utcStart, newValue);
      final newEndLocal = TimezoneUtils.convertToTimezone(utcEnd, newValue);

      _selectedTimezone = newValue;
      _shiftDate = DateTime(
        newStartLocal.year,
        newStartLocal.month,
        newStartLocal.day,
      );
      _startTime = TimeOfDay.fromDateTime(newStartLocal);
      _endTime = TimeOfDay.fromDateTime(newEndLocal);
    });
  }

  Widget _buildTimezoneSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppLocalizations.of(context)!.profileTimezone,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xff374151),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: AppLocalizations.of(context)!.theTimezoneForTheTimesBelow,
              child: Icon(
                Icons.info_outline,
                size: 14,
                color: const Color(0xff9CA3AF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TimezoneSelectorField(
          selectedTimezone: _selectedTimezone,
          borderRadius: BorderRadius.circular(8),
          borderColor: const Color(0xffD1D5DB),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xff111827),
          ),
          onTimezoneSelected: _handleTimezoneChange,
        ),
      ],
    );
  }

  Widget _buildTimeSelector(
      String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return InkWell(
      onTap: () async {
        final selected = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffD1D5DB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$label: ',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xff6B7280)),
                ),
                Expanded(
                  child: Text(
                    time.format(context),
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff374151)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              TimezoneUtils.getTimezoneAbbreviation(_selectedTimezone),
              style: GoogleFonts.inter(
                fontSize: 10,
                color: const Color(0xff9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteShift2,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text(
          AppLocalizations.of(context)!.thisWillPermanentlyDeleteThisShift,
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteShift();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.commonDelete, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteShift() async {
    setState(() => _isLoading = true);
    try {
      await ShiftService.deleteShift(widget.shift.id);
      if (mounted) {
        Navigator.pop(context);
        widget.onDeleted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.shiftDeleted), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      AppLogger.error('Error deleting shift: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorE), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      // Create naive DateTime in selected timezone
      final naiveStart = DateTime(
        _shiftDate.year,
        _shiftDate.month,
        _shiftDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      // Handle end time - if it's before start time, assume next day
      DateTime naiveEnd = DateTime(
        _shiftDate.year,
        _shiftDate.month,
        _shiftDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      if (naiveEnd.isBefore(naiveStart)) {
        naiveEnd = naiveEnd.add(const Duration(days: 1));
      }

      // Convert to UTC using selected timezone
      final utcStart =
          TimezoneUtils.convertToUtc(naiveStart, _selectedTimezone);
      final utcEnd = TimezoneUtils.convertToUtc(naiveEnd, _selectedTimezone);

      final updatedShift = widget.shift.copyWith(
        shiftStart: utcStart,
        shiftEnd: utcEnd,
        adminTimezone:
            _selectedTimezone, // Update scheduling timezone if changed
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      // Use the standard update path so lifecycle tasks are rescheduled for the
      // new times (best-effort; will not block the edit if scheduling fails).
      await ShiftService.updateShift(updatedShift);

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.shiftUpdated), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      AppLogger.error('Error updating shift: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorE), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
