import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../widgets/modern_header.dart';
import '../shared/widgets/fade_in_slide.dart';
import '../core/models/enrollment_request.dart';
import '../core/services/enrollment_service.dart';
import 'enrollment_success_page.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

// Helper class for time ranges
class _TimeRange {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  
  const _TimeRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });
}

// Helper class for student input (multi-student support with individual program)
class _StudentInput {
  final TextEditingController nameController;
  final TextEditingController ageController;
  String? gender;
  
  // Individual program details for each student
  String? subject;
  String? specificLanguage;
  String? level;
  String? classType;
  String? sessionDuration;
  String? timeOfDayPreference;
  List<String> selectedDays;
  List<String> selectedTimeSlots;
  
  _StudentInput() 
    : nameController = TextEditingController(),
      ageController = TextEditingController(),
      gender = null,
      subject = null,
      specificLanguage = null,
      level = null,
      classType = null,
      sessionDuration = null,
      timeOfDayPreference = null,
      selectedDays = [],
      selectedTimeSlots = [];
  
  void dispose() {
    nameController.dispose();
    ageController.dispose();
  }
}

class ProgramSelectionPage extends StatefulWidget {
  final String? initialSubject;
  final bool isLanguageSelection;
  final String? initialAfricanLanguage;

  const ProgramSelectionPage({
    super.key,
    this.initialSubject,
    this.isLanguageSelection = false,
    this.initialAfricanLanguage,
  });

  @override
  State<ProgramSelectionPage> createState() => _ProgramSelectionPageState();
}

class _ProgramSelectionPageState extends State<ProgramSelectionPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  late AnimationController _progressController;
  late AnimationController _cardController;
  int _currentStep = 0;
  
  // Controllers
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _whatsAppNumberController = TextEditingController();
  final _studentNameController = TextEditingController();
  final _studentAgeController = TextEditingController();
  final _parentIdentityController = TextEditingController();
  
  // State variables
  bool _isCheckingIdentity = false;
  Map<String, dynamic>? _linkedParentData;
  String? _guardianId;

  String? _selectedSubject;
  String? _selectedGrade;
  String? _selectedAfricanLanguage;
  Country? _selectedCountry;
  String _phoneNumber = '';
  String _ianaTimeZone = 'UTC'; // IANA timezone (e.g., 'America/New_York', 'Africa/Casablanca')
  String _initialCountryCode = 'US'; // For syncing phone field with country picker
  bool _isSubmitting = false;
  
  // Enhanced form fields
  String? _role; // Must be selected explicitly
  String? _preferredLanguage;
  String _whatsAppNumber = '';
  String? _gender;
  // Removed: bool? _knowsZoom; (Zoom question removed)
  String? _classType;
  String? _sessionDuration;
  String? _timeOfDayPreference;
  String? _selectedLevel; // For program level (Beginner/Intermediate/Advanced or After School levels)
  
  // Multi-student support
  final List<_StudentInput> _students = [];
  
  // Available options
  final List<String> _subjects = [
    'Islamic Program (Arabic, Quran, etc...)',
    'AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)',
    'Entrepreneurship',
    'Coding',
    'After School Tutoring (Math, Science, Physics, etc...)',
    'Adult Literacy (Reading and Writing English & French, etc...)',
  ];

  final List<String> _otherAfricanLanguages = [
    'Pular',
    'Mandingo',
    'Swahili',
    'Wolof',
    'Hausa',
    'Yoruba',
    'Other'
  ];

  final List<String> _grades = [
    'Elementary School',
    'Middle School',
    'High School',
    'University',
    'Adult Professionals'
  ];

  // Program level options (for non-After School programs)
  final List<String> _programLevelOptions = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  // After School level options
  final List<String> _afterSchoolLevelOptions = [
    'Elementary School',
    'Middle School',
    'High School',
    'University',
  ];

  // Get current level options based on selected subject
  List<String> get _currentLevels {
    if (_selectedSubject == 'After School Tutoring (Math, Science, Physics, etc...)') {
      return _afterSchoolLevelOptions;
    }
    return _programLevelOptions;
  }

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _selectedDays = [];
  
  static const Map<String, _TimeRange> _timeRanges = {
    'Morning':
        _TimeRange(startHour: 6, startMinute: 0, endHour: 12, endMinute: 0),
    'Afternoon':
        _TimeRange(startHour: 12, startMinute: 0, endHour: 17, endMinute: 0),
    'Evening':
        _TimeRange(startHour: 17, startMinute: 0, endHour: 21, endMinute: 0),
  };
  
  final List<String> _selectedTimeSlots = [];
  
  List<String> get _filteredTimeSlots {
    if (_timeOfDayPreference == null ||
        _timeOfDayPreference == 'Flexible' ||
        _sessionDuration == null) {
      if (_timeOfDayPreference == null || _timeOfDayPreference == 'Flexible') {
        return ['8 AM - 12 PM', '12 PM - 4 PM', '4 PM - 8 PM', '8 PM - 12 AM'];
      }
      return [];
    }
    final timeRange = _timeRanges[_timeOfDayPreference];
    if (timeRange == null) return [];
    final durationMinutes = _parseDurationToMinutes(_sessionDuration!);
    if (durationMinutes == null) return [];
    return _generateTimeSlots(
      startHour: timeRange.startHour,
      startMinute: timeRange.startMinute,
      endHour: timeRange.endHour,
      endMinute: timeRange.endMinute,
      durationMinutes: durationMinutes,
    );
  }
  
  int? _parseDurationToMinutes(String duration) {
    // Handle new duration format - check longer/more specific durations first
    if (duration.contains('1 hr 30')) return 90; // Must check before '30 mins' and '1 hr'
    if (duration.contains('2 hr 30')) return 150; // Must check before '30 mins' and '2 hrs'
    if (duration.contains('30 mins')) return 30;
    if (duration.contains('1 hr')) return 60; // Must check after '1 hr 30' to avoid partial match
    if (duration.contains('2 hrs')) return 120; // Must check after '2 hr 30' to avoid partial match
    if (duration.contains('3 hrs')) return 180;
    if (duration.contains('4 hrs')) return 240;
    return null;
  }
  
  List<String> _generateTimeSlots({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required int durationMinutes,
  }) {
    final slots = <String>[];
    final startTotalMinutes = startHour * 60 + startMinute;
    final endTotalMinutes = endHour * 60 + endMinute;
    int currentMinutes = startTotalMinutes;
    while (currentMinutes + durationMinutes <= endTotalMinutes) {
      final startTime = _formatTimeFromMinutes(currentMinutes);
      final endTime = _formatTimeFromMinutes(currentMinutes + durationMinutes);
      slots.add('$startTime - $endTime');
      currentMinutes += durationMinutes;
    }
    return slots;
  }
  
  String _formatTimeFromMinutes(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final hour12 = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours);
    final period = hours < 12 ? 'AM' : 'PM';
    final minuteStr = minutes.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $period';
  }
  
  final List<String> _roles = ['Student', 'Parent', 'Guardian'];
  final List<String> _languages = ['English', 'French', 'Arabic', 'Other'];
  final List<String> _genders = ['Male', 'Female']; // Removed "Prefer not to say"
  final List<String> _classTypes = ['One-on-One', 'Group', 'Both'];
  final List<String> _sessionDurations = [
    '30 mins',
    '1 hr',
    '1 hr 30 mins',
    '2 hrs',
    '2 hr 30 mins',
    '3 hrs',
    '4 hrs',
  ];
  final List<String> _timeOfDayOptions = [
    'Morning',
    'Afternoon',
    'Evening',
    'Flexible'
  ];

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.initialSubject;
    _selectedAfricanLanguage = widget.initialAfricanLanguage;
    _selectedCountry = Country.parse('US');
    _initialCountryCode = 'US';

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _cardController.forward();
    
    // Initialize IANA timezone
    _initTimezone();
  }

  Future<void> _initTimezone() async {
    try {
      final dynamic timezoneInfo = await FlutterTimezone.getLocalTimezone();
      // In version 5.0.1+, this returns TimezoneInfo, but in older versions it returned String.
      String currentTimeZone;
      if (timezoneInfo is String) {
        currentTimeZone = timezoneInfo;
      } else {
        // TimezoneInfo has an identifier property
        currentTimeZone = timezoneInfo.identifier as String;
      }
      if (mounted) {
        setState(() {
          _ianaTimeZone = currentTimeZone;
        });
      }
    } catch (e) {
      debugPrint('Could not get IANA timezone: $e');
      // Fallback to UTC if timezone detection fails
      if (mounted) {
        setState(() {
          _ianaTimeZone = 'UTC';
        });
      }
    }
  }

  Future<void> _checkParentIdentity() async {
    final identifier = _parentIdentityController.text.trim();
    if (identifier.isEmpty) {
      _showSnackBar('Please enter an email or kiosque code to link account', isError: true);
      return;
    }

    setState(() => _isCheckingIdentity = true);

    try {
      final result = await EnrollmentService().checkParentIdentity(identifier);

      if (mounted) {
        if (result != null) {
          setState(() {
            _linkedParentData = result;
            _guardianId = result['userId'];
            _parentNameController.text =
                '${result['firstName']} ${result['lastName']}'.trim();
            _emailController.text = result['email'] ?? '';
            _phoneController.text = result['phone'] ?? '';
            _phoneNumber = result['phone'] ?? '';
          });
          _showSnackBar('Account linked successfully!', isSuccess: true);
        } else {
          _showSnackBar('No parent account found with that email or kiosque code',
              isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error checking identity: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isCheckingIdentity = false);
    }
  }

  void _showSnackBar(String message,
      {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle
                  : isError
                      ? Icons.error
                      : Icons.info,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess
            ? const Color(0xff059669)
            : isError
                ? const Color(0xffDC2626)
                : const Color(0xff3B82F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _unlinkParent() {
    setState(() {
      _linkedParentData = null;
      _guardianId = null;
      _parentNameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _parentIdentityController.clear();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _cardController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _parentNameController.dispose();
    _cityController.dispose();
    _whatsAppNumberController.dispose();
    _studentNameController.dispose();
    _studentAgeController.dispose();
    _parentIdentityController.dispose();
    // Dispose additional student controllers
    for (final student in _students) {
      student.dispose();
    }
    super.dispose();
  }

  void _nextStep() {
    print('🔍 _nextStep called - current step: $_currentStep');

    // Validate current step before proceeding
    if (!_validateCurrentStep()) {
      print('❌ Step validation failed');
      return;
    }

    print('✅ Step validation passed, proceeding to next step');

    if (_currentStep < 3) {
      _cardController.reverse().then((_) {
        _pageController.animateToPage(
          _currentStep + 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
        setState(() => _currentStep++);
        _cardController.forward();
      });
    } else {
      _submitForm();
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Contact/Role
        return _validateContactStep();
      case 1: // Student Info
        return _validateStudentInfoStep();
      case 2: // Program
        return _validateProgramStep();
      case 3: // Schedule
        return _validateScheduleStep();
      default:
        return true;
    }
  }

  bool _validateStudentInfoStep() {
    // First student name is always required
    final studentName = _studentNameController.text.trim();
    if (studentName.isEmpty) {
      _showSnackBar('Please enter the student name', isError: true);
      return false;
    }
    
    // Validate additional students (for Parent/Guardian role)
    final isParentOrGuardian = _role == 'Parent' || _role == 'Guardian';
    if (isParentOrGuardian) {
      for (int i = 0; i < _students.length; i++) {
        final student = _students[i];
        if (student.nameController.text.trim().isEmpty) {
          _showSnackBar('Please enter name for Student ${i + 2}', isError: true);
          return false;
        }
      }
    }

    return true;
  }

  bool _validateProgramStep() {
    // Validate first student's program
    if (_selectedSubject == null || _selectedSubject!.isEmpty) {
      _showSnackBar('Please select a program for Student 1', isError: true);
      return false;
    }
    if (_selectedSubject == 'AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)' &&
        (_selectedAfricanLanguage == null || _selectedAfricanLanguage!.isEmpty)) {
      _showSnackBar('Please select a specific language for Student 1', isError: true);
      return false;
    }
    if (_selectedLevel == null || _selectedLevel!.isEmpty) {
      _showSnackBar('Please select a level for Student 1', isError: true);
      return false;
    }
    
    // Validate additional students' programs (for Parent/Guardian with multiple students)
    final isParentOrGuardian = _role == 'Parent' || _role == 'Guardian';
    if (isParentOrGuardian && _students.isNotEmpty) {
      for (int i = 0; i < _students.length; i++) {
        final student = _students[i];
        final studentNum = i + 2;
        
        if (student.subject == null || student.subject!.isEmpty) {
          _showSnackBar('Please select a program for Student $studentNum', isError: true);
          return false;
        }
        if (student.subject == 'AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)' &&
            (student.specificLanguage == null || student.specificLanguage!.isEmpty)) {
          _showSnackBar('Please select a specific language for Student $studentNum', isError: true);
          return false;
        }
        if (student.level == null || student.level!.isEmpty) {
          _showSnackBar('Please select a level for Student $studentNum', isError: true);
          return false;
        }
      }
    }
    
    return true;
  }

  bool _validateScheduleStep() {
    if (_selectedDays.isEmpty) {
      _showSnackBar('Please select at least one preferred day', isError: true);
      return false;
    }

    if (_selectedTimeSlots.isEmpty) {
      _showSnackBar('Please select at least one preferred time slot', isError: true);
      return false;
    }

    return true;
  }

  bool _validateContactStep() {
    // Role is required
    if (_role == null || _role!.isEmpty) {
      _showSnackBar('Please select who you are (Student, Parent, or Guardian)', isError: true);
      return false;
    }

    // Validate form fields using FormKey
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill in all required fields', isError: true);
      return false;
    }

    // For Parent/Guardian role, parent name is required (unless linked)
    final isParentOrGuardian = _role == 'Parent' || _role == 'Guardian';
    if (isParentOrGuardian) {
      final hasLinkedParent = _linkedParentData != null;
      final hasParentName = _parentNameController.text.trim().isNotEmpty;

      if (!hasLinkedParent && !hasParentName) {
        _showSnackBar('Please either link to an existing parent account or enter parent name', isError: true);
        return false;
      }
    }

    return true;
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _cardController.reverse().then((_) {
        _pageController.animateToPage(
          _currentStep - 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
        setState(() => _currentStep--);
        _cardController.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Column(
        children: [
          const ModernHeader(),
          Expanded(
            child: isDesktop
                ? Row(
                    children: [
                      Expanded(flex: 4, child: _buildLeftSection()),
                      Expanded(flex: 6, child: _buildRightSection(isMobile)),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(
                            height: isMobile ? 200 : 280,
                            child: _buildLeftSection()),
                        _buildRightSection(isMobile),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSection() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff0F172A),
            Color(0xff1E293B),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Animated background circles
          Positioned(
            top: -100,
            right: -100,
            child: FadeInSlide(
              delay: 0.3,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xff3B82F6).withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: FadeInSlide(
              delay: 0.5,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xff10B981).withOpacity(0.1),
                      Colors.transparent,
                    ],
                ),
              ),
            ),
          ),
          ),
          Padding(
            padding: const EdgeInsets.all(40.0),
            // FIX START: Wrapped in Center -> SingleChildScrollView
            child: Center(
              child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min, // Ensures it doesn't expand unnecessarily
              children: [
                FadeInSlide(
                  delay: 0.1,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xff3B82F6).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(100),
                        ),
                  child: Text(
                          AppLocalizations.of(context)!.classSignUp,
                    style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xff60A5FA),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeInSlide(
                      delay: 0.15,
                      child: Text(
                        AppLocalizations.of(context)!.classSignUp2,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 38,
                      fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeInSlide(
                  delay: 0.2,
                  child: Text(
                        AppLocalizations.of(context)!.qualityIslamicEducationFromAnywhereIn,
                    style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xff94A3B8),
                          height: 1.6,
                    ),
                  ),
                ),
                    const SizedBox(height: 48),
                    // Steps Indicator
                    _buildStepIndicator(),
                  ],
                ),
              ),
            ),
            // FIX END
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = [
      {'title': 'Contact', 'icon': Icons.mail_outline},
      {'title': 'Student', 'icon': Icons.person_outline},
      {'title': 'Program', 'icon': Icons.auto_stories_outlined},
      {'title': 'Schedule', 'icon': Icons.calendar_today_outlined},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        FadeInSlide(
          delay: 0.25,
                      child: Container(
            height: 4,
            margin: const EdgeInsets.only(bottom: 32),
                        decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      width: constraints.maxWidth *
                          ((_currentStep + 1) / steps.length),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff3B82F6), Color(0xff60A5FA)],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                              );
                            },
                          ),
                        ),
                      ),
        ...List.generate(steps.length, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          final step = steps[index];

          return FadeInSlide(
            delay: 0.3 + (index * 0.08),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xff10B981)
                          : isCurrent
                              ? const Color(0xff3B82F6)
                              : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xff3B82F6)
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: const Color(0xff3B82F6).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, size: 20, color: Colors.white)
                          : Icon(
                              step['icon'] as IconData,
                              size: 20,
                              color: isCurrent
                                  ? Colors.white
                                  : const Color(0xff64748B),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step ${index + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xff64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step['title'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                            color: isCurrent
                                ? Colors.white
                                : const Color(0xff94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
              ),
      ),
          );
        }),
      ],
    );
  }

  Widget _buildRightSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 48),
          child: Form(
            key: _formKey,
            child: Column(
          mainAxisSize: MainAxisSize.min,
              children: [
            // Only show parent lookup on Contact step (Step 0)
            if (_currentStep == 0) _buildParentLookup(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep0Contact(),
                  _buildStep1StudentInfo(),
                  _buildStep2Program(),
                  _buildStep3Schedule(),
                ],
              ),
            ),
            _buildNavigationButtons(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildParentLookup() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _linkedParentData != null
              ? [const Color(0xffECFDF5), const Color(0xffD1FAE5)]
              : [const Color(0xffEFF6FF), const Color(0xffDBEAFE)],
        ),
                      borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _linkedParentData != null
              ? const Color(0xff10B981).withOpacity(0.3)
              : const Color(0xff3B82F6).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (_linkedParentData != null
                    ? const Color(0xff10B981)
                    : const Color(0xff3B82F6))
                .withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _linkedParentData != null
                      ? const Color(0xff10B981).withOpacity(0.15)
                      : const Color(0xff3B82F6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _linkedParentData != null
                      ? Icons.check_circle_rounded
                      : Icons.link_rounded,
                  color: _linkedParentData != null
                      ? const Color(0xff059669)
                      : const Color(0xff3B82F6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _linkedParentData != null
                          ? 'Account Linked'
                          : 'Already have a child enrolled?',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _linkedParentData != null
                            ? const Color(0xff047857)
                            : const Color(0xff1E40AF),
                      ),
                    ),
                    if (_linkedParentData == null) ...[
                      const SizedBox(height: 2),
                      Text(
                        AppLocalizations.of(context)!.linkYourAccountToManageAll,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xff64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_linkedParentData != null)
            Row(
              children: [
                Expanded(
                    child: Container(
                    padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              const Color(0xff10B981).withOpacity(0.15),
                          child: Text(
                            (_linkedParentData!['firstName'] as String?)
                                    ?.substring(0, 1)
                                    .toUpperCase() ??
                                'P',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff059669),
                            ),
                          ),
                        ),
                          const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                                'Welcome back, ${_linkedParentData!['firstName']}!',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: const Color(0xff065F46),
                                ),
                              ),
                              Text(
                                AppLocalizations.of(context)!.newStudentWillBeLinkedTo,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xff059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                          ),
                          const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _unlinkParent,
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(AppLocalizations.of(context)!.unlink),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xffDC2626),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                          Expanded(
                  child: TextField(
                    controller: _parentIdentityController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.enterYourEmailOrKiosqueCode,
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xff94A3B8),
                        fontSize: 14,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Color(0xff94A3B8)),
                    ),
                    onSubmitted: (_) => _checkParentIdentity(),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: const Color(0xff3B82F6),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _isCheckingIdentity ? null : _checkParentIdentity,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: _isCheckingIdentity
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              children: [
                                const Icon(Icons.link_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context)!.link,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              flex: isMobile ? 1 : 0,
              child: OutlinedButton.icon(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(isMobile ? '' : 'Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff64748B),
                  side: const BorderSide(color: Color(0xffE2E8F0)),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 28,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            flex: isMobile ? 2 : 0,
            child: Container(
              constraints: BoxConstraints(
                minWidth: isMobile ? 0 : 200,
              ),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: const Color(0xff3B82F6).withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentStep == 3 ? 'Submit Enrollment' : 'Continue',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentStep == 3
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
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

  bool get _isAdult {
    // Check if level is University (adult) OR Age >= 18
    // Note: 'Student' role does NOT automatically mean adult.
    // Updated to use new level system while maintaining backward compatibility
    if (_selectedLevel == 'University' ||
        _selectedGrade == 'University' ||
        _selectedGrade == 'Adult Professionals') return true;

    final age = int.tryParse(_studentAgeController.text) ?? 0;
    if (age >= 18) return true;

    return false;
  }

  // --- Steps Content ---

  Widget _buildStepCard({required String title, required List<Widget> children}) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: FadeTransition(
        opacity: _cardController,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _cardController,
            curve: Curves.easeOutCubic,
          )),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff0F172A).withOpacity(0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff3B82F6), Color(0xff60A5FA)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 28),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1StudentInfo() {
    final isParentOrGuardian = _role == 'Parent' || _role == 'Guardian';
    
    // For adult students (role == 'Student'), use single student fields
    if (!isParentOrGuardian) {
      return _buildStepCard(
        title: AppLocalizations.of(context)!.yourInformation,
        children: [
          _buildModernTextField(
            'Full Name',
            _studentNameController,
            Icons.person_outline_rounded,
            hint: 'Enter your full name',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildModernTextField(
                  'Age',
                  _studentAgeController,
                  Icons.cake_outlined,
                  isNumber: true,
                  hint: 'Years',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildModernDropdown(
                  'Gender',
                  _genders,
                  _gender,
                  (v) => setState(() => _gender = v),
                  Icons.people_outline_rounded,
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    // For Parent/Guardian: show multi-student support
    return _buildStepCard(
      title: AppLocalizations.of(context)!.studentSInformation,
      children: [
        // Info banner for multi-student
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xff3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xff3B82F6).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xff3B82F6), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.youCanAddMultipleStudentsIn,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xff3B82F6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // First student (always visible, uses main controllers)
        _buildStudentCard(
          index: 0,
          nameController: _studentNameController,
          ageController: _studentAgeController,
          gender: _gender,
          onGenderChanged: (v) => setState(() => _gender = v),
          isRemovable: false,
        ),
        
        // Additional students from _students list
        ...List.generate(_students.length, (index) {
          final student = _students[index];
          return Column(
            children: [
              const SizedBox(height: 16),
              _buildStudentCard(
                index: index + 1,
                nameController: student.nameController,
                ageController: student.ageController,
                gender: student.gender,
                onGenderChanged: (v) => setState(() => student.gender = v),
                isRemovable: true,
                onRemove: () => _removeStudent(index),
              ),
            ],
          );
        }),
        
        const SizedBox(height: 20),
        
        // Add Student Button
        OutlinedButton.icon(
          onPressed: _addStudent,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(
            AppLocalizations.of(context)!.addAnotherStudent,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xff3B82F6),
            side: const BorderSide(color: Color(0xff3B82F6), width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStudentCard({
    required int index,
    required TextEditingController nameController,
    required TextEditingController ageController,
    required String? gender,
    required Function(String?) onGenderChanged,
    required bool isRemovable,
    VoidCallback? onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Student ${index + 1}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
              ),
              if (isRemovable)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: const Color(0xffEF4444),
                  tooltip: AppLocalizations.of(context)!.removeStudent,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildModernTextField(
            'Student Name',
            nameController,
            Icons.person_outline_rounded,
            hint: 'Enter full name',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildModernTextField(
                  'Age',
                  ageController,
                  Icons.cake_outlined,
                  isNumber: true,
                  hint: 'Years',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildModernDropdown(
                  'Gender',
                  _genders,
                  gender,
                  onGenderChanged,
                  Icons.people_outline_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  void _addStudent() {
    setState(() {
      _students.add(_StudentInput());
    });
  }
  
  void _removeStudent(int index) {
    setState(() {
      _students[index].dispose();
      _students.removeAt(index);
    });
  }
  
  // Helper method to get levels based on subject
  List<String> _getLevelsForSubject(String? subject) {
    if (subject == 'After School Tutoring (Math, Science, Physics, etc...)') {
      return ['Elementary', 'Middle School', 'High School', 'University'];
    }
    return ['Beginner', 'Intermediate', 'Advanced'];
  }
  
  Widget _buildProgramFields({
    required String? subject,
    required Function(String?) onSubjectChanged,
    required String? specificLanguage,
    required Function(String?) onSpecificLanguageChanged,
    required String? level,
    required Function(String?) onLevelChanged,
    required String? classType,
    required Function(String?) onClassTypeChanged,
  }) {
    return Column(
      children: [
        _buildModernDropdown(
          'Select Program',
          widget.isLanguageSelection
              ? ['English', 'French', 'Adlam', 'AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)']
              : _subjects,
          subject,
          onSubjectChanged,
          Icons.auto_stories_outlined,
        ),
        if (subject == 'AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)') ...[
          const SizedBox(height: 16),
          _buildModernDropdown(
            'Specific Language',
            _otherAfricanLanguages,
            specificLanguage,
            onSpecificLanguageChanged,
            Icons.language_rounded,
          ),
        ],
        if (subject != null) ...[
          const SizedBox(height: 16),
          _buildModernDropdown(
            subject == 'After School Tutoring (Math, Science, Physics, etc...)' ? 'Grade Level' : 'Proficiency Level',
            _getLevelsForSubject(subject),
            level,
            onLevelChanged,
            Icons.school_outlined,
          ),
        ],
        const SizedBox(height: 16),
        _buildModernDropdown(
          'Class Type',
          _classTypes,
          classType,
          onClassTypeChanged,
          Icons.groups_outlined,
        ),
      ],
    );
  }
  
  Widget _buildStudentProgramCard({
    required int studentIndex,
    required String studentName,
    required String? subject,
    required Function(String?) onSubjectChanged,
    required String? specificLanguage,
    required Function(String?) onSpecificLanguageChanged,
    required String? level,
    required Function(String?) onLevelChanged,
    required String? classType,
    required Function(String?) onClassTypeChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff3B82F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${studentIndex + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  studentName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff374151),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgramFields(
            subject: subject,
            onSubjectChanged: onSubjectChanged,
            specificLanguage: specificLanguage,
            onSpecificLanguageChanged: onSpecificLanguageChanged,
            level: level,
            onLevelChanged: onLevelChanged,
            classType: classType,
            onClassTypeChanged: onClassTypeChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Program() {
    final isParentOrGuardian = _role == 'Parent' || _role == 'Guardian';
    final totalStudents = isParentOrGuardian ? 1 + _students.length : 1;
    
    // For single student (adult) or first student
    if (!isParentOrGuardian || totalStudents == 1) {
      return _buildStepCard(
        title: AppLocalizations.of(context)!.programDetails,
        children: [
          _buildProgramFields(
            subject: _selectedSubject,
            onSubjectChanged: (v) {
              setState(() {
                _selectedSubject = v;
                if (v != 'AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)') _selectedAfricanLanguage = null;
                _selectedLevel = null;
              });
            },
            specificLanguage: _selectedAfricanLanguage,
            onSpecificLanguageChanged: (v) => setState(() => _selectedAfricanLanguage = v),
            level: _selectedLevel,
            onLevelChanged: (v) => setState(() => _selectedLevel = v),
            classType: _classType,
            onClassTypeChanged: (v) => setState(() => _classType = v),
          ),
        ],
      );
    }
    
    // For Parent/Guardian with multiple students - show program for each
    return _buildStepCard(
      title: AppLocalizations.of(context)!.programDetailsForEachStudent,
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xff10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.school_outlined, color: Color(0xff10B981), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.selectAProgramForEachStudent,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff10B981), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // First student program
        _buildStudentProgramCard(
          studentIndex: 0,
          studentName: _studentNameController.text.isNotEmpty ? _studentNameController.text : AppLocalizations.of(context)!.student1,
          subject: _selectedSubject,
          onSubjectChanged: (v) {
            setState(() {
              _selectedSubject = v;
              if (v != 'AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)') _selectedAfricanLanguage = null;
              _selectedLevel = null;
            });
          },
          specificLanguage: _selectedAfricanLanguage,
          onSpecificLanguageChanged: (v) => setState(() => _selectedAfricanLanguage = v),
          level: _selectedLevel,
          onLevelChanged: (v) => setState(() => _selectedLevel = v),
          classType: _classType,
          onClassTypeChanged: (v) => setState(() => _classType = v),
        ),
        
        // Additional students' programs
        ...List.generate(_students.length, (index) {
          final student = _students[index];
          final studentName = student.nameController.text.isNotEmpty 
              ? student.nameController.text 
              : 'Student ${index + 2}';
          return Column(
            children: [
              const SizedBox(height: 16),
              _buildStudentProgramCard(
                studentIndex: index + 1,
                studentName: studentName,
                subject: student.subject,
                onSubjectChanged: (v) {
                  setState(() {
                    student.subject = v;
                    if (v != 'AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)') student.specificLanguage = null;
                    student.level = null;
                  });
                },
                specificLanguage: student.specificLanguage,
                onSpecificLanguageChanged: (v) => setState(() => student.specificLanguage = v),
                level: student.level,
                onLevelChanged: (v) => setState(() => student.level = v),
                classType: student.classType,
                onClassTypeChanged: (v) => setState(() => student.classType = v),
              ),
            ],
          );
        }),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildModernDropdown(
                'Preferred Language',
                _languages,
                _preferredLanguage,
                (v) => setState(() => _preferredLanguage = v),
                Icons.translate_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3Schedule() {
    return _buildStepCard(
      title: AppLocalizations.of(context)!.schedulePreferences,
      children: [
        // Timezone indicator
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xffEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffBFDBFE), width: 1),
          ),
                  child: Row(
                    children: [
              const Icon(Icons.public_rounded, size: 18, color: Color(0xff3B82F6)),
              const SizedBox(width: 12),
                      Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.yourTimezone,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff1E40AF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _ianaTimeZone,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                            color: const Color(0xff3B82F6),
                          ),
                    ),
                  ],
                        ),
                      ),
                    ],
                  ),
                ),
        Row(
          children: [
            Expanded(
              child: _buildModernDropdown(
                'Duration',
                _sessionDurations,
                _sessionDuration,
                (v) => setState(() {
                  _sessionDuration = v;
                  _selectedTimeSlots
                      .removeWhere((slot) => !_filteredTimeSlots.contains(slot));
                }),
                Icons.timer_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernDropdown(
                'Time of Day',
                _timeOfDayOptions,
                _timeOfDayPreference,
                (v) => setState(() {
                  _timeOfDayPreference = v;
                  _selectedTimeSlots
                      .removeWhere((slot) => !_filteredTimeSlots.contains(slot));
                }),
                Icons.wb_sunny_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildModernLabel('Preferred Days'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _days.map((day) {
            final isSelected = _selectedDays.contains(day);
            return InkWell(
              onTap: () => setState(
                  () => isSelected ? _selectedDays.remove(day) : _selectedDays.add(day)),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xff3B82F6), Color(0xff2563EB)],
                        )
                      : null,
                  color: isSelected ? null : const Color(0xffF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xff3B82F6).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                          ),
                          child: Text(
                  day,
                            style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                              fontSize: 14,
                    color: isSelected ? Colors.white : const Color(0xff64748B),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _buildModernLabel('Preferred Time Slots'),
        const SizedBox(height: 10),
        if (_filteredTimeSlots.isNotEmpty)
          Wrap(
            spacing: 10,
            runSpacing: 10,
                          children: _filteredTimeSlots.map((slot) {
                      final isSelected = _selectedTimeSlots.contains(slot);
              return InkWell(
                onTap: () => setState(() => isSelected
                    ? _selectedTimeSlots.remove(slot)
                    : _selectedTimeSlots.add(slot)),
                          borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xff10B981), Color(0xff059669)],
                          )
                        : null,
                    color: isSelected ? null : const Color(0xffF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xff10B981).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    slot,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: isSelected ? Colors.white : const Color(0xff64748B),
                    ),
                          ),
                        ),
                      );
                    }).toList(),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xffFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffFCD34D).withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xffD97706), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.selectDurationAndTimeOfDay,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xff92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStep0Contact() {
    // Determine if we should show parent fields based on role
    final isParentOrGuardian = _role == 'Parent' || _role == 'Guardian';
    
    return _buildStepCard(
      title: AppLocalizations.of(context)!.contactInformation,
      children: [
        // Role selection first
        _buildModernDropdown(
          'I am the',
          _roles,
          _role,
          (v) => setState(() => _role = v),
          Icons.account_circle_outlined,
        ),
        const SizedBox(height: 20),
        // Parent info first when role is Parent/Guardian
        if (isParentOrGuardian) ...[
          _buildModernTextField(
            'Parent/Guardian Name',
            _parentNameController,
            Icons.person_outline_rounded,
            hint: 'Enter full name',
          ),
          const SizedBox(height: 20),
        ],
        _buildModernTextField(
          _role == 'Student' ? 'Your Email Address' : 'Email Address',
          _emailController,
          Icons.email_outlined,
          hint: 'your@email.com',
          isEnabled: _linkedParentData == null,
        ),
        const SizedBox(height: 20),
        _buildModernLabel('WhatsApp Number (Optional)'),
        const SizedBox(height: 8),
        IntlPhoneField(
          controller: _whatsAppNumberController,
          key: ValueKey('wa_$_initialCountryCode'),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.whatsappNumber,
            hintStyle: GoogleFonts.inter(color: const Color(0xff94A3B8)),
            filled: true,
            fillColor: const Color(0xffF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xff3B82F6), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          initialCountryCode: _initialCountryCode,
          onChanged: (phone) => _whatsAppNumber = phone.completeNumber,
        ),
        const SizedBox(height: 20),
        _buildModernLabel('Phone Number'),
        const SizedBox(height: 8),
        IntlPhoneField(
          controller: _phoneController,
          key: ValueKey(_initialCountryCode), // Rebuild when country changes
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.userPhone,
            hintStyle: GoogleFonts.inter(color: const Color(0xff94A3B8)),
            filled: true,
            fillColor: const Color(0xffF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xff3B82F6), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          initialCountryCode: _initialCountryCode,
          onChanged: (phone) => _phoneNumber = phone.completeNumber,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModernLabel('Country'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      showCountryPicker(
                        context: context,
                        showPhoneCode: false,
                        countryListTheme: CountryListThemeData(
                            borderRadius: BorderRadius.circular(16),
                          inputDecoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.searchCountry,
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        onSelect: (Country country) {
                          setState(() {
                            _selectedCountry = country;
                            _initialCountryCode = country.countryCode; // Sync phone field
                          });
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xffF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xffE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _selectedCountry?.flagEmoji ?? '🇺🇸',
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedCountry?.name ?? 'Select Country',
                                style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff374151),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xff94A3B8),
                          ),
                        ],
                    ),
                  ),
                ),
              ],
            ),
          ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernTextField(
                'City',
                _cityController,
                Icons.location_city_outlined,
                hint: 'City',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Modern Helpers ---

  Widget _buildModernLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: const Color(0xff374151),
      ),
    );
  }

  Widget _buildModernTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = false,
    bool isEnabled = true,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: isEnabled,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: const Color(0xff0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint ?? label,
            hintStyle: GoogleFonts.inter(
              color: const Color(0xff94A3B8),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(icon, color: const Color(0xff94A3B8), size: 20),
            filled: true,
            fillColor:
                isEnabled ? const Color(0xffF8FAFC) : const Color(0xffF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xff3B82F6), width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: (value) =>
              value == null || value.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildModernDropdown(
    String label,
    List<String> items,
    String? value,
    Function(String?) onChanged,
    IconData icon, {
    bool isRequired = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModernLabel(label),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          validator: isRequired 
              ? (v) => v == null || v.isEmpty ? 'Required' : null 
              : null,
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff374151),
                      ),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xff94A3B8)),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.selectLabel,
            hintStyle: GoogleFonts.inter(
              color: const Color(0xff94A3B8),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(icon, color: const Color(0xff94A3B8), size: 20),
            filled: true,
            fillColor: const Color(0xffF8FAFC),
      border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xff3B82F6), width: 2),
      ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      try {
        final isAdultStudent = _isAdult;
        final isParentOrGuardian = _role == 'Parent' || _role == 'Guardian';
        
        // For Parent/Guardian with multiple students: create individual enrollments
        if (isParentOrGuardian && _students.isNotEmpty) {
          // Build list of all students with their individual program details
          final allStudents = <StudentInfo>[
            // First student with main form fields
            StudentInfo(
              name: _studentNameController.text.trim(),
              age: _studentAgeController.text.trim(),
              gender: _gender,
              subject: _selectedSubject,
              specificLanguage: _selectedSubject == 'AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)'
                  ? _selectedAfricanLanguage
                  : null,
              level: _selectedLevel,
              classType: _classType,
              sessionDuration: _sessionDuration,
              timeOfDayPreference: _timeOfDayPreference,
              preferredDays: _selectedDays,
              preferredTimeSlots: _selectedTimeSlots,
            ),
            // Additional students with their individual program details
            ..._students.map((s) => StudentInfo(
              name: s.nameController.text.trim(),
              age: s.ageController.text.trim(),
              gender: s.gender,
              subject: s.subject ?? _selectedSubject,
              specificLanguage: s.subject == 'AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)'
                  ? s.specificLanguage
                  : null,
              level: s.level ?? _selectedLevel,
              classType: s.classType ?? _classType,
              sessionDuration: s.sessionDuration ?? _sessionDuration,
              timeOfDayPreference: s.timeOfDayPreference ?? _timeOfDayPreference,
              preferredDays: s.selectedDays.isNotEmpty ? s.selectedDays : _selectedDays,
              preferredTimeSlots: s.selectedTimeSlots.isNotEmpty ? s.selectedTimeSlots : _selectedTimeSlots,
            )),
          ];
          
          // Submit individual enrollments for each student (all linked to same parent)
          await EnrollmentService().submitMultipleEnrollments(
            parentName: _parentNameController.text.trim(),
            email: _emailController.text.trim(),
            phoneNumber: _phoneNumber,
            countryCode: _selectedCountry?.countryCode ?? 'US',
            countryName: _selectedCountry?.name ?? 'United States',
            city: _cityController.text.trim(),
            whatsAppNumber: _whatsAppNumber,
            timeZone: _ianaTimeZone,
            preferredLanguage: _preferredLanguage ?? 'English',
            role: _role ?? 'Parent',
            guardianId: _guardianId,
            students: allStudents,
          );
        } else {
          // Single student enrollment (adult student or parent with one child)
          final request = EnrollmentRequest(
            subject: _selectedSubject,
            specificLanguage: _selectedSubject == 'AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)'
                ? _selectedAfricanLanguage
                : null,
            gradeLevel: _selectedLevel ?? _selectedGrade ?? '',
            email: _emailController.text.trim(),
            phoneNumber: _phoneNumber,
            countryCode: _selectedCountry?.countryCode ?? 'US',
            countryName: _selectedCountry?.name ?? 'United States',
            preferredDays: _selectedDays,
            preferredTimeSlots: _selectedTimeSlots,
            submittedAt: DateTime.now(),
            timeZone: _ianaTimeZone,
            role: isAdultStudent ? 'Student' : (_role ?? 'Parent'),
            preferredLanguage: _preferredLanguage,
            parentName: isAdultStudent
                ? null
                : _parentNameController.text.trim(),
            city: _cityController.text.trim(),
            whatsAppNumber: _whatsAppNumber,
            studentName: _studentNameController.text.trim(),
            studentAge: _studentAgeController.text.trim(),
            gender: _gender,
            knowsZoom: null,
            classType: _classType,
            sessionDuration: _sessionDuration,
            timeOfDayPreference: _timeOfDayPreference,
            guardianId: _guardianId,
            isAdult: isAdultStudent,
          );

          await EnrollmentService().submitEnrollment(request);
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const EnrollmentSuccessPage(),
              transitionDuration: const Duration(milliseconds: 400),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error: $e', isError: true);
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }
}
