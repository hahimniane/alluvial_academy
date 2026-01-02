import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StudentQuickStatsCard extends StatelessWidget {
  final int totalClasses;
  final double attendanceRate;
  final int completedTasks;
  final int totalTasks;

  const StudentQuickStatsCard({
    super.key,
    required this.totalClasses,
    required this.attendanceRate,
    required this.completedTasks,
    required this.totalTasks,
  });

  @override
  Widget build(BuildContext context) {
    final attendancePercent = (attendanceRate * 100).toStringAsFixed(0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _buildStatItem(
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFF1D4ED8),
            label: 'Total Classes',
            value: totalClasses.toString(),
          ),
          const SizedBox(width: 24),
          _buildStatItem(
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF16A34A),
            label: 'Attendance',
            value: '$attendancePercent%',
          ),
          const SizedBox(width: 24),
          _buildStatItem(
            icon: Icons.assignment_turned_in_rounded,
            iconColor: const Color(0xFFF59E0B),
            label: 'Tasks Done',
            value: '$completedTasks/$totalTasks',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

