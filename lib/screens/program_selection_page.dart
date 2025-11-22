import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:country_picker/country_picker.dart';
import '../widgets/modern_header.dart';
import '../shared/widgets/fade_in_slide.dart';
import '../core/models/enrollment_request.dart';
import '../core/services/enrollment_service.dart';
import 'enrollment_success_page.dart';

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
  
  // State variables
  String? _selectedSubject;
  String? _selectedGrade;
  String? _selectedAfricanLanguage;
  Country? _selectedCountry;
  String _phoneNumber = '';
  bool _isSubmitting = false;
  
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
  
  final List<String> _timeSlots = [
    '8 AM - 12 PM',
    '12 PM - 4 PM',
    '4 PM - 8 PM',
    '8 PM - 12 AM'
  ];
  final List<String> _selectedTimeSlots = [];

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
                const SizedBox(height: 8),
                FadeInSlide(
                  delay: 0.8,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _timeSlots.map((slot) {
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
