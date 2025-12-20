import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/enums/shift_enums.dart';
// import '../../../core/services/shift_service.dart'; // Unused
import '../../../core/services/shift_timesheet_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/shift_form_service.dart';
import '../../../core/services/user_role_service.dart';
import '../../../core/utils/timezone_utils.dart';
import '../../../core/utils/app_logger.dart';
import '../../../form_screen.dart';
import '../../time_clock/widgets/edit_timesheet_dialog.dart';
import 'report_schedule_issue_dialog.dart';
import 'reschedule_shift_dialog.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/zoom_service.dart';
import '../../../features/zoom/screens/in_app_zoom_meeting_screen.dart';

class ShiftDetailsDialog extends StatefulWidget {
  final TeachingShift shift;
  final VoidCallback? onPublishShift;
  final VoidCallback? onClaimShift;
  final VoidCallback? onRefresh;

  const ShiftDetailsDialog({
    super.key,
    required this.shift,
    this.onPublishShift,
    this.onClaimShift,
    this.onRefresh,
  });

  @override
  State<ShiftDetailsDialog> createState() => _ShiftDetailsDialogState();
}

class _ShiftDetailsDialogState extends State<ShiftDetailsDialog> {
  bool _isLoading = true;
  bool _isClockingIn = false;
  bool _isClockingOut = false;
  bool _useTeacherTimeZone = true; // Time zone toggle for display
  Map<String, dynamic>? _timesheetEntry;
  Map<String, dynamic>? _formResponse;
  Map<String, dynamic>? _modificationHistory;
  String _displayTimezone = 'UTC'; // For admin viewing modifications
  bool _isAdmin = false;

  // Timer for live elapsed time display
  Timer? _elapsedTimer;
  String _elapsedTime = "00:00:00";
  DateTime? _clockInTime;

  // Mapping of long question IDs to simplified labels for the Readiness Form
  static const Map<String, String> _simplifiedLabels = {
    '1762629945642': 'Teacher Name',
    '1754405971187': 'Equipment Used',
    '1754406115874': 'Class Type',
    '1754406288023': 'Class Day',
    '1754406414139': 'Duration (Hrs)',
    '1754406457284': 'Present Students',
    '1754406487572': 'Absent Students',
    '1754406512129': 'Late Students',
    '1754406537658': 'Weekly Video Rec',
    '1754406625835': 'Punctuality',
    '1754406729715': 'Weekly Status',
    '1754406826688': 'Clock-In Status',
    '1754406914911': 'Clock-Out Status',
    '1754407016623': 'Monthly Bayana',
    '1754407079872': 'Off-Schedule?',
    '1754407111959': 'Off-Schedule Reason',
    '1754407141413': 'Missed Bayana',
    '1754407184691': 'Topics Taught',
    '1754407218568': 'Student Work',
    '1754407297953': 'Curriculum Used',
    '1754407417507': 'Coach Support',
    '1754407509366': 'Teacher\'s Note',
    '1756564707506': 'Class Category',
    '1764288691217': 'Zoom Host',
  };

  List<Map<String, dynamic>> _allTimesheetEntries = [];

  // Stream subscriptions for real-time updates
  StreamSubscription? _timesheetSubscription;
  StreamSubscription? _shiftSubscription;

  // Cached shift data (for real-time status updates)
  TeachingShift? _liveShift;

  @override
  void initState() {
    super.initState();
    _liveShift = widget.shift;
    _checkAdminStatus();
    _loadDetails();
    _setupRealtimeListeners();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin = await UserRoleService.isAdmin();
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
        });
      }
    } catch (e) {
      AppLogger.error('Error checking admin status: $e');
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _timesheetSubscription?.cancel();
    _shiftSubscription?.cancel();
    super.dispose();
  }

  /// Setup real-time listeners for shift and timesheet changes
  void _setupRealtimeListeners() {
    // Listen for timesheet entry changes
    _timesheetSubscription = FirebaseFirestore.instance
        .collection('timesheet_entries')
        .where('shift_id', isEqualTo: widget.shift.id)
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      if (snapshot.docs.isNotEmpty) {
        final entries = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        
        setState(() {
          _allTimesheetEntries = entries;
          _timesheetEntry = entries.first;
        });
        
        // Restart elapsed timer if needed
        _startElapsedTimerIfActive();
        
        debugPrint("🔄 Real-time update: ${entries.length} timesheet entries");
      }
    }, onError: (e) {
      debugPrint("❌ Timesheet stream error: $e");
    });

    // Listen for shift status changes
    _shiftSubscription = FirebaseFirestore.instance
        .collection('teaching_shifts')
        .doc(widget.shift.id)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || !snapshot.exists) return;
      
      try {
        final updatedShift = TeachingShift.fromFirestore(snapshot);
        setState(() {
          _liveShift = updatedShift;
        });
        debugPrint("🔄 Shift status updated: ${updatedShift.status}");
      } catch (e) {
        debugPrint("❌ Shift stream parse error: $e");
      }
    }, onError: (e) {
      debugPrint("❌ Shift stream error: $e");
    });
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      debugPrint("🔍 Loading details for shift: ${widget.shift.id}");
      
      // OPTIMIZATION: Try both field names in parallel instead of sequentially
      final timesheetQueries = await Future.wait([
        FirebaseFirestore.instance
            .collection('timesheet_entries')
            .where('shift_id', isEqualTo: widget.shift.id)
            .orderBy('created_at', descending: true)
            .get(),
        FirebaseFirestore.instance
            .collection('timesheet_entries')
            .where('shiftId', isEqualTo: widget.shift.id)
            .orderBy('created_at', descending: true)
            .get(),
      ]);
      
      // Use the first non-empty result
      QuerySnapshot? timesheetQuery;
      if (timesheetQueries[0].docs.isNotEmpty) {
        timesheetQuery = timesheetQueries[0];
      } else if (timesheetQueries[1].docs.isNotEmpty) {
        debugPrint("⚠️ Found timesheet using shiftId (camelCase)");
        timesheetQuery = timesheetQueries[1];
      }
      
      if (timesheetQuery != null && timesheetQuery.docs.isNotEmpty) {
        _allTimesheetEntries = timesheetQuery.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        // Set the most recent one as _timesheetEntry for backward compatibility / status check
        if (mounted) {
          setState(() {
             _timesheetEntry = _allTimesheetEntries.first;
          });
        }
        
        debugPrint("✅ Found ${_allTimesheetEntries.length} timesheet entries");

        // 2. Find Form Response (link to the most recent timesheet or shift)
        // Check timesheet first, then check shift directly (for missed shifts)
        final formId = _timesheetEntry!['form_response_id'];
        Map<String, dynamic>? formResponse;
        
        if (formId != null) {
          final formDoc = await FirebaseFirestore.instance
              .collection('form_responses')
              .doc(formId)
              .get();
          if (formDoc.exists) {
            formResponse = formDoc.data();
          }
        } else {
          // Fallback queries for form response via timesheet
          var formQuery = await FirebaseFirestore.instance
              .collection('form_responses')
              .where('timesheetId', isEqualTo: _timesheetEntry!['id'])
              .limit(1)
              .get();
          
          if (formQuery.docs.isEmpty) {
            formQuery = await FirebaseFirestore.instance
                .collection('form_responses')
                .where('timesheet_id', isEqualTo: _timesheetEntry!['id'])
                .limit(1)
                .get();
          }

          if (formQuery.docs.isNotEmpty) {
            formResponse = formQuery.docs.first.data();
          }
        }
        
        if (mounted) {
            setState(() {
            _formResponse = formResponse;
            });
          }
        
        // Start timer if there's an active clock-in (no clock-out)
        _startElapsedTimerIfActive();
        }

      // 3. Load modification history if shift was modified by teacher
      final shiftDoc = await FirebaseFirestore.instance
          .collection('teaching_shifts')
          .doc(widget.shift.id)
          .get();
      
      if (shiftDoc.exists) {
        final shiftData = shiftDoc.data();
        if (shiftData?['teacher_modified'] == true) {
          // Load modification history
          final modQuery = await FirebaseFirestore.instance
              .collection('shift_modifications')
              .where('shift_id', isEqualTo: widget.shift.id)
              .orderBy('modified_at', descending: true)
              .limit(1)
              .get();
          
          if (modQuery.docs.isNotEmpty) {
            final modData = modQuery.docs.first.data();
            if (mounted) {
              setState(() {
                _modificationHistory = modData;
                _displayTimezone = modData['timezone_used'] ?? widget.shift.teacherTimezone ?? 'UTC';
              });
            }
          } else {
            // Fallback: use data from shift document
            if (mounted) {
              setState(() {
                _modificationHistory = {
                  'original_start_time': shiftData?['original_start_time'],
                  'original_end_time': shiftData?['original_end_time'],
                  'new_start_time': Timestamp.fromDate(widget.shift.shiftStart),
                  'new_end_time': Timestamp.fromDate(widget.shift.shiftEnd),
                  'teacher_modification_reason': shiftData?['teacher_modification_reason'],
                  'teacher_modified_at': shiftData?['teacher_modified_at'],
                  'timezone_used': shiftData?['timezone_used'] ?? widget.shift.teacherTimezone ?? 'UTC',
                };
                _displayTimezone = shiftData?['timezone_used'] ?? widget.shift.teacherTimezone ?? 'UTC';
              });
            }
          }
        }
      } else {
          // No timesheet entries - check if shift has form linked directly (missed shift case)
          debugPrint("⚠️ No timesheet entries found - checking for shift-linked form");
          
          // Check if shift has form_response_id directly
          final shiftDoc = await FirebaseFirestore.instance
              .collection('teaching_shifts')
              .doc(widget.shift.id)
              .get();
          
          if (shiftDoc.exists) {
            final shiftData = shiftDoc.data();
            final shiftFormId = shiftData?['form_response_id'];
            
            if (shiftFormId != null) {
              final formDoc = await FirebaseFirestore.instance
                  .collection('form_responses')
                  .doc(shiftFormId)
                  .get();
              if (formDoc.exists) {
                if (mounted) {
                  setState(() {
                    _formResponse = formDoc.data();
                  });
                }
              }
            } else {
              // Try querying by shiftId
              final formQuery = await FirebaseFirestore.instance
                  .collection('form_responses')
                  .where('shiftId', isEqualTo: widget.shift.id)
                  .limit(1)
                  .get();
              
              if (formQuery.docs.isNotEmpty) {
                if (mounted) {
                  setState(() {
                    _formResponse = formQuery.docs.first.data();
                  });
                }
              }
            }
          }
        debugPrint("❌ No timesheet found for shift: ${widget.shift.id} after all attempts");
      }

      // 3. Load modification history if shift was modified by teacher
      final shiftDocForMod = await FirebaseFirestore.instance
          .collection('teaching_shifts')
          .doc(widget.shift.id)
          .get();
      
      if (shiftDocForMod.exists) {
        final shiftData = shiftDocForMod.data();
        if (shiftData?['teacher_modified'] == true) {
          // Load modification history
          final modQuery = await FirebaseFirestore.instance
              .collection('shift_modifications')
              .where('shift_id', isEqualTo: widget.shift.id)
              .orderBy('modified_at', descending: true)
              .limit(1)
              .get();
          
          if (modQuery.docs.isNotEmpty) {
            final modData = modQuery.docs.first.data();
            if (mounted) {
              setState(() {
                _modificationHistory = modData;
                _displayTimezone = modData['timezone_used'] ?? widget.shift.teacherTimezone ?? 'UTC';
              });
            }
          } else {
            // Fallback: use data from shift document
            if (mounted) {
              setState(() {
                _modificationHistory = {
                  'original_start_time': shiftData?['original_start_time'],
                  'original_end_time': shiftData?['original_end_time'],
                  'new_start_time': Timestamp.fromDate(widget.shift.shiftStart),
                  'new_end_time': Timestamp.fromDate(widget.shift.shiftEnd),
                  'teacher_modification_reason': shiftData?['teacher_modification_reason'],
                  'teacher_modified_at': shiftData?['teacher_modified_at'],
                  'timezone_used': shiftData?['timezone_used'] ?? widget.shift.teacherTimezone ?? 'UTC',
                };
                _displayTimezone = shiftData?['timezone_used'] ?? widget.shift.teacherTimezone ?? 'UTC';
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading shift details: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Starts the elapsed time timer if the user is currently clocked in
  void _startElapsedTimerIfActive() {
    // Check if there's an active timesheet entry (has clock-in but no clock-out)
    for (final entry in _allTimesheetEntries) {
      final clockIn = entry['clock_in_time'] ?? entry['clock_in_timestamp'];
      final clockOut = entry['clock_out_time'] ?? entry['clock_out_timestamp'];
      
      if (clockIn != null && (clockOut == null || clockOut == '')) {
        // Found an active entry - start the timer
        if (clockIn is Timestamp) {
          _clockInTime = clockIn.toDate();
        } else if (clockIn is DateTime) {
          _clockInTime = clockIn;
        }
        
        if (_clockInTime != null) {
          _startElapsedTimer();
        }
        break;
      }
    }
  }

  /// Starts the timer that updates elapsed time every second
  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _clockInTime == null) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final elapsed = now.difference(_clockInTime!);
      setState(() {
        _elapsedTime = _formatDuration(elapsed);
      });

      // AUTO CLOCK-OUT CHECK
      // If current time is past shift end time, automatically clock out
      // Add 2 seconds buffer to ensure we are definitely past end time
      if (now.isAfter(widget.shift.shiftEnd.add(const Duration(seconds: 2)))) {
        _handleAutoClockOut();
      }
    });
    
    // Update immediately
    if (_clockInTime != null) {
      final elapsed = DateTime.now().difference(_clockInTime!);
      setState(() {
        _elapsedTime = _formatDuration(elapsed);
      });
    }
  }

  Future<void> _handleAutoClockOut() async {
    // Prevent multiple calls
    if (_isClockingOut) return;
    
    _elapsedTimer?.cancel();
    debugPrint("🕒 Auto clocking out: Time exceeded shift end");
    
    // Call standard clock out
    await _handleClockOut();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auto-clocked out: Shift time ended'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Stops the elapsed time timer
  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    setState(() {
      _elapsedTime = "00:00:00";
      _clockInTime = null;
    });
  }

  /// Formats a duration into HH:MM:SS string
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  // Check if clock-in is allowed right now
  bool get _canClockInNow {
    final now = DateTime.now();
    final shiftStart = widget.shift.shiftStart;
    final shiftEnd = widget.shift.shiftEnd;

    // Use live shift status for real-time updates
    final status = _liveShift?.status ?? widget.shift.status;
    
    // Only allow clock-in when it's actually time (at or after shift start, before shift end)
    // No early clock-in - must be at or after shift start time
    return (now.isAfter(shiftStart) || now.isAtSameMomentAs(shiftStart)) &&
        now.isBefore(shiftEnd) &&
        (status == ShiftStatus.scheduled || status == ShiftStatus.active);
  }

  // Build the button for joining class
  Widget _buildZoomButton() {
    final shift = _liveShift ?? widget.shift;
    final canJoin = ZoomService.canJoinClass(shift);
    final timeUntil = ZoomService.getTimeUntilCanJoin(shift);

    return Expanded(
      child: ElevatedButton.icon(
        onPressed: canJoin
            ? () => _handleJoinClass()
            : null,
        icon: const Icon(Icons.videocam, size: 20),
        label: Text(
          canJoin
              ? "Join Class"
              : timeUntil != null
                  ? "Join (${_formatTimeUntil(timeUntil)})"
                  : "Class Ended",
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canJoin ? const Color(0xFF0E72ED) : const Color(0xFF94A3B8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  String _formatTimeUntil(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    if (remainingMins == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainingMins}m';
  }

  Future<void> _handleJoinClass() async {
    final shift = _liveShift ?? widget.shift;

    // Simply join the class - ZoomService handles everything
    await ZoomService.joinClass(context, shift);
  }

  // Check if this is an upcoming shift (not yet time to clock in)
  bool get _isUpcoming {
    final now = DateTime.now();
    final status = _liveShift?.status ?? widget.shift.status;
    
    // If status is active, it's definitely not upcoming
    if (status == ShiftStatus.active) return false;
    
    return widget.shift.shiftStart.isAfter(now) &&
        status == ShiftStatus.scheduled;
  }

  // Check if shift is currently active (clocked in)
  bool get _isActive {
    // Check if ANY entry is currently active (has clock in but no clock out)
    for (final entry in _allTimesheetEntries) {
      final clockIn = entry['clock_in_time'] ?? entry['clock_in_timestamp'];
      final clockOut = entry['clock_out_time'] ?? entry['clock_out_timestamp'];
      
      if (clockIn != null && (clockOut == null || clockOut == '')) {
        return true;
      }
    }
    
    // STRICT CHECK: Only return true if we found an active timesheet entry.
    // ShiftStatus.active just means the class time has started, not that the teacher clocked in.
    return false;
  }

  // Check if shift is completed
  bool get _isCompleted {
    final status = _liveShift?.status ?? widget.shift.status;
    
    // STRICT: Only show completed if the cloud function has determined it
    // The cloud function (handleShiftEndTask) sets the status based on worked vs scheduled time
    // We trust the backend's calculation with 0 tolerance
    return status == ShiftStatus.completed ||
        status == ShiftStatus.fullyCompleted;
  }

  // Check if shift was missed
  bool get _isMissed {
    final now = DateTime.now();
    final status = _liveShift?.status ?? widget.shift.status;
    
    return (status == ShiftStatus.missed) ||
        (widget.shift.shiftEnd.isBefore(now) &&
            status == ShiftStatus.scheduled &&
            _timesheetEntry == null);
  }

  Future<void> _handleClockIn() async {
    setState(() => _isClockingIn = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Get location
      final location = await LocationService.getCurrentLocation();
      if (location == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get location. Please enable location services.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Clock in
      final result = await ShiftTimesheetService.clockInToShift(
        user.uid,
        widget.shift.id,
        location: location,
        platform: 'mobile',
      );

      if (result['success'] == true) {
        // Start the elapsed timer
        _clockInTime = DateTime.now();
        _startElapsedTimer();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clocked in successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
          widget.onRefresh?.call();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to clock in'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isClockingIn = false);
    }
  }

  Future<void> _handleClockOut() async {
    setState(() => _isClockingOut = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Get location
      final location = await LocationService.getCurrentLocation();
      if (location == null) {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get location. Please enable location services.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Clock out
      final result = await ShiftTimesheetService.clockOutFromShift(
        user.uid,
        widget.shift.id,
        location: location,
        platform: 'mobile',
      );

      if (result['success'] == true) {
        // Stop the elapsed timer
        _stopElapsedTimer();
        
        if (mounted) {
          Navigator.pop(context); // Close the shift details dialog

          // Extract timesheetId from the result
          // The service returns 'timesheetEntry' with 'documentId' inside
          final timesheetEntry = result['timesheetEntry'] as Map<String, dynamic>?;
          final timesheetId = timesheetEntry?['documentId'] ?? _timesheetEntry?['id'];
          
          debugPrint('🕐 Clock-out successful. TimesheetId: $timesheetId');

          // RELOAD details to fetch all timesheets including the new one
          if (mounted) {
            await _loadDetails();
          }

          // Navigate to the ACTUAL Readiness Form from the database
          // This uses the same form that appears in "Available Forms"
          if (mounted) {
            // Only navigate if we are fully clocked out (no active sessions left)
            // For now, we assume one session at a time per shift in UI logic, 
            // but _isActive checks all. If we just clocked out, _isActive should be false unless parallel sessions exist (unlikely)
            
            if (timesheetId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FormScreen(
                    timesheetId: timesheetId,
                    shiftId: widget.shift.id,
                    autoSelectFormId: ShiftFormService.readinessFormId, // The actual form ID
                  ),
                ),
              ).then((_) {
                // Refresh after returning from form
                widget.onRefresh?.call();
              });
            } else {
              // If no timesheetId, still refresh
              widget.onRefresh?.call();
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to clock out'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isClockingOut = false);
      }
    }

  void _showEditTimesheetDialog(String timesheetId) {
    if (_timesheetEntry == null) return;
    
    // Check if timesheet has been approved - if so, prevent editing
    final status = _timesheetEntry!['status'] as String?;
    final editApproved = _timesheetEntry!['edit_approved'] as bool?;
    
    // Prevent editing if:
    // 1. Status is 'approved' OR
    // 2. edit_approved is true (admin has approved an edit)
    if (status == 'approved' || editApproved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This timesheet has been approved and can no longer be edited',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => EditTimesheetDialog(
        timesheetId: timesheetId,
        timesheetData: Map<String, dynamic>.from(_timesheetEntry!),
        onUpdated: () {
          // Reload timesheet data after edit
          _loadDetails();
          widget.onRefresh?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 750),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                          _buildStatusBanner(),
                          const SizedBox(height: 20),
                          _buildShiftInfoSection(),
                          const SizedBox(height: 20),
                          _buildParticipantsSection(),
                          const SizedBox(height: 20),
                          _buildTimesheetSection(),
                          const SizedBox(height: 20),
                          _buildApprovalStatusSection(),
                          const SizedBox(height: 20),
                          _buildModificationHistorySection(),
                          const SizedBox(height: 20),
                          _buildFormSection(),
                  ],
                ),
              ),
            ),
            _buildFooterActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0386FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_note, color: Color(0xFF0386FF), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shift Details',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  widget.shift.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Reschedule & Report Issue buttons (for teachers)
          if (FirebaseAuth.instance.currentUser?.uid == widget.shift.teacherId) ...[
            // Only show reschedule if shift hasn't started yet
            if (widget.shift.shiftStart.isAfter(DateTime.now()))
              IconButton(
                icon: const Icon(Icons.schedule, color: Color(0xFF0386FF), size: 20),
                tooltip: 'Reschedule shift',
                onPressed: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => RescheduleShiftDialog(shift: widget.shift),
                  );
                  if (result == true) {
                    _loadDetails();
                    widget.onRefresh?.call();
                  }
                },
              ),
            IconButton(
              icon: const Icon(Icons.report_problem, color: Color(0xFFF59E0B), size: 20),
              tooltip: 'Report schedule issue',
              onPressed: () async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => ReportScheduleIssueDialog(shift: widget.shift),
                );
                if (result == true) {
                  // Refresh if timezone was updated
                  _loadDetails();
                  widget.onRefresh?.call();
                }
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF64748B)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    Color color;
    String label;
    IconData icon;
    String subtitle = '';

    if (_isActive) {
      color = const Color(0xFF10B981);
      label = "In Progress";
      icon = Icons.play_circle_fill;
      subtitle = "Elapsed Time: $_elapsedTime";
    } else if (_isCompleted) {
      color = const Color(0xFF8B5CF6);
      label = "Fully Completed";
      icon = Icons.check_circle;
      subtitle = "All scheduled time was worked";
    } else if ((_liveShift?.status ?? widget.shift.status) == ShiftStatus.partiallyCompleted) {
      color = const Color(0xFFF59E0B);
      label = "Partially Completed";
      icon = Icons.timelapse;
      subtitle = "Some time was worked";
    } else if (_isMissed) {
      color = const Color(0xFFEF4444);
      label = "Missed";
      icon = Icons.cancel;
      subtitle = "This shift was not attended";
    } else if (_canClockInNow) {
      color = const Color(0xFF10B981);
      label = "Ready to Start";
      icon = Icons.login;
      subtitle = "You can clock in now!";
    } else if (_isUpcoming) {
      color = const Color(0xFF0386FF);
      label = "Upcoming";
      icon = Icons.schedule;
      final timeUntil = widget.shift.shiftStart.difference(DateTime.now());
      if (timeUntil.inDays > 0) {
        subtitle = "Starts in ${timeUntil.inDays} day${timeUntil.inDays > 1 ? 's' : ''}";
      } else if (timeUntil.inHours > 0) {
        subtitle = "Starts in ${timeUntil.inHours} hour${timeUntil.inHours > 1 ? 's' : ''}";
      } else {
        subtitle = "Starts in ${timeUntil.inMinutes} minute${timeUntil.inMinutes > 1 ? 's' : ''}";
      }
    } else {
      color = const Color(0xFF64748B);
      label = (_liveShift?.status ?? widget.shift.status).name.toUpperCase();
      icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
        color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
                  ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                    style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                    ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftInfoSection() {
    final duration = widget.shift.shiftEnd.difference(widget.shift.shiftStart);
    final hours = duration.inMinutes / 60.0;

    return _buildSection(
      title: "Schedule Information",
      icon: Icons.calendar_today_outlined,
      children: [
        _detailRow("Date", DateFormat('EEEE, MMMM d, yyyy').format(widget.shift.shiftStart)),
        _detailRow("Time", "${DateFormat('h:mm a').format(widget.shift.shiftStart)} - ${DateFormat('h:mm a').format(widget.shift.shiftEnd)}"),
        _detailRow("Duration", "${hours.toStringAsFixed(1)} hours"),
        _detailRow("Subject", widget.shift.effectiveSubjectDisplayName),
        if (widget.shift.hourlyRate > 0)
          _detailRow("Hourly Rate", "\$${widget.shift.hourlyRate.toStringAsFixed(2)}/hr"),
        if (widget.shift.notes != null && widget.shift.notes!.isNotEmpty)
          _detailRow("Notes", widget.shift.notes!),
      ],
    );
  }

  Widget _buildParticipantsSection() {
    return _buildSection(
      title: "Participants",
      icon: Icons.people_outline,
      children: [
        _detailRow("Teacher", widget.shift.teacherName),
        if (widget.shift.studentNames.isNotEmpty)
          _detailRow(
            "Students",
            widget.shift.studentNames.length == 1
                ? widget.shift.studentNames.first
                : "${widget.shift.studentNames.length} students",
          ),
        if (widget.shift.studentNames.length > 1)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.shift.studentNames.map((name) {
                return Chip(
                  label: Text(name, style: GoogleFonts.inter(fontSize: 12)),
                  backgroundColor: const Color(0xFFF1F5F9),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
        ),
      ],
    );
  }

  Widget _buildTimesheetSection() {
    // 1. If we have timesheet entries, show them
    if (_allTimesheetEntries.isNotEmpty) {
      
      // Calculate total worked seconds across all entries (for precision)
      // Use effective_end_timestamp (capped) or cap clock_out_time to shift end for consistency
      int totalSeconds = 0;
      for (final entry in _allTimesheetEntries) {
        final clockIn = entry['clock_in_time'] ?? entry['clock_in_timestamp'];
        // Prefer effective_end_timestamp (capped time) for consistency with payment calculation
        final clockOut = entry['effective_end_timestamp'] ?? entry['clock_out_time'] ?? entry['clock_out_timestamp'];
        
        if (clockIn != null && clockIn is Timestamp && clockOut != null && clockOut is Timestamp) {
          DateTime start = clockIn.toDate();
          DateTime end = clockOut.toDate();
          
          // Cap at shift end time to match payment calculation
          if (end.isAfter(widget.shift.shiftEnd)) {
            end = widget.shift.shiftEnd;
          }
          
          // Cap start time at shift start (shouldn't happen, but safety check)
          if (start.isBefore(widget.shift.shiftStart)) {
            start = widget.shift.shiftStart;
          }
          
          final duration = end.difference(start);
          if (!duration.isNegative) {
            totalSeconds += duration.inSeconds;
          }
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           _buildSection(
            title: "Timesheet Records (${_allTimesheetEntries.length})",
            icon: Icons.access_time,
            children: [
              if (totalSeconds > 0)
                 _detailRow("Total Worked", _formatDuration(Duration(seconds: totalSeconds))),
              const Divider(),
              ..._allTimesheetEntries.map((entry) {
                 final clockIn = entry['clock_in_time'] ?? entry['clock_in_timestamp'];
                 final clockOut = entry['clock_out_time'] ?? entry['clock_out_timestamp'];
                 DateTime? start;
                 DateTime? end;
                 
                 if (clockIn != null && clockIn is Timestamp) start = clockIn.toDate();
                 // Use effective_end_timestamp (capped) for display consistency
                 final effectiveEnd = entry['effective_end_timestamp'] ?? clockOut;
                 if (effectiveEnd != null && effectiveEnd is Timestamp) {
                   end = effectiveEnd.toDate();
                   // Cap at shift end for display
                   if (end.isAfter(widget.shift.shiftEnd)) {
                     end = widget.shift.shiftEnd;
                   }
                 }
                 
                 final isEntryCompleted = end != null;
                 final timesheetId = entry['id'] as String?;

                 return Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     _detailRow("Clock In", start != null ? DateFormat('h:mm a').format(start) : "Unknown"),
                     _detailRow("Clock Out", end != null ? DateFormat('h:mm a').format(end) : "Active Now"),
                     if (end != null && start != null) ...[
                       // Cap start time at shift start for display
                       _detailRow("Duration", _formatDuration(end.difference(start.isBefore(widget.shift.shiftStart) ? widget.shift.shiftStart : start))),
                     ],
                     
                     if (isEntryCompleted && timesheetId != null) ...[
                       Padding(
                         padding: const EdgeInsets.only(top: 8.0),
                         child: () {
                           // Check if this entry is approved
                           final entryStatus = entry['status'] as String?;
                           final editApproved = entry['edit_approved'] as bool?;
                           final isApproved = entryStatus == 'approved' || editApproved == true;
                           
                           return SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: isApproved ? null : () => _showEditTimesheetDialog(timesheetId),
                                icon: Icon(
                                  isApproved ? Icons.lock : Icons.edit,
                                  size: 16,
                                ),
                                label: Text(
                                  isApproved ? "Approved (Locked)" : "Edit Entry",
                                  style: GoogleFonts.inter(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: isApproved ? const Color(0xFF64748B) : null,
                                  side: BorderSide(
                                    color: isApproved ? const Color(0xFFE2E8F0) : const Color(0xFF0386FF),
                                  ),
                                ),
                              ),
                           );
                         }(),
                       ),
                       // Show approval badge if approved
                       if ((entry['status'] as String?) == 'approved' || (entry['edit_approved'] as bool?) == true)
                         Padding(
                           padding: const EdgeInsets.only(top: 8.0),
                           child: Container(
                             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                             decoration: BoxDecoration(
                               color: const Color(0xFFDCFCE7),
                               borderRadius: BorderRadius.circular(6),
                               border: Border.all(color: const Color(0xFF86EFAC)),
                             ),
                             child: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 const Icon(Icons.verified, size: 14, color: Color(0xFF059669)),
                                 const SizedBox(width: 6),
                                 Text(
                                   'Admin Approved',
                                   style: GoogleFonts.inter(
                                     fontSize: 11,
                                     fontWeight: FontWeight.w600,
                                     color: const Color(0xFF059669),
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         ),
                     ],
                     const Divider(),
                   ],
                 );
              }).toList(),
            ],
          ),
        ],
      );
    }

    // 2. If no timesheet, show warning ONLY if it should exist (past/completed)
    final now = DateTime.now();
    // Check if shift is past its end time
    final isPast = widget.shift.shiftEnd.isBefore(now);
    // Check if shift is marked as completed/missed or is past due
    final shouldHaveTimesheet = _isCompleted || _isMissed || isPast;
    
    // Only show warning if it should have a timesheet but doesn't (and isn't active)
    if (shouldHaveTimesheet && !_isActive && !_canClockInNow && !_isUpcoming) {
      return Container(
        padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 24),
            const SizedBox(width: 12),
            Expanded(
          child: Text(
                "No timesheet record found for this past shift.",
            style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFDC2626),
            ),
          ),
        ),
      ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  // Approval status and earnings section
  Widget _buildApprovalStatusSection() {
    // Only show if there are timesheet entries
    if (_allTimesheetEntries.isEmpty) return const SizedBox.shrink();
    
    // Use the first entry for status tracking (all entries share the same approval status)
    final status = (_timesheetEntry?['status'] as String?) ?? 'pending';
    // final approvedBy = _timesheetEntry?['approved_by'] as String?; // Not currently used
    final approvedAt = _timesheetEntry?['approved_at'] as Timestamp?;
    final isEdited = _timesheetEntry?['is_edited'] as bool? ?? false;
    final editApproved = _timesheetEntry?['edit_approved'] as bool? ?? false;
    
    // Get hourly rate for display and calculation
    final hourlyRate = (widget.shift.hourlyRate > 0) 
        ? widget.shift.hourlyRate 
        : (_timesheetEntry?['hourly_rate'] as num?)?.toDouble() ?? 15.0;
    
    // Use actual payment from timesheet if available (saved during clock-out)
    // This ensures consistency between phone and website
    double earnings = 0.0;
    
    // Sum up payment_amount from all timesheet entries
    for (final entry in _allTimesheetEntries) {
      final paymentAmount = (entry['payment_amount'] as num?)?.toDouble() ??
          (entry['total_pay'] as num?)?.toDouble() ??
          0.0;
      earnings += paymentAmount;
    }
    
    // If no payment found in timesheet (legacy data or not clocked out yet),
    // calculate from hours worked as fallback
    if (earnings == 0.0 && _allTimesheetEntries.isNotEmpty) {
      
      int totalSeconds = 0;
      
      // Calculate total time worked across ALL entries (using seconds for precision)
      // Prefer using the new 'effective_end_timestamp' if available, otherwise use clock_out
      for (final entry in _allTimesheetEntries) {
        final clockIn = entry['clock_in_time'] ?? entry['clock_in_timestamp'];
        // Prefer effective_end_timestamp (capped time) for payment calculation
        final clockOut = entry['effective_end_timestamp'] ?? entry['clock_out_time'] ?? entry['clock_out_timestamp'];
        
        if (clockIn != null && clockOut != null && clockIn is Timestamp && clockOut is Timestamp) {
          DateTime start = clockIn.toDate();
          DateTime end = clockOut.toDate();

          // FRONTEND SAFEGUARD: Cap at shift end if the backend field didn't exist yet
          if (end.isAfter(widget.shift.shiftEnd)) {
            end = widget.shift.shiftEnd;
          }

          // Calculate duration, ensuring no negative values
          final duration = end.difference(start);
          if (!duration.isNegative) {
            totalSeconds += duration.inSeconds;
          }
        }
      }
      
      // Convert seconds to hours for earnings calculation (precise)
      final hoursWorked = totalSeconds / 3600.0;
      earnings = hoursWorked * hourlyRate;
    }
    
    // Format total time for display (if we calculated it)
    int totalSeconds = 0;
    for (final entry in _allTimesheetEntries) {
      final clockIn = entry['clock_in_time'] ?? entry['clock_in_timestamp'];
      final clockOut = entry['effective_end_timestamp'] ?? entry['clock_out_time'] ?? entry['clock_out_timestamp'];
      
      if (clockIn != null && clockOut != null && clockIn is Timestamp && clockOut is Timestamp) {
        DateTime start = clockIn.toDate();
        DateTime end = clockOut.toDate();
        if (end.isAfter(widget.shift.shiftEnd)) {
          end = widget.shift.shiftEnd;
        }
        final duration = end.difference(start);
        if (!duration.isNegative) {
          totalSeconds += duration.inSeconds;
        }
      }
    }
    
    // Format total time as HH:MM:SS for display
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final formattedTime = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    // Determine status display
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusSubtitle = '';
    
    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        statusText = 'Approved';
        if (approvedAt != null) {
          statusSubtitle = 'Approved on ${DateFormat('MMM d, yyyy').format(approvedAt.toDate())}';
        }
        break;
      case 'paid':
        statusColor = const Color(0xFF059669);
        statusIcon = Icons.payments;
        statusText = 'Paid';
        statusSubtitle = 'Payment processed';
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
        statusSubtitle = 'Please review and resubmit';
        break;
      default: // pending
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.pending;
        statusText = 'Pending Approval';
        statusSubtitle = 'Awaiting admin review';
    }
    
    // Check for edit status
    if (isEdited && !editApproved) {
      statusColor = const Color(0xFF8B5CF6);
      statusIcon = Icons.edit_note;
      statusText = 'Edit Pending';
      statusSubtitle = 'Your edit is awaiting approval';
    }
    
    return _buildSection(
      title: "Approval & Earnings",
      icon: Icons.verified,
      children: [
        // Time zone toggle (optional - for admin viewing)
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              _useTeacherTimeZone ? "Shift Time" : "Local Time",
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            Switch(
              value: !_useTeacherTimeZone,
              activeColor: const Color(0xFF0386FF),
              onChanged: (val) {
                setState(() {
                  _useTeacherTimeZone = !val;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Status badge
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                    if (statusSubtitle.isNotEmpty)
                      Text(
                        statusSubtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: statusColor.withOpacity(0.8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Earnings card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0386FF).withOpacity(0.1),
                const Color(0xFF10B981).withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated Earnings',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${earnings.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (status == 'approved' || status == 'paid') 
                          ? const Color(0xFF10B981).withOpacity(0.2)
                          : const Color(0xFFF59E0B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      (status == 'approved' || status == 'paid') 
                          ? Icons.check_circle 
                          : Icons.schedule,
                      color: (status == 'approved' || status == 'paid') 
                          ? const Color(0xFF10B981) 
                          : const Color(0xFFF59E0B),
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildEarningDetail(
                    label: 'Time Worked',
                    value: formattedTime,
                    icon: Icons.access_time,
                  ),
                  _buildEarningDetail(
                    label: 'Rate',
                    value: '\$${hourlyRate.toStringAsFixed(2)}/hr',
                    icon: Icons.attach_money,
                  ),
                  _buildEarningDetail(
                    label: 'Status',
                    value: status == 'approved' || status == 'paid' ? '✓ Confirmed' : 'Pending',
                    icon: (status == 'approved' || status == 'paid') 
                        ? Icons.verified 
                        : Icons.pending,
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Manager notes if available
        if (_timesheetEntry != null && 
            _timesheetEntry!['manager_notes'] != null && 
            (_timesheetEntry!['manager_notes'] as String).isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.comment, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manager Notes',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timesheetEntry!['manager_notes'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildEarningDetail({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildModificationHistorySection() {
    // Only show for admins and if shift was modified by teacher
    if (_modificationHistory == null || !_isAdmin) {
      return const SizedBox.shrink();
    }

    final originalStart = _modificationHistory!['original_start_time'] as Timestamp?;
    final originalEnd = _modificationHistory!['original_end_time'] as Timestamp?;
    final newStart = _modificationHistory!['new_start_time'] as Timestamp?;
    final newEnd = _modificationHistory!['new_end_time'] as Timestamp?;
    final reason = _modificationHistory!['teacher_modification_reason'] as String?;
    final modifiedAt = _modificationHistory!['teacher_modified_at'] as Timestamp?;
    final timezoneUsed = _modificationHistory!['timezone_used'] as String? ?? _displayTimezone;

    if (originalStart == null || originalEnd == null || newStart == null || newEnd == null) {
      return const SizedBox.shrink();
    }

    // Convert times to display timezone
    final originalStartLocal = TimezoneUtils.convertToTimezone(originalStart.toDate(), _displayTimezone);
    final originalEndLocal = TimezoneUtils.convertToTimezone(originalEnd.toDate(), _displayTimezone);
    final newStartLocal = TimezoneUtils.convertToTimezone(newStart.toDate(), _displayTimezone);
    final newEndLocal = TimezoneUtils.convertToTimezone(newEnd.toDate(), _displayTimezone);

    return _buildSection(
      title: "Modification History",
      icon: Icons.edit_note,
      children: [
        // Timezone selector for admins
        Row(
          children: [
            Expanded(
              child: Text(
                'Display Timezone:',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _displayTimezone,
                  isDense: true,
                  style: GoogleFonts.inter(fontSize: 12),
                  items: TimezoneUtils.getCommonTimezones().map((tz) {
                    return DropdownMenuItem<String>(
                      value: tz,
                      child: Text(tz, style: GoogleFonts.inter(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _displayTimezone = value);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        // Original times
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Original Schedule',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${DateFormat('MMM d, h:mm a').format(originalStartLocal)} - ${DateFormat('h:mm a').format(originalEndLocal)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Text(
                '(${TimezoneUtils.getTimezoneAbbreviation(_displayTimezone)})',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Arrow
        Center(
          child: Icon(Icons.arrow_downward, size: 20, color: Colors.blue.shade700),
        ),
        const SizedBox(height: 12),
        // New times
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Modified Schedule',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${DateFormat('MMM d, h:mm a').format(newStartLocal)} - ${DateFormat('h:mm a').format(newEndLocal)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Text(
                '(${TimezoneUtils.getTimezoneAbbreviation(_displayTimezone)})',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        if (reason != null && reason.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Reason',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  reason,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (modifiedAt != null) ...[
          const SizedBox(height: 8),
          Text(
            'Modified: ${DateFormat('MMM d, yyyy h:mm a').format(modifiedAt.toDate())}',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF64748B),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.public, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              'Teacher used timezone: ${timezoneUsed}',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF64748B),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormSection() {
    final isReportSubmitted = _formResponse != null;
    
    bool hasTimesheet = false;
    if (_timesheetEntry != null) {
      final clockOut = _timesheetEntry!['clock_out_time'] ?? _timesheetEntry!['clock_out_timestamp'];
      hasTimesheet = clockOut != null;
    }

    if (isReportSubmitted) {
      // Show submitted form info
    return Container(
        padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                const Icon(Icons.assignment_turned_in, color: Color(0xFF15803D), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Text(
                        "Class Report Submitted",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                          color: const Color(0xFF15803D),
                  ),
                ),
                      if (_formResponse!['reportedHours'] != null)
                        Text(
                          "Hours Logged: ${_formResponse!['reportedHours']} hrs",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF166534),
                          ),
                        ),
                    ],
            ),
          ),
        ],
      ),
            // Show form responses if available
            if (_formResponse!['responses'] != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              ...(_formResponse!['responses'] as Map<String, dynamic>).entries.map((entry) {
                if (entry.value == null || entry.value.toString().isEmpty) {
                  return const SizedBox.shrink();
                }
    return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
            child: Text(
                    "${_formatFieldName(entry.key)}: ${entry.value}",
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF4B5563)),
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      );
    } else if (hasTimesheet) {
      // Shift done but no report - show button to fill the ACTUAL form from database
      return Container(
            padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCD34D)),
              ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
                const SizedBox(width: 12),
          Expanded(
            child: Text(
                    "Class Report Not Submitted",
              style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFD97706),
              ),
            ),
          ),
        ],
      ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final timesheetId = _timesheetEntry!['id'];
                  final shiftId = widget.shift.id;
                  final formId = ShiftFormService.readinessFormId;
                  
                  debugPrint('📋 Fill Form button pressed:');
                  debugPrint('   - timesheetId: $timesheetId');
                  debugPrint('   - shiftId: $shiftId');
                  debugPrint('   - formId: $formId');
                  
                  // Verify the form exists before navigating
                  final formDoc = await FirebaseFirestore.instance
                      .collection('form')
                      .doc(formId)
                      .get();
                  
                  if (!formDoc.exists) {
                    debugPrint('❌ Form with ID $formId does NOT exist in database!');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Form not found. Please contact admin. (ID: $formId)'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }
                  
                  debugPrint('✅ Form exists: ${formDoc.data()?['title'] ?? 'Untitled'}');
                  
                  // Navigate to the form
                  if (mounted) {
                    Navigator.pop(context); // Close the dialog first
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FormScreen(
                          timesheetId: timesheetId,
                          shiftId: shiftId,
                          autoSelectFormId: formId,
                        ),
                      ),
                    ).then((_) {
                      // Refresh after returning from form
                      widget.onRefresh?.call();
                    });
                  }
                },
                icon: const Icon(Icons.assignment),
                label: const Text("Fill Class Report Now"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
            ),
          ),
        ],
        ),
      );
    } else {
      // Missed shift case - no timesheet entry, but can still fill form
      final shiftStatus = _liveShift?.status ?? widget.shift.status;
      final isMissed = shiftStatus == ShiftStatus.missed;
      
      if (isMissed) {
        // Check if form already submitted for this missed shift
        final hasForm = _formResponse != null;
        
        if (hasForm) {
          // Form already submitted for missed shift
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment_turned_in, color: Color(0xFF15803D), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Class Report Submitted (Missed Shift)",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                          if (_formResponse!['reportedHours'] != null)
                            Text(
                              "Hours Logged: ${_formResponse!['reportedHours']} hrs",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF166534),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Show form responses if available
                if (_formResponse!['responses'] != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  ...(_formResponse!['responses'] as Map<String, dynamic>).entries.map((entry) {
                    if (entry.value == null || entry.value.toString().isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        "${_formatFieldName(entry.key)}: ${entry.value}",
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF4B5563)),
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          );
        } else {
          // No form submitted yet - show button to fill form
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Missed Shift - Class Report Required",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "This shift was missed. Please fill out the readiness form to explain the reason.",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final shiftId = widget.shift.id;
                      final formId = ShiftFormService.readinessFormId;
                      
                      debugPrint('📋 Fill Form button pressed for missed shift:');
                      debugPrint('   - shiftId: $shiftId');
                      debugPrint('   - formId: $formId');
                      
                      // Verify the form exists before navigating
                      final formDoc = await FirebaseFirestore.instance
                          .collection('form')
                          .doc(formId)
                          .get();
                      
                      if (!formDoc.exists) {
                        debugPrint('❌ Form with ID $formId does NOT exist in database!');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Form not found. Please contact admin. (ID: $formId)'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return;
                      }
                      
                      debugPrint('✅ Form exists: ${formDoc.data()?['title'] ?? 'Untitled'}');
                      
                      // Navigate to the form (no timesheetId for missed shifts)
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FormScreen(
                              timesheetId: null, // No timesheet for missed shift
                              shiftId: shiftId,
                              autoSelectFormId: formId,
                            ),
                          ),
                        ).then((_) {
                          // Refresh after returning from form
                          _loadDetails();
                          widget.onRefresh?.call();
                        });
                      }
                    },
                    icon: const Icon(Icons.assignment),
                    label: const Text("Fill Class Report Now"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      }
    }

    return const SizedBox.shrink();
  }

  String _formatFieldName(String fieldName) {
    // Check if we have a simplified label for this field ID
    if (_simplifiedLabels.containsKey(fieldName)) {
      return _simplifiedLabels[fieldName]!;
    }

    // Fallback to formatting the key if it's not in our map
    return fieldName
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');
    }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
              children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
                const SizedBox(width: 8),
          Text(
                  title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
            ),
          ),
              ],
            ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
            padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
            style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
          style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
        ),
      );
    }

  Widget _buildFooterActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          // Close button
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Text(
                "Close",
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
            ),
          ),
            ),
          ),

          // Zoom button (if meeting is configured and within time window)
          if (_liveShift?.hasZoomMeeting == true || widget.shift.hasZoomMeeting) ...[
            const SizedBox(width: 8),
            _buildZoomButton(),
          ],

          // Clock In/Out or Claim button
          if (_canClockInNow && !_isActive) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isClockingIn ? null : _handleClockIn,
                icon: _isClockingIn
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.login),
                  label: Text(
                  _isClockingIn ? "Clocking In..." : "Clock In",
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    ),
                  ),
          ] else if (_isActive) ...[
                const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isClockingOut ? null : _handleClockOut,
                icon: _isClockingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.logout),
                  label: Text(
                  _isClockingOut ? "Clocking Out..." : "Clock Out",
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
          ] else if (_isUpcoming) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: null, // Disabled
                icon: const Icon(Icons.schedule),
                  label: Text(
                  "Clock In (Not Yet)",
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF94A3B8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
          ] else if (widget.onClaimShift != null) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  widget.onClaimShift?.call();
                  },
                icon: const Icon(Icons.add_task),
                  label: Text(
                  "Claim Shift",
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

