import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/teaching_shift.dart';
import '../widgets/shift_details_dialog.dart';

class AvailableShiftsScreen extends StatefulWidget {
  const AvailableShiftsScreen({super.key});

  @override
  State<AvailableShiftsScreen> createState() => _AvailableShiftsScreenState();
}

class _AvailableShiftsScreenState extends State<AvailableShiftsScreen> {
  List<TeachingShift> _availableShifts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableShifts();
  }

  Future<void> _loadAvailableShifts() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Query only published shifts, excluding current user's shifts
      final querySnapshot = await FirebaseFirestore.instance
          .collection('teaching_shifts')
          .where('is_published', isEqualTo: true)
          .where('status', isEqualTo: 'scheduled')
          .orderBy('shift_start')
          .limit(50)
          .get();

      final shifts = querySnapshot.docs
          .map((doc) => TeachingShift.fromFirestore(doc))
          .where((shift) => !shift.hasExpired && shift.originalTeacherId != currentUser.uid)
          .toList();

      if (mounted) {
        setState(() {
          _availableShifts = shifts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading available shifts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showShiftDetails(TeachingShift shift) {
    showDialog(
      context: context,
      builder: (context) => ShiftDetailsDialog(
        shift: shift,
        onClaimShift: () => _handleClaimShift(shift),
      ),
    );
  }

  Future<void> _handleClaimShift(TeachingShift shift) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.add_task, color: Color(0xff10B981)),
            const SizedBox(width: 12),
            Text(
              'Claim Shift',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to claim this shift?',
              style: GoogleFonts.inter(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xffF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shift.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Subject: ${shift.effectiveSubjectDisplayName}',
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                  Text(
                    'Date: ${_formatDate(shift.shiftStart)}',
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                  Text(
                    'Time: ${_formatTime(shift.shiftStart)} - ${_formatTime(shift.shiftEnd)}',
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xff6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Claim Shift',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;

        // Get current user's name from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final userName = userDoc.data()?['name'] ?? 'Unknown';

        // Update shift: change teacher, keep original teacher info, set isPublished to false
        await FirebaseFirestore.instance
            .collection('teaching_shifts')
            .doc(shift.id)
            .update({
          'teacher_id': currentUser.uid,
          'teacher_name': userName,
          'is_published': false,
          'last_modified': FieldValue.serverTimestamp(),
          // Keep original_teacher_id and original_teacher_name unchanged
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Shift claimed successfully! Check "My Shifts" to see it.',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: const Color(0xff10B981),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        _loadAvailableShifts(); // Refresh list
      } catch (e) {
        print('Error claiming shift: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ Failed to claim shift. Please try again.',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: const Color(0xffEF4444),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Available Shifts',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: const Color(0xff111827),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xff111827)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailableShifts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _availableShifts.isEmpty
              ? _buildEmptyState()
              : _buildShiftsList(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xff0386FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_busy,
                size: 64,
                color: Color(0xff0386FF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Available Shifts',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'There are currently no published shifts available from other teachers.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xff6B7280),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAvailableShifts,
              icon: const Icon(Icons.refresh),
              label: Text(
                'Refresh',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftsList() {
    return RefreshIndicator(
      onRefresh: _loadAvailableShifts,
      color: const Color(0xff0386FF),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _availableShifts.length,
        itemBuilder: (context, index) {
          final shift = _availableShifts[index];
          return _buildShiftCard(shift);
        },
      ),
    );
  }

  Widget _buildShiftCard(TeachingShift shift) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xff0386FF).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0386FF).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showShiftDetails(shift),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Published badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff0386FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.public,
                          size: 14,
                          color: Color(0xff0386FF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AVAILABLE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xff0386FF),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Original teacher info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 12,
                          color: Color(0xff6B7280),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          shift.originalTeacherName ?? shift.teacherName,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xff6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                shift.displayName,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.book,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    shift.effectiveSubjectDisplayName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(shift.shiftStart),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatTime(shift.shiftStart)} - ${_formatTime(shift.shiftEnd)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.attach_money,
                            size: 18,
                            color: Color(0xff10B981),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '\$${shift.hourlyRate.toStringAsFixed(2)}/hr',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showShiftDetails(shift),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'View Details',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

