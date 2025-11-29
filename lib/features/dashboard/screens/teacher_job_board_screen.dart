import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/job_opportunity.dart';
import '../../../core/services/job_board_service.dart';

class TeacherJobBoardScreen extends StatelessWidget {
  const TeacherJobBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Student Opportunities',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
                Text(
                  'Accept new students to fill your schedule',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<JobOpportunity>>(
              stream: JobBoardService().getAllJobs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allJobs = snapshot.data ?? [];
                final openJobs = allJobs.where((j) => j.status == 'open').toList();
                final filledJobs = allJobs.where((j) => j.status == 'accepted').toList();

                if (openJobs.isEmpty && filledJobs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_turned_in, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No opportunities right now',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: openJobs.length + (filledJobs.isNotEmpty ? filledJobs.length + 1 : 0),
                  itemBuilder: (context, index) {
                    // Show filled jobs section header
                    if (index == openJobs.length && filledJobs.isNotEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16, top: 8),
                        child: Text(
                          'Filled Opportunities',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[700],
                          ),
                        ),
                      );
                    }
                    
                    // Show filled jobs
                    if (index > openJobs.length) {
                      final filledIndex = index - openJobs.length - 1;
                      return _JobCard(job: filledJobs[filledIndex], isFilled: true);
                    }
                    
                    // Show open jobs
                    return _JobCard(job: openJobs[index], isFilled: false);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatefulWidget {
  final JobOpportunity job;
  final bool isFilled;

  const _JobCard({required this.job, this.isFilled = false});

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool _isAccepting = false;

  Future<void> _acceptJob() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isAccepting = true);

    try {
      await JobBoardService().acceptJob(widget.job.id, currentUser.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have accepted this student! Check your schedule.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: widget.isFilled 
          ? const BorderSide(color: Colors.red, width: 2)
          : BorderSide.none,
      ),
      elevation: 2,
      color: widget.isFilled ? Colors.red[50] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.isFilled 
                          ? Colors.red[100] 
                          : const Color(0xffEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: widget.isFilled 
                            ? Colors.red[300]! 
                            : const Color(0xffBFDBFE),
                        ),
                      ),
                      child: Text(
                        widget.job.subject,
                        style: GoogleFonts.inter(
                          color: widget.isFilled 
                            ? Colors.red[900] 
                            : const Color(0xff1D4ED8),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (widget.isFilled) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'FILLED',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  DateFormat('MMM d').format(widget.job.createdAt),
                  style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Student Name
            Text(
              widget.job.studentName.isNotEmpty ? widget.job.studentName : 'Student',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 12),
            // Age, Subject, Grade, Timezone
            _buildInfoRow(Icons.person, 'Age: ${widget.job.studentAge.isNotEmpty ? widget.job.studentAge : "N/A"}'),
            _buildInfoRow(Icons.book, 'Subject: ${widget.job.subject}'),
            _buildInfoRow(Icons.school, 'Grade: ${widget.job.gradeLevel}'),
            _buildInfoRow(Icons.public, 'Timezone: ${widget.job.timeZone}'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today, 'Days: ${widget.job.days.join(", ")}'),
            _buildInfoRow(Icons.access_time, 'Times: ${widget.job.timeSlots.join(", ")}'),
            if (widget.isFilled && widget.job.acceptedAt != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.check_circle, 'Accepted on ${DateFormat('MMM d, yyyy').format(widget.job.acceptedAt!)}'),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: widget.isFilled
                  ? OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Already Filled',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.red[700],
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _isAccepting ? null : _acceptJob,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isAccepting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Accept Student',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: const Color(0xff4B5563), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

