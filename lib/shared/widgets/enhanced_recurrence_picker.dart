import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/models/enhanced_recurrence.dart';

class EnhancedRecurrencePicker extends StatefulWidget {
  final EnhancedRecurrence initialRecurrence;
  final Function(EnhancedRecurrence) onRecurrenceChanged;
  final bool showEndDate;

  const EnhancedRecurrencePicker({
    super.key,
    required this.initialRecurrence,
    required this.onRecurrenceChanged,
    this.showEndDate = true,
  });

  @override
  State<EnhancedRecurrencePicker> createState() => _EnhancedRecurrencePickerState();
}

class _EnhancedRecurrencePickerState extends State<EnhancedRecurrencePicker> {
  late EnhancedRecurrence _recurrence;

  @override
  void initState() {
    super.initState();
    _recurrence = widget.initialRecurrence;
  }

  void _updateRecurrence(EnhancedRecurrence newRecurrence) {
    setState(() {
      _recurrence = newRecurrence;
    });
    widget.onRecurrenceChanged(newRecurrence);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRecurrenceTypeSelector(),
        if (_recurrence.type != EnhancedRecurrenceType.none) ...[
          const SizedBox(height: 16),
          _buildRecurrenceSettings(),
          if (widget.showEndDate) ...[
            const SizedBox(height: 16),
            _buildEndDatePicker(),
          ],
        ],
      ],
    );
  }

  Widget _buildRecurrenceTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.grey[50],
      ),
      child: DropdownButtonFormField<EnhancedRecurrenceType>(
        initialValue: _recurrence.type,
        decoration: const InputDecoration(
          labelText: 'Recurrence Type',
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
          prefixIcon: Icon(Icons.repeat, color: Color(0xff0386FF)),
        ),
        items: EnhancedRecurrenceType.values.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(
              _getRecurrenceTypeLabel(type),
              style: GoogleFonts.inter(),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            _updateRecurrence(_recurrence.copyWith(type: value));
          }
        },
      ),
    );
  }

  Widget _buildRecurrenceSettings() {
    switch (_recurrence.type) {
      case EnhancedRecurrenceType.daily:
        return _buildDailySettings();
      case EnhancedRecurrenceType.weekly:
        return _buildWeeklySettings();
      case EnhancedRecurrenceType.monthly:
        return _buildMonthlySettings();
      case EnhancedRecurrenceType.yearly:
        return _buildYearlySettings();
      case EnhancedRecurrenceType.none:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDailySettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Recurrence Settings',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xff374151),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Exclude Days of Week',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xff6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: WeekDay.values.map((day) {
              final isExcluded = _recurrence.excludedWeekdays.contains(day);
              return FilterChip(
                label: Text(day.shortName),
                selected: isExcluded,
                onSelected: (selected) {
                  final newExcludedDays = List<WeekDay>.from(_recurrence.excludedWeekdays);
                  if (selected) {
                    newExcludedDays.add(day);
                  } else {
                    newExcludedDays.remove(day);
                  }
                  _updateRecurrence(_recurrence.copyWith(excludedWeekdays: newExcludedDays));
                },
                selectedColor: Colors.red[200],
                checkmarkColor: Colors.red[700],
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Exclude Specific Dates',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff6B7280),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addExcludedDate,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Date'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xff0386FF),
                ),
              ),
            ],
          ),
          if (_recurrence.excludedDates.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recurrence.excludedDates.map((date) {
                return Chip(
                  label: Text(DateFormat('MMM dd, yyyy').format(date)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    final newExcludedDates = List<DateTime>.from(_recurrence.excludedDates);
                    newExcludedDates.remove(date);
                    _updateRecurrence(_recurrence.copyWith(excludedDates: newExcludedDates));
                  },
                  backgroundColor: Colors.red[100],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklySettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.green[50],
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Recurrence Settings',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xff374151),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select Days of Week',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xff6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: WeekDay.values.map((day) {
              final isSelected = _recurrence.selectedWeekdays.contains(day);
              return FilterChip(
                label: Text(day.shortName),
                selected: isSelected,
                onSelected: (selected) {
                  final newSelectedDays = List<WeekDay>.from(_recurrence.selectedWeekdays);
                  if (selected) {
                    newSelectedDays.add(day);
                  } else {
                    newSelectedDays.remove(day);
                  }
                  _updateRecurrence(_recurrence.copyWith(selectedWeekdays: newSelectedDays));
                },
                selectedColor: Colors.green[200],
                checkmarkColor: Colors.green[700],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.purple[50],
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Recurrence Settings',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xff374151),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select Days of Month',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xff6B7280),
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: 31,
            itemBuilder: (context, index) {
              final day = index + 1;
              final isSelected = _recurrence.selectedMonthDays.contains(day);
              return GestureDetector(
                onTap: () {
                  final newSelectedDays = List<int>.from(_recurrence.selectedMonthDays);
                  if (isSelected) {
                    newSelectedDays.remove(day);
                  } else {
                    newSelectedDays.add(day);
                  }
                  newSelectedDays.sort();
                  _updateRecurrence(_recurrence.copyWith(selectedMonthDays: newSelectedDays));
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected ? Colors.purple[200] : Colors.grey[100],
                    border: Border.all(
                      color: isSelected ? Colors.purple[400]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: GoogleFonts.inter(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.purple[700] : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildYearlySettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yearly Recurrence Settings',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xff374151),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select Months',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xff6B7280),
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.5,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final isSelected = _recurrence.selectedMonths.contains(month);
              final monthName = DateFormat('MMMM').format(DateTime(2024, month));
              
              return GestureDetector(
                onTap: () {
                  final newSelectedMonths = List<int>.from(_recurrence.selectedMonths);
                  if (isSelected) {
                    newSelectedMonths.remove(month);
                  } else {
                    newSelectedMonths.add(month);
                  }
                  newSelectedMonths.sort();
                  _updateRecurrence(_recurrence.copyWith(selectedMonths: newSelectedMonths));
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected ? Colors.orange[200] : Colors.grey[100],
                    border: Border.all(
                      color: isSelected ? Colors.orange[400]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      monthName,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.orange[700] : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEndDatePicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'End Date (Optional)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff374151),
                ),
              ),
              const Spacer(),
              if (_recurrence.endDate != null)
                TextButton(
                  onPressed: () {
                    _updateRecurrence(_recurrence.copyWith(endDate: null));
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _selectEndDate,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20, color: Color(0xff0386FF)),
                  const SizedBox(width: 12),
                  Text(
                    _recurrence.endDate != null
                        ? DateFormat('MMM dd, yyyy').format(_recurrence.endDate!)
                        : 'Select end date',
                    style: GoogleFonts.inter(
                      color: _recurrence.endDate != null 
                          ? const Color(0xff374151) 
                          : const Color(0xff9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRecurrenceTypeLabel(EnhancedRecurrenceType type) {
    switch (type) {
      case EnhancedRecurrenceType.none:
        return 'No Recurrence';
      case EnhancedRecurrenceType.daily:
        return 'Daily';
      case EnhancedRecurrenceType.weekly:
        return 'Weekly';
      case EnhancedRecurrenceType.monthly:
        return 'Monthly';
      case EnhancedRecurrenceType.yearly:
        return 'Yearly';
    }
  }

  Future<void> _addExcludedDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (date != null) {
      final newExcludedDates = List<DateTime>.from(_recurrence.excludedDates);
      if (!newExcludedDates.any((d) => 
          d.year == date.year && d.month == date.month && d.day == date.day)) {
        newExcludedDates.add(date);
        newExcludedDates.sort();
        _updateRecurrence(_recurrence.copyWith(excludedDates: newExcludedDates));
      }
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recurrence.endDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );

    if (date != null) {
      _updateRecurrence(_recurrence.copyWith(endDate: date));
    }
  }
} 