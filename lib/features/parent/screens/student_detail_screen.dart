import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/features/parent/widgets/student_overview_tab.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/student_classes_tab.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/student_tasks_tab.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/student_progress_tab.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String? parentId;

  const StudentDetailScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.parentId,
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.studentName,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0386FF),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFF0386FF),
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Classes'),
            Tab(text: 'Tasks'),
            Tab(text: 'Progress'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          StudentOverviewTab(
            studentId: widget.studentId,
            studentName: widget.studentName,
          ),
          StudentClassesTab(
            studentId: widget.studentId,
            studentName: widget.studentName,
          ),
          StudentTasksTab(
            studentId: widget.studentId,
            studentName: widget.studentName,
          ),
          StudentProgressTab(
            studentId: widget.studentId,
            studentName: widget.studentName,
          ),
        ],
      ),
    );
  }
}

