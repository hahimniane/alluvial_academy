import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/services/shift_timesheet_service.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../core/services/user_role_service.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/profile_picture_service.dart';
import '../../time_clock/screens/time_clock_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// --- WIDGETS INTERNES ---

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
    // Génère les 14 prochains jours
    final dates = List.generate(14, (index) => now.add(Duration(days: index)));

    return Container(
      height: 85,
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected =
              date.day == selectedDate.day && date.month == selectedDate.month;
          final isToday = date.day == now.day && date.month == now.month;

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
    );
  }
}

class TimelineShiftCard extends StatelessWidget {
  final TeachingShift shift;
  final bool isLast;
  final VoidCallback onTap;

  const TimelineShiftCard({
    super.key,
    required this.shift,
    this.isLast = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final startTime = DateFormat('HH:mm').format(shift.shiftStart);
    final endTime = DateFormat('HH:mm').format(shift.shiftEnd);
    final duration = shift.shiftEnd.difference(shift.shiftStart).inMinutes;

    // Status color logic (simplified)
    Color statusColor = const Color(0xFF0386FF); // Default Blue
    if (shift.isClockedIn) statusColor = const Color(0xFF10B981); // Green
    if (shift.status == ShiftStatus.completed)
      statusColor = const Color(0xFF8B5CF6); // Purple

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time Column
          SizedBox(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  startTime,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B)),
                ),
                Text(
                  endTime,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),

          // The Timeline Line
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: statusColor, width: 3),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),

          // The Card
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF64748B).withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                  border:
                      Border(left: BorderSide(color: statusColor, width: 4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            shift.displayName,
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (shift.isClockedIn)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(AppLocalizations.of(context)!.active,
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF166534))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.people_outline,
                            size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text("${shift.studentNames.length} Students",
                            style: GoogleFonts.inter(
                                fontSize: 13, color: const Color(0xFF64748B))),
                        const SizedBox(width: 16),
                        const Icon(Icons.timer_outlined,
                            size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text("${(duration / 60).toStringAsFixed(1)} hrs",
                            style: GoogleFonts.inter(
                                fontSize: 13, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- MAIN SCREEN ---

class TeacherMobileHome extends StatefulWidget {
  final Function(int) onNavigate;
  const TeacherMobileHome({super.key, required this.onNavigate});

  @override
  State<TeacherMobileHome> createState() => _TeacherMobileHomeState();
}

class _TeacherMobileHomeState extends State<TeacherMobileHome> {
  String _userName = 'Teacher';
  String? _profilePicUrl;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  // Shift State
  TeachingShift? _activeShift;
  List<TeachingShift> _todayShifts = [];
  
  // Timer for active shift
  Timer? _timer;
  String _timerText = "00:00:00";
  DateTime? _clockInTime;
  StreamSubscription? _shiftsSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shiftsSubscription?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_activeShift != null && _clockInTime != null) {
        final duration = DateTime.now().difference(_clockInTime!);
        final hours = duration.inHours.toString().padLeft(2, '0');
        final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
        setState(() {
          _timerText = "$hours:$minutes:$seconds";
        });
      }
    });
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userData = await UserRoleService.getCurrentUserData();
        final profilePic = await ProfilePictureService.getProfilePictureUrl();

        // Check active session logic
        final session = await ShiftTimesheetService.getOpenSession(user.uid);

        if (mounted) {
          setState(() {
            _userName = userData?['first_name'] ?? user.displayName ?? 'Teacher';
            _profilePicUrl = profilePic;
            
            if (session != null) {
              _activeShift = session['shift'] as TeachingShift?;
              _clockInTime = session['clockInTime'] as DateTime?;
            } else {
              _activeShift = null;
              _clockInTime = null;
            }
            _isLoading = false;
          });

          // Load shifts stream specifically for the selected date
          _listenToShiftsForDate(_selectedDate);
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _listenToShiftsForDate(DateTime date) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _shiftsSubscription?.cancel();
    
    // Using the real ShiftService to get shifts and filtering client-side
    _shiftsSubscription = ShiftService.getTeacherShifts(user.uid).listen((shifts) {
      if (mounted) {
        setState(() {
          _todayShifts = shifts.where((shift) {
            return shift.shiftStart.year == date.year &&
                   shift.shiftStart.month == date.month &&
                   shift.shiftStart.day == date.day;
          }).toList();
          
          // Sort by start time
          _todayShifts.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));
        });
      }
    });
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _isLoading = true; // Show loading briefly while fetching new date
    });
    // Re-fetch shifts logic here
    _listenToShiftsForDate(date);
    Future.delayed(
        const Duration(milliseconds: 300), () => setState(() => _isLoading = false));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Light grey background like Connecteam
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Header & Greetings
            _buildHeader(),

            // 2. Date Strip (Calendar)
            DateStripCalendar(
              selectedDate: _selectedDate,
              onDateSelected: _onDateSelected,
            ),

            // 3. Main Content (Scrollable)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ACTIVE SHIFT HERO CARD (If clocked in)
                          if (_activeShift != null) ...[
                            _buildActiveShiftHero(),
                            const SizedBox(height: 32),
                          ],

                          // NEXT UP / TIMELINE HEADER
                          Text(
                            AppLocalizations.of(context)!.shiftSchedule,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // TIMELINE
                          if (_todayShifts.isEmpty)
                            _buildEmptyState()
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _todayShifts.length,
                              itemBuilder: (context, index) {
                                return TimelineShiftCard(
                                  shift: _todayShifts[index],
                                  isLast: index == _todayShifts.length - 1,
                                  onTap: () {
                                    // Open time clock or shift details
                                    // Currently navigate to TimeClockScreen for simplicity
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const TimeClockScreen(),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),

                          const SizedBox(height: 80), // Padding for bottom nav
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.goodMorning,
                style: GoogleFonts.inter(
                    fontSize: 14, color: const Color(0xFF64748B)),
              ),
              Text(
                _userName,
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              // Navigate to settings or profile
              // You can implement this later
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                image: _profilePicUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_profilePicUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: _profilePicUrl == null
                  ? const Icon(Icons.person, color: Color(0xFF0386FF))
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveShiftHero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0386FF), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0386FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context)!.clockedIn,
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Text(
                _timerText, // Use the dynamic timer variable
                style: GoogleFonts.dmMono(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _activeShift?.displayName ?? "Unknown Class",
            style: GoogleFonts.inter(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _activeShift?.subjectDisplayName ?? "Class Session",
            style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.8), fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to TimeClock Screen
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TimeClockScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0386FF),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(AppLocalizations.of(context)!.manageShift,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.coffee_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noClassesScheduledToday,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8)),
            ),
            Text(
              AppLocalizations.of(context)!.dashboardEnjoyFreeTime,
              style: GoogleFonts.inter(
                  fontSize: 14, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}
