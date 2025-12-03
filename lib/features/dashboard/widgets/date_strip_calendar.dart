import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DateStripCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const DateStripCalendar({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Generate dates: 30 days in the past + today + 30 days in the future
    final dates = List.generate(61, (index) {
      return now.subtract(const Duration(days: 30)).add(Duration(days: index));
    });

    // Find the initial scroll index (where "today" is)
    // 30 days past = index 30 is today
    final initialScrollIndex = 30; 
    
    // Controller to center on today/selected date would be ideal, 
    // but for now, simple list view with initialScrollOffset might need calculation 
    // or just letting the user scroll.
    // Better UX: Use a ScrollController and jump to today.

    final currentMonth = DateFormat('MMMM yyyy').format(selectedDate);

    return Container(
      height: 130, // Increased height to accommodate header
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currentMonth,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_month, color: Color(0xFF64748B)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: now.subtract(const Duration(days: 365)),
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      onDateSelected(picked);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: dates.length,
              // Initialize closer to today (rough estimate: 60px width + 12px margin = 72px per item)
              controller: ScrollController(initialScrollOffset: (initialScrollIndex - 2) * 72.0), 
              itemBuilder: (context, index) {
                final date = dates[index];
                final isSelected =
                    date.day == selectedDate.day && date.month == selectedDate.month && date.year == selectedDate.year;
                final isToday = date.day == now.day && date.month == now.month && date.year == now.year;

                return GestureDetector(
                  onTap: () => onDateSelected(date),
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0386FF)
                          : (isToday ? const Color(0xFFEFF6FF) : Colors.transparent),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : (isToday
                                ? const Color(0xFF0386FF).withOpacity(0.3)
                                : Colors.grey.shade200),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(date).toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date.day.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color:
                                isSelected ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

