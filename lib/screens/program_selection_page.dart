import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:country_picker/country_picker.dart';
import '../widgets/modern_header.dart';
import '../shared/widgets/fade_in_slide.dart';
import '../core/models/enrollment_request.dart';
import '../core/services/enrollment_service.dart';
import 'enrollment_success_page.dart';

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

class _ProgramSelectionPageState extends State<ProgramSelectionPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _whatsAppNumberController = TextEditingController();
  final _studentNameController = TextEditingController();
  final _studentAgeController = TextEditingController();
  
  // State variables
  String? _selectedSubject;
  String? _selectedGrade;
  String? _selectedAfricanLanguage;
  Country? _selectedCountry;
  String _phoneNumber = '';
  bool _isSubmitting = false;
  
  // Enhanced form fields
  String? _role; // 'student', 'parent', etc.
  String? _preferredLanguage;
  String _whatsAppNumber = '';
  String? _gender;
  bool? _knowsZoom;
  String? _classType;
  String? _sessionDuration;
  String? _timeOfDayPreference;
  
  // Available options
  final List<String> _subjects = [
    'Islamic Studies',
    'English',
    'French',
    'Maths',
    'Programming',
    'Quran',
    'Arabic',
    'Science'
  ];

  // Other African languages list (excluding English, French, Adlam)
  final List<String> _otherAfricanLanguages = [
    'Swahili',
    'Yoruba',
    'Amharic',
    'Wolof',
    'Hausa',
    'Mandinka',
    'Fulani',
    'Igbo',
    'Zulu',
    'Xhosa',
  ];

  final List<String> _grades = [
    'Elementary school',
    'Middle school',
    'High school / Sixth form',
    'University',
    'Adult Professionals'
  ];

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _selectedDays = [];
  
  // Time ranges for different times of day (standard definitions)
  static const Map<String, _TimeRange> _timeRanges = {
    'Morning': _TimeRange(startHour: 6, startMinute: 0, endHour: 12, endMinute: 0),      // 6 AM - 12 PM
    'Afternoon': _TimeRange(startHour: 12, startMinute: 0, endHour: 17, endMinute: 0),  // 12 PM - 5 PM
    'Evening': _TimeRange(startHour: 17, startMinute: 0, endHour: 21, endMinute: 0),      // 5 PM - 9 PM
  };
  
  final List<String> _selectedTimeSlots = [];
  
  // Generate dynamic time slots based on time of day preference and session duration
  List<String> get _filteredTimeSlots {
    // If no time preference or duration selected, return empty or default slots
    if (_timeOfDayPreference == null || _timeOfDayPreference == 'Flexible' || _sessionDuration == null) {
      // Return default broad time slots if no specific preference
      if (_timeOfDayPreference == null || _timeOfDayPreference == 'Flexible') {
        return ['8 AM - 12 PM', '12 PM - 4 PM', '4 PM - 8 PM', '8 PM - 12 AM'];
      }
      return [];
    }
    
    // Get time range for selected time of day
    final timeRange = _timeRanges[_timeOfDayPreference];
    if (timeRange == null) return [];
    
    // Parse duration to minutes
    final durationMinutes = _parseDurationToMinutes(_sessionDuration!);
    if (durationMinutes == null) return [];
    
    // Generate time slots with the specified duration interval
    return _generateTimeSlots(
      startHour: timeRange.startHour,
      startMinute: timeRange.startMinute,
      endHour: timeRange.endHour,
      endMinute: timeRange.endMinute,
      durationMinutes: durationMinutes,
    );
  }
  
  /// Parse duration string to minutes
  int? _parseDurationToMinutes(String duration) {
    if (duration.contains('30')) return 30;
    if (duration.contains('45')) return 45;
    if (duration.contains('60')) return 60;
    if (duration.contains('90')) return 90;
    return null;
  }
  
  /// Generate time slots with specified duration intervals
  List<String> _generateTimeSlots({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required int durationMinutes,
  }) {
    final slots = <String>[];
    
    // Convert start and end times to total minutes
    final startTotalMinutes = startHour * 60 + startMinute;
    final endTotalMinutes = endHour * 60 + endMinute;
    
    // Generate slots with the specified duration interval
    int currentMinutes = startTotalMinutes;
    while (currentMinutes + durationMinutes <= endTotalMinutes) {
      final startTime = _formatTimeFromMinutes(currentMinutes);
      final endTime = _formatTimeFromMinutes(currentMinutes + durationMinutes);
      slots.add('$startTime - $endTime');
      currentMinutes += durationMinutes;
    }
    
    return slots;
  }
  
  /// Format minutes to 12-hour time format (e.g., "5:00 PM", "6:30 AM")
  String _formatTimeFromMinutes(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    
    final hour12 = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours);
    final period = hours < 12 ? 'AM' : 'PM';
    final minuteStr = minutes.toString().padLeft(2, '0');
    
    return '$hour12:${minuteStr} $period';
  }
  
  // Enhanced form options
  final List<String> _roles = ['Student', 'Parent', 'Guardian'];
  final List<String> _languages = ['English', 'French', 'Arabic', 'Other'];
  final List<String> _genders = ['Male', 'Female', 'Prefer not to say'];
  final List<String> _classTypes = ['One-on-One', 'Group', 'Both'];
  final List<String> _sessionDurations = ['30 minutes', '45 minutes', '60 minutes', '90 minutes'];
  final List<String> _timeOfDayOptions = ['Morning', 'Afternoon', 'Evening', 'Flexible'];

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.initialSubject;
    _selectedAfricanLanguage = widget.initialAfricanLanguage;
    // Default to USA if not selected
    _selectedCountry = Country.parse('US');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _parentNameController.dispose();
    _cityController.dispose();
    _whatsAppNumberController.dispose();
    _studentNameController.dispose();
    _studentAgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const ModernHeader(),
          Expanded(
            child: isDesktop
                ? Row(
                    children: [
                      // Left Section (Promotional)
                      Expanded(
                        flex: 4,
                        child: _buildLeftSection(),
                      ),
                      // Right Section (Form)
                      Expanded(
                        flex: 6,
                        child: _buildRightSection(),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 300,
                          child: _buildLeftSection(),
                        ),
                        _buildRightSection(),
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
          colors: [Color(0xffF0F9FF), Color(0xffE0F2FE)],
        ),
      ),
      child: Stack(
        children: [
          // Background decoration (Soft animated circles)
          Positioned(
            top: -50,
            left: -50,
            child: FadeInSlide(
              delay: 0.5,
              beginOffset: const Offset(-0.2, -0.2),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: const Color(0xff3B82F6).withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeInSlide(
                  delay: 0.1,
                  child: Text(
                    'Start Your Journey',
                    style: GoogleFonts.inter(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xff111827),
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeInSlide(
                  delay: 0.2,
                  child: Text(
                    'Try for free!',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff3B82F6),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: FadeInSlide(
                    delay: 0.3,
                    beginOffset: const Offset(0, 0.1),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xff3B82F6).withOpacity(0.2),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/background_images/smiling_teacher.jpg', // Using existing asset as placeholder
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.white,
                                child: const Center(child: Icon(Icons.person, size: 100, color: Color(0xff3B82F6))),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeInSlide(
                  delay: 0.2,
                  child: Text(
                    'Book Your Session',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff111827),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.3,
                  child: Text(
                    'Fill out the form below to get started with your personalized learning plan.',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Subject Selector
                FadeInSlide(delay: 0.4, child: _buildLabel('Which subject do you want to learn?')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.4,
                  child: DropdownButtonFormField<String>(
                    value: _selectedSubject,
                    decoration: _inputDecoration('Select a subject', Icons.book_rounded),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    borderRadius: BorderRadius.circular(16),
                    items: (widget.isLanguageSelection 
                      ? ['English', 'French', 'Adlam', 'African Languages (Other)']
                      : _subjects
                    ).map((subject) {
                      return DropdownMenuItem(
                        value: subject,
                        child: Text(subject, style: GoogleFonts.inter()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSubject = value;
                        // Clear African language selection if not "African Languages (Other)"
                        if (value != 'African Languages (Other)') {
                          _selectedAfricanLanguage = null;
                        }
                      });
                    },
                    validator: (value) => value == null ? 'Please select a subject' : null,
                  ),
                ),
                const SizedBox(height: 24),

                // Other African Languages Selector (shown when "African Languages (Other)" is selected)
                if (widget.isLanguageSelection && _selectedSubject == 'African Languages (Other)') ...[
                  FadeInSlide(delay: 0.45, child: _buildLabel('Select an African Language')),
                  const SizedBox(height: 8),
                  FadeInSlide(
                    delay: 0.45,
                    child: DropdownButtonFormField<String?>(
                      value: _selectedAfricanLanguage,
                      decoration: _inputDecoration('Select an African language', Icons.language_rounded),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      borderRadius: BorderRadius.circular(16),
                      items: _otherAfricanLanguages.map((language) {
                        return DropdownMenuItem<String?>(
                          value: language,
                          child: Text(language, style: GoogleFonts.inter()),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedAfricanLanguage = value),
                      validator: (value) => value == null ? 'Please select an African language' : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Grade Level
                FadeInSlide(delay: 0.5, child: _buildLabel('What grade are you in?')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.5,
                  child: DropdownButtonFormField<String>(
                    value: _selectedGrade,
                    decoration: _inputDecoration('Select your grade level', Icons.school_rounded),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    borderRadius: BorderRadius.circular(16),
                    items: _grades.map((grade) {
                      return DropdownMenuItem(
                        value: grade,
                        child: Text(grade, style: GoogleFonts.inter()),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedGrade = value),
                    validator: (value) => value == null ? 'Please select a grade level' : null,
                  ),
                ),
                const SizedBox(height: 24),

                // Country Selector
                FadeInSlide(delay: 0.55, child: _buildLabel('Country of Residence')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.55,
                  child: GestureDetector(
                    onTap: () {
                      showCountryPicker(
                        context: context,
                        countryListTheme: CountryListThemeData(
                          borderRadius: BorderRadius.circular(20),
                          inputDecoration: InputDecoration(
                            hintText: 'Search',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                        onSelect: (Country country) {
                          setState(() {
                            _selectedCountry = country;
                          });
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xffE5E7EB)),
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xffFAFAFA),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.public_rounded, color: Color(0xff9CA3AF)),
                          const SizedBox(width: 12),
                          Text(
                            _selectedCountry?.flagEmoji ?? '🇺🇸',
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedCountry?.name ?? 'United States',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: const Color(0xff111827),
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, color: Color(0xff6B7280)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Email
                FadeInSlide(delay: 0.6, child: _buildLabel('Email Address')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.6,
                  child: TextFormField(
                    controller: _emailController,
                    style: GoogleFonts.inter(),
                    decoration: _inputDecoration('your.email@example.com', Icons.email_rounded),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your email';
                      if (!value.contains('@')) return 'Please enter a valid email';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Phone
                FadeInSlide(delay: 0.65, child: _buildLabel('Phone Number')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.65,
                  child: IntlPhoneField(
                    style: GoogleFonts.inter(),
                    decoration: _inputDecoration('Phone Number', Icons.phone_rounded),
                    initialCountryCode: 'US',
                    onChanged: (phone) {
                      _phoneNumber = phone.completeNumber;
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Role
                FadeInSlide(delay: 0.66, child: _buildLabel('I am a')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.66,
                  child: DropdownButtonFormField<String>(
                    value: _role,
                    decoration: _inputDecoration('Select your role', Icons.person_rounded),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    borderRadius: BorderRadius.circular(16),
                    items: _roles.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(role, style: GoogleFonts.inter()),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _role = value),
                  ),
                ),
                const SizedBox(height: 24),

                // Parent Name (if role is Parent or Guardian)
                if (_role == 'Parent' || _role == 'Guardian') ...[
                  FadeInSlide(delay: 0.67, child: _buildLabel('Parent/Guardian Name')),
                  const SizedBox(height: 8),
                  FadeInSlide(
                    delay: 0.67,
                    child: TextFormField(
                      controller: _parentNameController,
                      style: GoogleFonts.inter(),
                      decoration: _inputDecoration('Enter parent/guardian name', Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Student Name
                FadeInSlide(delay: 0.68, child: _buildLabel('Student Name')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.68,
                  child: TextFormField(
                    controller: _studentNameController,
                    style: GoogleFonts.inter(),
                    decoration: _inputDecoration('Enter student name', Icons.school_rounded),
                  ),
                ),
                const SizedBox(height: 24),

                // Student Age
                FadeInSlide(delay: 0.69, child: _buildLabel('Student Age')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.69,
                  child: TextFormField(
                    controller: _studentAgeController,
                    style: GoogleFonts.inter(),
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Enter student age', Icons.cake_rounded),
                  ),
                ),
                const SizedBox(height: 24),

                // Gender
                FadeInSlide(delay: 0.70, child: _buildLabel('Gender')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.70,
                  child: DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: _inputDecoration('Select gender', Icons.people_rounded),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    borderRadius: BorderRadius.circular(16),
                    items: _genders.map((gender) {
                      return DropdownMenuItem(
                        value: gender,
                        child: Text(gender, style: GoogleFonts.inter()),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                ),
                const SizedBox(height: 24),

                // City
                FadeInSlide(delay: 0.71, child: _buildLabel('City')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.71,
                  child: TextFormField(
                    controller: _cityController,
                    style: GoogleFonts.inter(),
                    decoration: _inputDecoration('Enter your city', Icons.location_city_rounded),
                  ),
                ),
                const SizedBox(height: 24),

                // WhatsApp Number
                FadeInSlide(delay: 0.72, child: _buildLabel('WhatsApp Number (Optional)')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.72,
                  child: IntlPhoneField(
                    controller: _whatsAppNumberController,
                    style: GoogleFonts.inter(),
                    decoration: _inputDecoration('WhatsApp Number', Icons.chat_rounded),
                    initialCountryCode: 'US',
                    onChanged: (phone) {
                      _whatsAppNumber = phone.completeNumber;
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Preferred Language
                FadeInSlide(delay: 0.73, child: _buildLabel('Preferred Language')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.73,
                  child: DropdownButtonFormField<String>(
                    value: _preferredLanguage,
                    decoration: _inputDecoration('Select preferred language', Icons.language_rounded),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    borderRadius: BorderRadius.circular(16),
                    items: _languages.map((language) {
                      return DropdownMenuItem(
                        value: language,
                        child: Text(language, style: GoogleFonts.inter()),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _preferredLanguage = value),
                  ),
                ),
                const SizedBox(height: 24),

                // Knows Zoom
                FadeInSlide(delay: 0.74, child: _buildLabel('Do you know how to use Zoom?')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.74,
                  child: Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          title: Text('Yes', style: GoogleFonts.inter()),
                          value: true,
                          groupValue: _knowsZoom,
                          onChanged: (value) => setState(() => _knowsZoom = value),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          title: Text('No', style: GoogleFonts.inter()),
                          value: false,
                          groupValue: _knowsZoom,
                          onChanged: (value) => setState(() => _knowsZoom = value),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Class Type
                FadeInSlide(delay: 0.75, child: _buildLabel('Preferred Class Type')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.75,
                  child: DropdownButtonFormField<String>(
                    value: _classType,
                    decoration: _inputDecoration('Select class type', Icons.groups_rounded),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    borderRadius: BorderRadius.circular(16),
                    items: _classTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type, style: GoogleFonts.inter()),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _classType = value),
                  ),
                ),
                const SizedBox(height: 24),

                // Session Duration
                FadeInSlide(delay: 0.76, child: _buildLabel('Preferred Session Duration')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.76,
                  child: DropdownButtonFormField<String>(
                    value: _sessionDuration,
                    decoration: _inputDecoration('Select session duration', Icons.timer_rounded),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    borderRadius: BorderRadius.circular(16),
                    items: _sessionDurations.map((duration) {
                      return DropdownMenuItem(
                        value: duration,
                        child: Text(duration, style: GoogleFonts.inter()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _sessionDuration = value;
                        // Clear time slots that are no longer valid
                        _selectedTimeSlots.removeWhere((slot) => !_filteredTimeSlots.contains(slot));
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Time of Day Preference
                FadeInSlide(delay: 0.77, child: _buildLabel('Time of Day Preference')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.77,
                  child: DropdownButtonFormField<String>(
                    value: _timeOfDayPreference,
                    decoration: _inputDecoration('Select time preference', Icons.access_time_rounded),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    borderRadius: BorderRadius.circular(16),
                    items: _timeOfDayOptions.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Text(option, style: GoogleFonts.inter()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _timeOfDayPreference = value;
                        // Clear time slots that are no longer valid based on time preference
                        _selectedTimeSlots.removeWhere((slot) => !_filteredTimeSlots.contains(slot));
                      });
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Availability Section
                FadeInSlide(
                  delay: 0.7,
                  child: Text(
                    'Availability',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                FadeInSlide(delay: 0.75, child: _buildLabel('Preferred Days')),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.75,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _days.map((day) {
                      final isSelected = _selectedDays.contains(day);
                      return FilterChip(
                        label: Text(day),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedDays.add(day);
                            } else {
                              _selectedDays.remove(day);
                            }
                          });
                        },
                        selectedColor: const Color(0xff3B82F6).withOpacity(0.1),
                        checkmarkColor: const Color(0xff3B82F6),
                        labelStyle: GoogleFonts.inter(
                          color: isSelected ? const Color(0xff3B82F6) : const Color(0xff374151),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? const Color(0xff3B82F6) : const Color(0xffE5E7EB),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                FadeInSlide(delay: 0.8, child: _buildLabel('Preferred Time Slots')),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: const Color(0xff3B82F6)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _getFilterMessage(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xff3B82F6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.8,
                  child: _filteredTimeSlots.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xffF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xffE5E7EB)),
                          ),
                          child: Text(
                            'Please select both time of day preference and session duration to see available time slots.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xff6B7280),
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _filteredTimeSlots.map((slot) {
                      final isSelected = _selectedTimeSlots.contains(slot);
                      return FilterChip(
                        label: Text(slot),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTimeSlots.add(slot);
                            } else {
                              _selectedTimeSlots.remove(slot);
                            }
                          });
                        },
                        selectedColor: const Color(0xff3B82F6).withOpacity(0.1),
                        checkmarkColor: const Color(0xff3B82F6),
                        labelStyle: GoogleFonts.inter(
                          color: isSelected ? const Color(0xff3B82F6) : const Color(0xff374151),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? const Color(0xff3B82F6) : const Color(0xffE5E7EB),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 40),

                // Submit Button
                FadeInSlide(
                  delay: 0.9,
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff3B82F6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: const Color(0xff3B82F6).withOpacity(0.4),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Book Free Trial',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: const Color(0xff374151),
      ),
    );
  }

  String _getFilterMessage() {
    List<String> messages = [];
    final timePreference = _timeOfDayPreference;
    
    if (timePreference != null && timePreference != 'Flexible' && _sessionDuration != null) {
      final slotCount = _filteredTimeSlots.length;
      messages.add('Showing $slotCount ${slotCount == 1 ? 'time slot' : 'time slots'} for ${timePreference.toLowerCase()} (${_sessionDuration})');
    } else if (timePreference != null && timePreference != 'Flexible') {
      messages.add('Select session duration to see available time slots');
    } else if (_sessionDuration != null) {
      messages.add('Select time of day preference to see available time slots');
    } else {
      messages.add('Select time of day and session duration to see available time slots');
    }
    
    return messages.isEmpty ? '' : messages.join(' • ');
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: const Color(0xff9CA3AF)),
      prefixIcon: Icon(icon, color: const Color(0xff9CA3AF), size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xffE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xffE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xff3B82F6), width: 2),
      ),
      filled: true,
      fillColor: const Color(0xffFAFAFA), // Very light grey for input bg
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        // 1. Construct the data object
        final request = EnrollmentRequest(
          subject: _selectedSubject,
          specificLanguage: _selectedSubject == 'African Languages (Other)'
              ? _selectedAfricanLanguage
              : null,
          gradeLevel: _selectedGrade!,
          email: _emailController.text.trim(),
          phoneNumber: _phoneNumber,
          countryCode: _selectedCountry?.countryCode ?? 'US',
          countryName: _selectedCountry?.name ?? 'United States',
          preferredDays: _selectedDays,
          preferredTimeSlots: _selectedTimeSlots,
          submittedAt: DateTime.now(),
          // For now, we simulate timezone detection. In a real app, use 'flutter_timezone' package.
          timeZone: DateTime.now().timeZoneName,
          // Enhanced fields
          role: _role,
          preferredLanguage: _preferredLanguage,
          parentName: _parentNameController.text.trim().isEmpty ? null : _parentNameController.text.trim(),
          city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
          whatsAppNumber: _whatsAppNumber.isEmpty ? null : _whatsAppNumber,
          studentName: _studentNameController.text.trim().isEmpty ? null : _studentNameController.text.trim(),
          studentAge: _studentAgeController.text.trim().isEmpty ? null : _studentAgeController.text.trim(),
          gender: _gender,
          knowsZoom: _knowsZoom,
          classType: _classType,
          sessionDuration: _sessionDuration,
          timeOfDayPreference: _timeOfDayPreference,
        );

        // 2. Call the service
        await EnrollmentService().submitEnrollment(request);

        // 3. Success Feedback
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const EnrollmentSuccessPage()),
          );
        }
      } catch (e) {
        // 4. Error Handling
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }
}
