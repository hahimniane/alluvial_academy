import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import '../widgets/modern_header.dart';
import '../core/models/teacher_application.dart';
import '../shared/widgets/fade_in_slide.dart';

class TeacherApplicationScreen extends StatefulWidget {
  const TeacherApplicationScreen({super.key});

  @override
  State<TeacherApplicationScreen> createState() => _TeacherApplicationScreenState();
}

class _TeacherApplicationScreenState extends State<TeacherApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;
  
  // Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _locationController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _interestReasonController = TextEditingController();
  final _scenarioController = TextEditingController();
  final _feedbackController = TextEditingController();
  final _currentStatusOtherController = TextEditingController();
  final _teachingProgramOtherController = TextEditingController();
  final _availabilityOtherController = TextEditingController();
  final _englishSubjectsController = TextEditingController();
  
  // State variables
  String _phoneNumber = '';
  String _countryCode = '';
  String? _gender;
  String? _currentStatus;
  final List<String> _selectedPrograms = [];
  final List<String> _selectedLanguages = [];
  String? _timeDiscipline;
  String? _scheduleBalance;
  String? _tajwidLevel;
  String? _quranMemorization;
  String? _arabicProficiency;
  String? _electricityAccess;
  String? _teachingComfort;
  String? _studentInteractionGuarantee;
  String? _availabilityStart;
  String? _teachingDevice;
  String? _internetAccess;
  
  bool _isSubmitting = false;

  final List<String> _availableLanguages = [
    'English', 'Arabic', 'French', 'Spanish', 'Mandingo', 'Pular', 'Wolof',
    'Hausa', 'Turkish', 'Urdu', 'Bengali', 'Indonesian', 'Malay', 'Swahili',
    'Amharic', 'Adlam', 'Other'
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _nationalityController.dispose();
    _phoneController.dispose();
    _interestReasonController.dispose();
    _scenarioController.dispose();
    _feedbackController.dispose();
    _currentStatusOtherController.dispose();
    _teachingProgramOtherController.dispose();
    _availabilityOtherController.dispose();
    _englishSubjectsController.dispose();
    super.dispose();
  }

  bool get _isIslamicStudiesSelected => _selectedPrograms.contains('islamic_studies');
  bool get _isEnglishSelected => _selectedPrograms.contains('english');
  bool get _showEnglishSubjects => _isEnglishSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Column(
        children: [
          const ModernHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              physics: const BouncingScrollPhysics(),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  margin: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width < 600 ? 8 : 16,
                  ),
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width < 600 ? 16 : 24,
                  ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildProgressIndicator(),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 600,
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildPage1_PersonalInfo(),
                            _buildPage2_TeachingProgram(),
                            _buildPage3_Experience(),
                            _buildPage4_Technical(),
                            _buildPage5_Scenarios(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildNavigationButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xff8B5CF6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: const Color(0xff8B5CF6).withOpacity(0.2)),
          ),
          child: Text(
            '👨‍🏫 Join Our Team',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xff8B5CF6),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Teacher Application',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: const Color(0xff111827),
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Thank you for your interest in teaching at Alluwal Education Hub!',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xff6B7280),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    final totalPages = 5;
    return Column(
      children: [
        Row(
          children: List.generate(totalPages, (index) {
            final isActive = index <= _currentPage;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index < totalPages - 1 ? 8 : 0),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xff8B5CF6) : const Color(0xffE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Step ${_currentPage + 1} of $totalPages',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xff6B7280),
          ),
        ),
      ],
    );
  }

  // Page 1: Personal Information
  Widget _buildPage1_PersonalInfo() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Personal Information', Icons.person_outline),
          const SizedBox(height: 24),
          FadeInSlide(delay: 0.1, child: _buildTextField('First Name', 'Mahmoud', _firstNameController, required: true)),
          const SizedBox(height: 16),
          FadeInSlide(delay: 0.15, child: _buildTextField('Last Name', 'Barry', _lastNameController, required: true)),
          const SizedBox(height: 16),
          FadeInSlide(delay: 0.2, child: _buildTextField('Email', 'Mahmoud.barry@example.com', _emailController, required: true, keyboardType: TextInputType.emailAddress)),
          const SizedBox(height: 16),
          FadeInSlide(delay: 0.25, child: _buildTextField('Current Location (Country and City)', 'United States, New York', _locationController, required: true)),
          const SizedBox(height: 16),
          FadeInSlide(
            delay: 0.3,
            child: _buildDropdownField(
              label: 'Gender *',
              value: _gender,
              icon: Icons.person,
              selectedItemBuilder: ['Male', 'Female'].map((gender) {
                return Text(gender, overflow: TextOverflow.ellipsis);
              }).toList(),
              items: ['Male', 'Female'].map((gender) {
                return DropdownMenuItem(value: gender.toLowerCase(), child: Text(gender, overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: (value) => setState(() => _gender = value),
              validator: (value) => value == null ? 'Please select your gender' : null,
            ),
          ),
          const SizedBox(height: 16),
          FadeInSlide(
            delay: 0.35,
            child: IntlPhoneField(
              controller: _phoneController,
              decoration: _inputDecoration('WhatsApp Number *', Icons.phone),
              initialCountryCode: 'US',
              onChanged: (phone) {
                setState(() {
                  _phoneNumber = phone.number;
                  _countryCode = phone.countryCode;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          FadeInSlide(delay: 0.4, child: _buildTextField('Nationality', 'American', _nationalityController, required: true)),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.45,
            child: DropdownButtonFormField<String>(
              value: _currentStatus,
              isExpanded: true,
              decoration: _inputDecoration('I am currently a... *', Icons.school),
              items: [
                DropdownMenuItem(value: 'university_student', child: const Text('University Student', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'high_school_student', child: const Text('High School Student', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'university_graduate', child: const Text('University Graduate', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'other', child: const Text('Other', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _currentStatus = value),
              validator: (value) => value == null ? 'Please select your current status' : null,
            ),
          ),
          if (_currentStatus == 'other') ...[
            const SizedBox(height: 16),
            FadeInSlide(
              delay: 0.5,
              child: _buildTextField('Please specify', 'Your current status', _currentStatusOtherController, required: true),
            ),
          ],
        ],
      ),
    );
  }

  // Page 2: Teaching Program
  Widget _buildPage2_TeachingProgram() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Teaching Program', Icons.book_outlined),
          const SizedBox(height: 8),
          Text(
            'Select the program(s) you are interested in teaching:',
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xff6B7280)),
          ),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.1,
            child: _buildProgramChip('English Tutoring Program (Elementary - High School)', 'english', Icons.language, const Color(0xff3B82F6)),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: 0.15,
            child: _buildProgramChip('Islamic Studies Program (Quran, Hadith, Fiqh, etc.)', 'islamic_studies', Icons.mosque, const Color(0xff10B981)),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: 0.2,
            child: _buildProgramChip('Adult Literacy Program (Basic English)', 'adult_literacy', Icons.menu_book, const Color(0xffF59E0B)),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: 0.25,
            child: _buildProgramChip('AdLaM (Reading and Writing)', 'adlam', Icons.text_fields, const Color(0xff8B5CF6)),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: 0.3,
            child: _buildProgramChip('Other', 'other', Icons.more_horiz, const Color(0xff6B7280)),
          ),
          if (_selectedPrograms.contains('other')) ...[
            const SizedBox(height: 16),
            FadeInSlide(
              delay: 0.35,
              child: _buildTextField('Please specify other program', 'Your program', _teachingProgramOtherController, required: true),
            ),
          ],
          if (_showEnglishSubjects) ...[
            const SizedBox(height: 24),
            FadeInSlide(
              delay: 0.4,
              child: _buildTextField(
                'If interested in English Program, list subjects you feel comfortable teaching',
                'Reading, Writing, Grammar, Vocabulary...',
                _englishSubjectsController,
                maxLines: 3,
              ),
            ),
          ],
          if (_isIslamicStudiesSelected) ...[
            const SizedBox(height: 24),
            _buildSectionSubtitle('Islamic Studies Qualifications'),
            const SizedBox(height: 16),
            FadeInSlide(
              delay: 0.45,
              child: _buildDropdownField(
                label: 'Are you excellent in Tajwid Rules?',
                value: _tajwidLevel,
                icon: Icons.auto_stories,
                selectedItemBuilder: const [
                  Text('Yes', overflow: TextOverflow.ellipsis),
                  Text('No', overflow: TextOverflow.ellipsis),
                  Text('Average', overflow: TextOverflow.ellipsis),
                  Text('N/A', overflow: TextOverflow.ellipsis),
                ],
                items: const [
                  DropdownMenuItem(value: 'yes', child: Text('Yes', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'no', child: Text('No', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'average', child: Text('Average', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'n/a', child: Text('N/A', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) => setState(() => _tajwidLevel = value),
                validator: null,
              ),
            ),
            const SizedBox(height: 16),
            FadeInSlide(
              delay: 0.5,
              child: _buildDropdownField(
                label: 'What is your level of Quran Memorization?',
                value: _quranMemorization,
                icon: Icons.book,
                selectedItemBuilder: const [
                  Text('100% - I am Hafiz', overflow: TextOverflow.ellipsis),
                  Text('About 50% or more', overflow: TextOverflow.ellipsis),
                  Text('About 35% or less', overflow: TextOverflow.ellipsis),
                  Text('I memorize less than Juzu Anma', overflow: TextOverflow.ellipsis),
                  Text('N/A', overflow: TextOverflow.ellipsis),
                ],
                items: const [
                  DropdownMenuItem(value: 'hafiz', child: Text('100% - I am Hafiz', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: '50%_or_more', child: Text('About 50% or more', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: '35%_or_less', child: Text('About 35% or less', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                    value: 'less_than_juzu_anma',
                    child: Text('I memorize less than Juzu Anma', overflow: TextOverflow.ellipsis, maxLines: 2),
                  ),
                  DropdownMenuItem(value: 'n/a', child: Text('N/A', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) => setState(() => _quranMemorization = value),
                validator: null,
              ),
            ),
            const SizedBox(height: 16),
            FadeInSlide(
              delay: 0.55,
              child: _buildDropdownField(
                label: 'How perfectly do you read and write Arabic?',
                value: _arabicProficiency,
                icon: Icons.translate,
                selectedItemBuilder: const [
                  Text('I am excellent', overflow: TextOverflow.ellipsis),
                  Text('I am intermediate', overflow: TextOverflow.ellipsis),
                  Text('I am a beginner', overflow: TextOverflow.ellipsis),
                  Text('N/A', overflow: TextOverflow.ellipsis),
                ],
                items: const [
                  DropdownMenuItem(value: 'excellent', child: Text('I am excellent', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'intermediate', child: Text('I am intermediate', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'beginner', child: Text('I am a beginner', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'n/a', child: Text('N/A', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) => setState(() => _arabicProficiency = value),
                validator: null,
              ),
            ),
          ],
          const SizedBox(height: 24),
          _buildSectionSubtitle('Languages You Fluently Speak'),
          const SizedBox(height: 16),
          FadeInSlide(
            delay: 0.6,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableLanguages.map((lang) {
                final isSelected = _selectedLanguages.contains(lang);
                return FilterChip(
                  label: Text(lang),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedLanguages.add(lang);
                      } else {
                        _selectedLanguages.remove(lang);
                      }
                    });
                  },
                  selectedColor: const Color(0xff8B5CF6).withOpacity(0.2),
                  checkmarkColor: const Color(0xff8B5CF6),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Page 3: Experience & Commitment
  Widget _buildPage3_Experience() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Experience & Commitment', Icons.work_outline),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.1,
            child: _buildDropdownField(
              label: 'How disciplined are you with time, especially working late at night? *',
              value: _timeDiscipline,
              icon: Icons.access_time,
              selectedItemBuilder: const [
                Text('100% - Sleep will never cause me to be late/absent', overflow: TextOverflow.ellipsis),
                Text('50% - Sleep and personal engagement might impact', overflow: TextOverflow.ellipsis),
                Text('<30% - Resisting sleep and planning ahead is tough', overflow: TextOverflow.ellipsis),
                Text('Sorry not at all, I am a day person', overflow: TextOverflow.ellipsis),
              ],
              items: const [
                DropdownMenuItem(
                  value: '100%',
                  child: Text(
                    '100% - Sleep will never cause me to be late/absent from my class',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                DropdownMenuItem(
                  value: '50%',
                  child: Text(
                    '50% - Sleep and personal engagement might impact my class attendance quite often',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                DropdownMenuItem(
                  value: '<30%',
                  child: Text(
                    '<30% - Resisting sleep and planning ahead is tough for me',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                DropdownMenuItem(
                  value: 'day_person',
                  child: Text(
                    'Sorry not at all, I am a day person',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _timeDiscipline = value),
              validator: (value) => value == null ? 'Please select an option' : null,
            ),
          ),
          const SizedBox(height: 16),
          FadeInSlide(
            delay: 0.15,
            child: _buildDropdownField(
              label: 'How well can you balance school/personal schedule with teaching (6 hrs/week required)? *',
              value: _scheduleBalance,
              icon: Icons.balance,
              selectedItemBuilder: const [
                Text('100% - I am always on top of things', overflow: TextOverflow.ellipsis),
                Text('50% - I often try to be on top of things', overflow: TextOverflow.ellipsis),
                Text('>30% - Life balance is not one of my great skills...', overflow: TextOverflow.ellipsis),
                Text('Not at all', overflow: TextOverflow.ellipsis),
                Text('N/A', overflow: TextOverflow.ellipsis),
              ],
              items: const [
                DropdownMenuItem(value: '100%', child: Text('100% - I am always on top of things', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: '50%', child: Text('50% - I often try to be on top of things', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                  value: '>30%',
                  child: Text(
                    '>30% - Life balance is not one of my great skills, but I will try my best',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                DropdownMenuItem(value: 'not_at_all', child: Text('Not at all', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'n/a', child: Text('N/A', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _scheduleBalance = value),
              validator: (value) => value == null ? 'Please select an option' : null,
            ),
          ),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.2,
            child: _buildTextField(
              'Why are you interested in applying for a teaching role with us? (100-400 words)',
              'Describe your motivation...',
              _interestReasonController,
              maxLines: 6,
              required: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please explain your interest';
                }
                final wordCount = value.trim().split(RegExp(r'\s+')).length;
                if (wordCount < 100) {
                  return 'Please write at least 100 words (currently: $wordCount)';
                }
                if (wordCount > 400) {
                  return 'Please limit to 400 words (currently: $wordCount)';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.25,
            child: _buildDropdownField(
              label: 'How often do you have electricity/energy at home? *',
              value: _electricityAccess,
              icon: Icons.bolt,
              selectedItemBuilder: const [
                Text('Always (24/7)', overflow: TextOverflow.ellipsis),
                Text('Sometimes', overflow: TextOverflow.ellipsis),
                Text('Rarely', overflow: TextOverflow.ellipsis),
                Text('Never', overflow: TextOverflow.ellipsis),
              ],
              items: const [
                DropdownMenuItem(value: 'always', child: Text('Always (24/7)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'sometimes', child: Text('Sometimes', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'rarely', child: Text('Rarely', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'never', child: Text('Never', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _electricityAccess = value),
              validator: (value) => value == null ? 'Please select an option' : null,
            ),
          ),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.3,
            child: _buildDropdownField(
              label: 'How comfortable are you teaching teenagers, adults, and children online? *',
              value: _teachingComfort,
              icon: Icons.video_call,
              selectedItemBuilder: const [
                Text('Very comfortable', overflow: TextOverflow.ellipsis),
                Text('Comfortable', overflow: TextOverflow.ellipsis),
                Text('Less comfortable', overflow: TextOverflow.ellipsis),
                Text('Uncomfortable', overflow: TextOverflow.ellipsis),
              ],
              items: const [
                DropdownMenuItem(value: 'very_comfortable', child: Text('Very comfortable', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'comfortable', child: Text('Comfortable', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'less_comfortable', child: Text('Less comfortable', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'uncomfortable', child: Text('Uncomfortable', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _teachingComfort = value),
              validator: (value) => value == null ? 'Please select an option' : null,
            ),
          ),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.35,
            child: _buildDropdownField(
              label: 'Do you guarantee responsible, legal, and moral interaction with students, especially minors? *',
              value: _studentInteractionGuarantee,
              icon: Icons.shield,
              selectedItemBuilder: const [
                Text('Yes and always', overflow: TextOverflow.ellipsis),
                Text('Sometimes', overflow: TextOverflow.ellipsis),
                Text('Maybe, but I will try', overflow: TextOverflow.ellipsis),
                Text('No, I can\'t', overflow: TextOverflow.ellipsis),
              ],
              items: const [
                DropdownMenuItem(value: 'yes_always', child: Text('Yes and always', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'sometimes', child: Text('Sometimes', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'maybe_try', child: Text('Maybe, but I will try', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'no_cant', child: Text('No, I can\'t', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _studentInteractionGuarantee = value),
              validator: (value) => value == null ? 'Please select an option' : null,
            ),
          ),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.4,
            child: _buildDropdownField(
              label: 'How soon are you available to start teaching? *',
              value: _availabilityStart,
              icon: Icons.calendar_today,
              selectedItemBuilder: const [
                Text('In One Week from now', overflow: TextOverflow.ellipsis),
                Text('In Two Weeks from now', overflow: TextOverflow.ellipsis),
                Text('In Three Weeks from now', overflow: TextOverflow.ellipsis),
                Text('In a Month from now', overflow: TextOverflow.ellipsis),
                Text('Other', overflow: TextOverflow.ellipsis),
              ],
              items: const [
                DropdownMenuItem(value: 'one_week', child: Text('In One Week from now', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'two_weeks', child: Text('In Two Weeks from now', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'three_weeks', child: Text('In Three Weeks from now', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'one_month', child: Text('In a Month from now', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'other', child: Text('Other', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _availabilityStart = value),
              validator: (value) => value == null ? 'Please select an option' : null,
            ),
          ),
          if (_availabilityStart == 'other') ...[
            const SizedBox(height: 16),
            FadeInSlide(
              delay: 0.45,
              child: _buildTextField('Please specify availability', 'Your availability', _availabilityOtherController, required: true),
            ),
          ],
        ],
      ),
    );
  }

  // Page 4: Technical Requirements
  Widget _buildPage4_Technical() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Technical Requirements', Icons.computer),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.1,
            child: _buildDropdownField(
              label: 'What device do you intend to use to teach classes? *',
              value: _teachingDevice,
              icon: Icons.devices,
              selectedItemBuilder: const [
                Text('A Computer', overflow: TextOverflow.ellipsis),
                Text('A Tablet', overflow: TextOverflow.ellipsis),
                Text('A Phone', overflow: TextOverflow.ellipsis),
                Text('No device', overflow: TextOverflow.ellipsis),
              ],
              items: const [
                DropdownMenuItem(value: 'computer', child: Text('A Computer', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'tablet', child: Text('A Tablet', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'phone', child: Text('A Phone', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'no_device', child: Text('No device', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _teachingDevice = value),
              validator: (value) => value == null ? 'Please select an option' : null,
            ),
          ),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.15,
            child: _buildDropdownField(
              label: 'How often do you have access to the internet? *',
              value: _internetAccess,
              icon: Icons.wifi,
              selectedItemBuilder: const [
                Text('Always (24/7)', overflow: TextOverflow.ellipsis),
                Text('Often (few days a week)', overflow: TextOverflow.ellipsis),
                Text('Rarely (few hours a week)', overflow: TextOverflow.ellipsis),
                Text('Not at all', overflow: TextOverflow.ellipsis),
              ],
              items: const [
                DropdownMenuItem(value: 'always', child: Text('Always (24/7)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'often', child: Text('Often (few days a week)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'rarely', child: Text('Rarely (few hours a week)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'not_at_all', child: Text('Not at all', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _internetAccess = value),
              validator: (value) => value == null ? 'Please select an option' : null,
            ),
          ),
        ],
      ),
    );
  }

  // Page 5: Scenarios & Feedback
  Widget _buildPage5_Scenarios() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Teaching Scenarios', Icons.psychology),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.1,
            child: _buildTextField(
              'Scenario: What would you do if a student (child) does not want to participate/read during class? (100-300 words)',
              'Describe your approach...',
              _scenarioController,
              maxLines: 6,
              required: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please describe your approach';
                }
                final wordCount = value.trim().split(RegExp(r'\s+')).length;
                if (wordCount < 100) {
                  return 'Please write at least 100 words (currently: $wordCount)';
                }
                if (wordCount > 300) {
                  return 'Please limit to 300 words (currently: $wordCount)';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Feedback', Icons.feedback_outlined),
          const SizedBox(height: 16),
          FadeInSlide(
            delay: 0.15,
            child: _buildTextField(
              'Any feedback on this application form? What didn\'t you like? (Optional)',
              'Your feedback helps us improve...',
              _feedbackController,
              maxLines: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramChip(String label, String value, IconData icon, Color color) {
    final isSelected = _selectedPrograms.contains(value);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedPrograms.remove(value);
          } else {
            _selectedPrograms.add(value);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? color : const Color(0xffE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.2) : const Color(0xffF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: isSelected ? color : const Color(0xff6B7280), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? color : const Color(0xff374151),
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24)
            else
              Icon(Icons.radio_button_unchecked, color: const Color(0xff9CA3AF), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xff8B5CF6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xff8B5CF6), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xff111827),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionSubtitle(String subtitle) {
    return Text(
      subtitle,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: const Color(0xff374151),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller, {bool required = false, TextInputType? keyboardType, int maxLines = 1, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                  height: 1.4,
                ),
                softWrap: true,
              ),
            ),
            if (required)
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 2),
                child: Text(' *', style: TextStyle(color: Colors.red, fontSize: 15)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: _inputDecoration(hint, null),
          validator: validator ?? (required
              ? (value) => value == null || value.trim().isEmpty ? 'This field is required' : null
              : null),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    String? Function(String?)? validator,
    IconData? icon,
    List<Widget>? selectedItemBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xff111827),
            height: 1.4,
          ),
          softWrap: true,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: _inputDecoration('Select an option', icon),
          selectedItemBuilder: selectedItemBuilder != null
              ? (context) => selectedItemBuilder
              : null,
          items: items,
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: const Color(0xff9CA3AF),
        fontSize: 14,
      ),
      labelText: null, // Explicitly set to null to avoid confusion
      prefixIcon: icon != null ? Icon(icon, color: const Color(0xff9CA3AF)) : null,
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
        borderSide: const BorderSide(color: Color(0xff8B5CF6), width: 2),
      ),
      filled: true,
      fillColor: const Color(0xffFAFAFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentPage > 0)
          Flexible(
            child: OutlinedButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                setState(() => _currentPage--);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(0, 48),
              ),
              child: Text(
                'Previous',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        else
          const SizedBox.shrink(),
        const SizedBox(width: 12),
        Flexible(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : () {
              if (_currentPage < 4) {
                // Validate current page
                if (_formKey.currentState!.validate()) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                  setState(() => _currentPage++);
                }
              } else {
                // Last page - submit
                _handleSubmit();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(0, 48),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _currentPage < 4 ? 'Next' : 'Submit Application',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      // Scroll to first error
      _pageController.jumpToPage(0);
      return;
    }

    if (_selectedPrograms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one teaching program')),
      );
      _pageController.jumpToPage(1);
      return;
    }

    if (_selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one language')),
      );
      _pageController.jumpToPage(1);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final application = TeacherApplication(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        currentLocation: _locationController.text.trim(),
        gender: _gender!,
        phoneNumber: _phoneNumber,
        countryCode: _countryCode,
        nationality: _nationalityController.text.trim(),
        currentStatus: _currentStatus!,
        currentStatusOther: _currentStatus == 'other' ? _currentStatusOtherController.text.trim() : null,
        teachingPrograms: _selectedPrograms,
        teachingProgramOther: _selectedPrograms.contains('other') ? _teachingProgramOtherController.text.trim() : null,
        englishSubjects: _isEnglishSelected && _englishSubjectsController.text.trim().isNotEmpty
            ? _englishSubjectsController.text.trim().split(',').map((e) => e.trim()).toList()
            : null,
        languages: _selectedLanguages,
        timeDiscipline: _timeDiscipline!,
        scheduleBalance: _scheduleBalance!,
        tajwidLevel: _isIslamicStudiesSelected ? _tajwidLevel : null,
        quranMemorization: _isIslamicStudiesSelected ? _quranMemorization : null,
        arabicProficiency: _isIslamicStudiesSelected ? _arabicProficiency : null,
        interestReason: _interestReasonController.text.trim(),
        electricityAccess: _electricityAccess!,
        teachingComfort: _teachingComfort!,
        studentInteractionGuarantee: _studentInteractionGuarantee!,
        availabilityStart: _availabilityStart!,
        availabilityStartOther: _availabilityStart == 'other' ? _availabilityOtherController.text.trim() : null,
        teachingDevice: _teachingDevice!,
        internetAccess: _internetAccess!,
        scenarioNonParticipatingStudent: _scenarioController.text.trim().isNotEmpty ? _scenarioController.text.trim() : null,
        feedbackOnForm: _feedbackController.text.trim().isNotEmpty ? _feedbackController.text.trim() : null,
        submittedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('teacher_applications')
          .add(application.toMap());

      if (mounted) {
        _showSuccessDialog();
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit application: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _pageController.jumpToPage(0);
    setState(() {
      _currentPage = 0;
      _gender = null;
      _currentStatus = null;
      _selectedPrograms.clear();
      _selectedLanguages.clear();
      _timeDiscipline = null;
      _scheduleBalance = null;
      _tajwidLevel = null;
      _quranMemorization = null;
      _arabicProficiency = null;
      _electricityAccess = null;
      _teachingComfort = null;
      _studentInteractionGuarantee = null;
      _availabilityStart = null;
      _teachingDevice = null;
      _internetAccess = null;
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xff10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 24),
            Text(
              'Application Submitted!',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Thank you for your interest! We\'ve received your application and will review it carefully. You will receive a confirmation email shortly.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xff6B7280),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff8B5CF6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Return Home',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
