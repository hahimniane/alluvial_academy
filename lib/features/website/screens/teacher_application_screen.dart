import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alluwalacademyadmin/core/utils/phone_national_input_validation.dart';
import 'package:alluwalacademyadmin/core/widgets/modern_header.dart';
import 'package:alluwalacademyadmin/features/website/models/teacher_application.dart';
import 'package:alluwalacademyadmin/core/widgets/fade_in_slide.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class TeacherApplicationScreen extends StatefulWidget {
  const TeacherApplicationScreen({super.key});

  @override
  State<TeacherApplicationScreen> createState() =>
      _TeacherApplicationScreenState();
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
    'English',
    'Arabic',
    'French',
    'Spanish',
    'Mandingo',
    'Pular',
    'Wolof',
    'Hausa',
    'Turkish',
    'Urdu',
    'Bengali',
    'Indonesian',
    'Malay',
    'Swahili',
    'Amharic',
    'Adlam',
    'Other'
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

  bool get _isIslamicStudiesSelected =>
      _selectedPrograms.contains('islamic_studies');
  bool get _isEnglishSelected => _selectedPrograms.contains('english');

  String _localizedLanguage(String language, AppLocalizations l) {
    switch (language) {
      case 'English':
        return l.languageEnglish;
      case 'Arabic':
        return l.languageArabic;
      case 'French':
        return l.languageFrench;
      case 'Spanish':
        return l.publicLanguageSpanish;
      case 'Mandingo':
        return l.publicLanguageMandingo;
      case 'Pular':
        return l.publicLanguagePular;
      case 'Wolof':
        return l.unifiedProgLangWolofTitle;
      case 'Hausa':
        return l.unifiedProgLangHausaTitle;
      case 'Turkish':
        return l.publicLanguageTurkish;
      case 'Urdu':
        return l.publicLanguageUrdu;
      case 'Bengali':
        return l.publicLanguageBengali;
      case 'Indonesian':
        return l.publicLanguageIndonesian;
      case 'Malay':
        return l.publicLanguageMalay;
      case 'Swahili':
        return l.unifiedProgLangSwahiliTitle;
      case 'Amharic':
        return l.unifiedProgLangAmharicTitle;
      case 'Adlam':
        return l.unifiedProgLangAdlamTitle;
      case 'Other':
        return l.other;
    }
    return language;
  }

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
            AppLocalizations.of(context)!.joinOurTeam,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xff8B5CF6),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppLocalizations.of(context)!.teacherApplication,
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
          AppLocalizations.of(context)!.thankYouForYourInterestIn,
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
                  color: isActive
                      ? const Color(0xff8B5CF6)
                      : const Color(0xffE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!
              .publicTeacherStepProgress(_currentPage + 1, totalPages),
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
          _buildSectionTitle(
              AppLocalizations.of(context)!.publicTeacherPersonalInfo,
              Icons.person_outline),
          const SizedBox(height: 24),
          FadeInSlide(
              delay: 0.1,
              child: _buildTextField(AppLocalizations.of(context)!.firstName,
                  'Mahmoud', _firstNameController,
                  required: true)),
          const SizedBox(height: 16),
          FadeInSlide(
              delay: 0.15,
              child: _buildTextField(AppLocalizations.of(context)!.lastName,
                  'Barry', _lastNameController,
                  required: true)),
          const SizedBox(height: 16),
          FadeInSlide(
            delay: 0.2,
            child: _buildTextField(
              AppLocalizations.of(context)!.loginEmail,
              'Mahmoud.barry@example.com',
              _emailController,
              required: true,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return AppLocalizations.of(context)!.publicRequiredField;
                }
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
                  return AppLocalizations.of(context)!
                      .publicContactEmailInvalid;
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          FadeInSlide(
              delay: 0.25,
              child: _buildTextField(
                  AppLocalizations.of(context)!.publicCurrentLocation,
                  AppLocalizations.of(context)!.publicLocationHint,
                  _locationController,
                  required: true)),
          const SizedBox(height: 16),
          FadeInSlide(
            delay: 0.3,
            child: _buildDropdownField(
              label: '${AppLocalizations.of(context)!.publicGender} *',
              value: _gender,
              icon: Icons.person,
              selectedItemBuilder: [
                AppLocalizations.of(context)!.publicMale,
                AppLocalizations.of(context)!.publicFemale
              ].map((gender) {
                return Text(gender, overflow: TextOverflow.ellipsis);
              }).toList(),
              items: [
                DropdownMenuItem(
                    value: 'male',
                    child: Text(AppLocalizations.of(context)!.publicMale,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'female',
                    child: Text(AppLocalizations.of(context)!.publicFemale,
                        overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _gender = value),
              validator: (value) => value == null
                  ? AppLocalizations.of(context)!.publicSelectOption
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          FadeInSlide(
            delay: 0.35,
            child: IntlPhoneField(
              controller: _phoneController,
              decoration: _inputDecoration(
                  '${AppLocalizations.of(context)!.publicTeacherWhatsApp} *',
                  Icons.phone),
              initialCountryCode: 'US',
              disableLengthCheck: true,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (p) =>
                  PhoneNationalInputValidation.validateRequiredNational(
                p,
                AppLocalizations.of(context)!.enrollmentPhoneRequired,
                AppLocalizations.of(context)!
                    .phoneInternationalSubscriberInvalid,
              ),
              onChanged: (phone) {
                setState(() {
                  _phoneNumber = phone.number;
                  _countryCode = phone.countryCode;
                });
              },
            ),
          ),
          SizedBox(height: 16),
          FadeInSlide(
              delay: 0.4,
              child: _buildTextField(
                  AppLocalizations.of(context)!.publicNationality,
                  AppLocalizations.of(context)!.publicNationalityHint,
                  _nationalityController,
                  required: true)),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.45,
            child: DropdownButtonFormField<String>(
              value: _currentStatus,
              isExpanded: true,
              decoration: _inputDecoration(
                  '${AppLocalizations.of(context)!.publicCurrentStatus} *',
                  Icons.school),
              items: [
                DropdownMenuItem(
                    value: 'university_student',
                    child: Text(AppLocalizations.of(context)!.universityStudent,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'high_school_student',
                    child: Text(AppLocalizations.of(context)!.highSchoolStudent,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'university_graduate',
                    child: Text(
                        AppLocalizations.of(context)!.universityGraduate,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'other',
                    child: Text(AppLocalizations.of(context)!.other,
                        overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _currentStatus = value),
              validator: (value) => value == null
                  ? AppLocalizations.of(context)!.publicSelectOption
                  : null,
            ),
          ),
          if (_currentStatus == 'other') ...[
            const SizedBox(height: 16),
            FadeInSlide(
              delay: 0.5,
              child: _buildTextField(
                  AppLocalizations.of(context)!.publicPleaseSpecify,
                  AppLocalizations.of(context)!.publicStatusHint,
                  _currentStatusOtherController,
                  required: true),
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
          _buildSectionTitle(
              AppLocalizations.of(context)!.publicTeacherTeachingPrograms,
              Icons.book_outlined),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.selectTheProgramSYouAre,
            style:
                GoogleFonts.inter(fontSize: 14, color: const Color(0xff6B7280)),
          ),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.1,
            child: _buildProgramChip(
                AppLocalizations.of(context)!.publicTeacherProgramAfterSchool,
                'english',
                Icons.language,
                const Color(0xff3B82F6)),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: 0.15,
            child: _buildProgramChip(
                AppLocalizations.of(context)!.publicTeacherProgramIslamic,
                'islamic_studies',
                Icons.mosque,
                const Color(0xff10B981)),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: 0.2,
            child: _buildProgramChip(
                AppLocalizations.of(context)!.publicTeacherProgramAdultLiteracy,
                'adult_literacy',
                Icons.menu_book,
                const Color(0xffF59E0B)),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: 0.25,
            child: _buildProgramChip(
                AppLocalizations.of(context)!.publicTeacherProgramAdlam,
                'adlam',
                Icons.text_fields,
                const Color(0xff8B5CF6)),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: 0.3,
            child: _buildProgramChip(AppLocalizations.of(context)!.other,
                'other', Icons.more_horiz, const Color(0xff6B7280)),
          ),
          if (_selectedPrograms.contains('other')) ...[
            const SizedBox(height: 16),
            FadeInSlide(
              delay: 0.35,
              child: _buildTextField(
                  AppLocalizations.of(context)!.publicTeacherOtherProgram,
                  AppLocalizations.of(context)!.publicProgramHint,
                  _teachingProgramOtherController,
                  required: true),
            ),
          ],
          if (_showEnglishSubjects) ...[
            const SizedBox(height: 24),
            FadeInSlide(
              delay: 0.4,
              child: _buildTextField(
                AppLocalizations.of(context)!.publicTeacherSubjectsPrompt,
                AppLocalizations.of(context)!.publicTeacherSubjectsHint,
                _englishSubjectsController,
                maxLines: 3,
              ),
            ),
          ],
          if (_isIslamicStudiesSelected) ...[
            const SizedBox(height: 24),
            _buildSectionSubtitle(AppLocalizations.of(context)!
                .publicTeacherIslamicQualifications),
            const SizedBox(height: 16),
            FadeInSlide(
              delay: 0.45,
              child: _buildDropdownField(
                label: AppLocalizations.of(context)!.publicTeacherTajwidPrompt,
                value: _tajwidLevel,
                icon: Icons.auto_stories,
                selectedItemBuilder: [
                  Text(AppLocalizations.of(context)!.commonYes,
                      overflow: TextOverflow.ellipsis),
                  Text(AppLocalizations.of(context)!.commonNo,
                      overflow: TextOverflow.ellipsis),
                  Text(AppLocalizations.of(context)!.average,
                      overflow: TextOverflow.ellipsis),
                  Text(AppLocalizations.of(context)!.nA,
                      overflow: TextOverflow.ellipsis),
                ],
                items: [
                  DropdownMenuItem(
                      value: 'yes',
                      child: Text(AppLocalizations.of(context)!.commonYes,
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: 'no',
                      child: Text(AppLocalizations.of(context)!.commonNo,
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: 'average',
                      child: Text(AppLocalizations.of(context)!.average,
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: 'n/a',
                      child: Text(AppLocalizations.of(context)!.nA,
                          overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) => setState(() => _tajwidLevel = value),
                validator: null,
              ),
            ),
            SizedBox(height: 16),
            FadeInSlide(
              delay: 0.5,
              child: _buildDropdownField(
                label:
                    AppLocalizations.of(context)!.publicTeacherQuranLevelPrompt,
                value: _quranMemorization,
                icon: Icons.book,
                selectedItemBuilder: [
                  Text(AppLocalizations.of(context)!.publicTeacherQuranHafiz,
                      overflow: TextOverflow.ellipsis),
                  Text(AppLocalizations.of(context)!.publicTeacherQuranHalf,
                      overflow: TextOverflow.ellipsis),
                  Text(AppLocalizations.of(context)!.publicTeacherQuranThird,
                      overflow: TextOverflow.ellipsis),
                  Text(AppLocalizations.of(context)!.publicTeacherQuranJuzu,
                      overflow: TextOverflow.ellipsis),
                  const Text('N/A', overflow: TextOverflow.ellipsis),
                ],
                items: [
                  DropdownMenuItem(
                      value: 'hafiz',
                      child: Text(
                          AppLocalizations.of(context)!.publicTeacherQuranHafiz,
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: '50%_or_more',
                      child: Text(
                          AppLocalizations.of(context)!.publicTeacherQuranHalf,
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: '35%_or_less',
                      child: Text(
                          AppLocalizations.of(context)!.publicTeacherQuranThird,
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                    value: 'less_than_juzu_anma',
                    child: Text(
                        AppLocalizations.of(context)!.publicTeacherQuranJuzu,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2),
                  ),
                  DropdownMenuItem(
                      value: 'n/a',
                      child: Text('N/A', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) =>
                    setState(() => _quranMemorization = value),
                validator: null,
              ),
            ),
            const SizedBox(height: 16),
            FadeInSlide(
              delay: 0.55,
              child: _buildDropdownField(
                label: AppLocalizations.of(context)!.publicTeacherArabicPrompt,
                value: _arabicProficiency,
                icon: Icons.translate,
                selectedItemBuilder: [
                  Text(AppLocalizations.of(context)!.iAmExcellent,
                      overflow: TextOverflow.ellipsis),
                  Text(AppLocalizations.of(context)!.iAmIntermediate,
                      overflow: TextOverflow.ellipsis),
                  Text(AppLocalizations.of(context)!.iAmABeginner,
                      overflow: TextOverflow.ellipsis),
                  Text(AppLocalizations.of(context)!.nA,
                      overflow: TextOverflow.ellipsis),
                ],
                items: [
                  DropdownMenuItem(
                      value: 'excellent',
                      child: Text(AppLocalizations.of(context)!.iAmExcellent,
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: 'intermediate',
                      child: Text(AppLocalizations.of(context)!.iAmIntermediate,
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: 'beginner',
                      child: Text(AppLocalizations.of(context)!.iAmABeginner,
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: 'n/a',
                      child: Text(AppLocalizations.of(context)!.nA,
                          overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) =>
                    setState(() => _arabicProficiency = value),
                validator: null,
              ),
            ),
          ],
          const SizedBox(height: 24),
          _buildSectionSubtitle(
              AppLocalizations.of(context)!.publicTeacherFluentLanguages),
          const SizedBox(height: 16),
          FadeInSlide(
            delay: 0.6,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableLanguages.map((lang) {
                final isSelected = _selectedLanguages.contains(lang);
                return FilterChip(
                  label: Text(
                    _localizedLanguage(lang, AppLocalizations.of(context)!),
                  ),
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
          _buildSectionTitle(
              AppLocalizations.of(context)!.publicTeacherExperienceCommitment,
              Icons.work_outline),
          SizedBox(height: 24),
          FadeInSlide(
            delay: 0.1,
            child: _buildDropdownField(
              label:
                  '${AppLocalizations.of(context)!.publicTeacherTimeDisciplinePrompt} *',
              value: _timeDiscipline,
              icon: Icons.access_time,
              selectedItemBuilder: [
                Text(
                    AppLocalizations.of(context)!.publicTeacherDisciplineAlways,
                    overflow: TextOverflow.ellipsis),
                Text(
                    AppLocalizations.of(context)!
                        .publicTeacherDisciplineSometimes,
                    overflow: TextOverflow.ellipsis),
                Text(
                    AppLocalizations.of(context)!
                        .publicTeacherDisciplineDifficult,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.publicTeacherDisciplineDay,
                    overflow: TextOverflow.ellipsis),
              ],
              items: [
                DropdownMenuItem(
                  value: '100%',
                  child: Text(
                    AppLocalizations.of(context)!.publicTeacherDisciplineAlways,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                DropdownMenuItem(
                  value: '50%',
                  child: Text(
                    AppLocalizations.of(context)!
                        .publicTeacherDisciplineSometimes,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                DropdownMenuItem(
                  value: '<30%',
                  child: Text(
                    AppLocalizations.of(context)!
                        .publicTeacherDisciplineDifficult,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                DropdownMenuItem(
                  value: 'day_person',
                  child: Text(
                    AppLocalizations.of(context)!.publicTeacherDisciplineDay,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _timeDiscipline = value),
              validator: (value) => value == null
                  ? AppLocalizations.of(context)!.publicSelectOption
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          FadeInSlide(
            delay: 0.15,
            child: _buildDropdownField(
              label:
                  '${AppLocalizations.of(context)!.publicTeacherBalancePrompt} *',
              value: _scheduleBalance,
              icon: Icons.balance,
              selectedItemBuilder: [
                Text(AppLocalizations.of(context)!.publicTeacherBalanceAlways,
                    overflow: TextOverflow.ellipsis),
                Text(
                    AppLocalizations.of(context)!.publicTeacherBalanceSometimes,
                    overflow: TextOverflow.ellipsis),
                Text(
                    AppLocalizations.of(context)!.publicTeacherBalanceDifficult,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.notAtAll,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.nA,
                    overflow: TextOverflow.ellipsis),
              ],
              items: [
                DropdownMenuItem(
                    value: '100%',
                    child: Text(
                        AppLocalizations.of(context)!
                            .publicTeacherBalanceAlways,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: '50%',
                    child: Text(
                        AppLocalizations.of(context)!
                            .publicTeacherBalanceSometimes,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                  value: '>30%',
                  child: Text(
                    AppLocalizations.of(context)!.publicTeacherBalanceDifficult,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                DropdownMenuItem(
                    value: 'not_at_all',
                    child: Text(AppLocalizations.of(context)!.notAtAll,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'n/a',
                    child: Text(AppLocalizations.of(context)!.nA,
                        overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _scheduleBalance = value),
              validator: (value) => value == null
                  ? AppLocalizations.of(context)!.publicSelectOption
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.2,
            child: _buildTextField(
              AppLocalizations.of(context)!.publicTeacherInterestPrompt,
              AppLocalizations.of(context)!.publicTeacherInterestHint,
              _interestReasonController,
              maxLines: 6,
              required: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppLocalizations.of(context)!
                      .publicTeacherInterestRequired;
                }
                final wordCount = value.trim().split(RegExp(r'\s+')).length;
                if (wordCount < 100) {
                  return AppLocalizations.of(context)!
                      .publicTeacherMinWords(100, wordCount);
                }
                if (wordCount > 400) {
                  return AppLocalizations.of(context)!
                      .publicTeacherMaxWords(400, wordCount);
                }
                return null;
              },
            ),
          ),
          SizedBox(height: 24),
          FadeInSlide(
            delay: 0.25,
            child: _buildDropdownField(
              label:
                  '${AppLocalizations.of(context)!.publicTeacherElectricityPrompt} *',
              value: _electricityAccess,
              icon: Icons.bolt,
              selectedItemBuilder: [
                Text(AppLocalizations.of(context)!.always24Hours7Days,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.sometimes,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.rarely,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.never,
                    overflow: TextOverflow.ellipsis),
              ],
              items: [
                DropdownMenuItem(
                    value: 'always',
                    child: Text(
                        AppLocalizations.of(context)!.always24Hours7Days,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'sometimes',
                    child: Text(AppLocalizations.of(context)!.sometimes,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'rarely',
                    child: Text(AppLocalizations.of(context)!.rarely,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'never',
                    child: Text(AppLocalizations.of(context)!.never,
                        overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _electricityAccess = value),
              validator: (value) => value == null
                  ? AppLocalizations.of(context)!.publicSelectOption
                  : null,
            ),
          ),
          SizedBox(height: 24),
          FadeInSlide(
            delay: 0.3,
            child: _buildDropdownField(
              label:
                  '${AppLocalizations.of(context)!.publicTeacherComfortPrompt} *',
              value: _teachingComfort,
              icon: Icons.video_call,
              selectedItemBuilder: [
                Text(AppLocalizations.of(context)!.veryComfortable,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.comfortable,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.lessComfortable,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.uncomfortable,
                    overflow: TextOverflow.ellipsis),
              ],
              items: [
                DropdownMenuItem(
                    value: 'very_comfortable',
                    child: Text(AppLocalizations.of(context)!.veryComfortable,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'comfortable',
                    child: Text(AppLocalizations.of(context)!.comfortable,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'less_comfortable',
                    child: Text(AppLocalizations.of(context)!.lessComfortable,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'uncomfortable',
                    child: Text(AppLocalizations.of(context)!.uncomfortable,
                        overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _teachingComfort = value),
              validator: (value) => value == null
                  ? AppLocalizations.of(context)!.publicSelectOption
                  : null,
            ),
          ),
          SizedBox(height: 24),
          FadeInSlide(
            delay: 0.35,
            child: _buildDropdownField(
              label:
                  '${AppLocalizations.of(context)!.publicTeacherSafetyPrompt} *',
              value: _studentInteractionGuarantee,
              icon: Icons.shield,
              selectedItemBuilder: [
                Text(AppLocalizations.of(context)!.yesAndAlways,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.sometimes,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.maybeButIWillTry,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.noICanT,
                    overflow: TextOverflow.ellipsis),
              ],
              items: [
                DropdownMenuItem(
                    value: 'yes_always',
                    child: Text(AppLocalizations.of(context)!.yesAndAlways,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'sometimes',
                    child: Text(AppLocalizations.of(context)!.sometimes,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'maybe_try',
                    child: Text(AppLocalizations.of(context)!.maybeButIWillTry,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'no_cant',
                    child: Text(AppLocalizations.of(context)!.noICanT,
                        overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) =>
                  setState(() => _studentInteractionGuarantee = value),
              validator: (value) => value == null
                  ? AppLocalizations.of(context)!.publicSelectOption
                  : null,
            ),
          ),
          SizedBox(height: 24),
          FadeInSlide(
            delay: 0.4,
            child: _buildDropdownField(
              label:
                  '${AppLocalizations.of(context)!.publicTeacherStartPrompt} *',
              value: _availabilityStart,
              icon: Icons.calendar_today,
              selectedItemBuilder: [
                Text(AppLocalizations.of(context)!.inOneWeekFromNow,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.inTwoWeeksFromNow,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.inThreeWeeksFromNow,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.inAMonthFromNow,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.other,
                    overflow: TextOverflow.ellipsis),
              ],
              items: [
                DropdownMenuItem(
                    value: 'one_week',
                    child: Text(AppLocalizations.of(context)!.inOneWeekFromNow,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'two_weeks',
                    child: Text(AppLocalizations.of(context)!.inTwoWeeksFromNow,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'three_weeks',
                    child: Text(
                        AppLocalizations.of(context)!.inThreeWeeksFromNow,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'one_month',
                    child: Text(AppLocalizations.of(context)!.inAMonthFromNow,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'other',
                    child: Text(AppLocalizations.of(context)!.other,
                        overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _availabilityStart = value),
              validator: (value) => value == null
                  ? AppLocalizations.of(context)!.publicSelectOption
                  : null,
            ),
          ),
          if (_availabilityStart == 'other') ...[
            const SizedBox(height: 16),
            FadeInSlide(
              delay: 0.45,
              child: _buildTextField(
                  AppLocalizations.of(context)!.publicSpecifyAvailability,
                  AppLocalizations.of(context)!.publicAvailabilityHint,
                  _availabilityOtherController,
                  required: true),
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
          _buildSectionTitle(
              AppLocalizations.of(context)!.publicTeacherTechnicalRequirements,
              Icons.computer),
          SizedBox(height: 24),
          FadeInSlide(
            delay: 0.1,
            child: _buildDropdownField(
              label:
                  '${AppLocalizations.of(context)!.publicTeacherDevicePrompt} *',
              value: _teachingDevice,
              icon: Icons.devices,
              selectedItemBuilder: [
                Text(AppLocalizations.of(context)!.aComputer,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.aTablet,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.aPhone,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.noDevice,
                    overflow: TextOverflow.ellipsis),
              ],
              items: [
                DropdownMenuItem(
                    value: 'computer',
                    child: Text(AppLocalizations.of(context)!.aComputer,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'tablet',
                    child: Text(AppLocalizations.of(context)!.aTablet,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'phone',
                    child: Text(AppLocalizations.of(context)!.aPhone,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'no_device',
                    child: Text(AppLocalizations.of(context)!.noDevice,
                        overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _teachingDevice = value),
              validator: (value) => value == null
                  ? AppLocalizations.of(context)!.publicSelectOption
                  : null,
            ),
          ),
          SizedBox(height: 24),
          FadeInSlide(
            delay: 0.15,
            child: _buildDropdownField(
              label:
                  '${AppLocalizations.of(context)!.publicTeacherInternetPrompt} *',
              value: _internetAccess,
              icon: Icons.wifi,
              selectedItemBuilder: [
                Text(AppLocalizations.of(context)!.always24Hours7Days,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.oftenFewDaysAWeek,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.rarelyFewHoursAWeek,
                    overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.notAtAll,
                    overflow: TextOverflow.ellipsis),
              ],
              items: [
                DropdownMenuItem(
                    value: 'always',
                    child: Text(
                        AppLocalizations.of(context)!.always24Hours7Days,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'often',
                    child: Text(AppLocalizations.of(context)!.oftenFewDaysAWeek,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'rarely',
                    child: Text(
                        AppLocalizations.of(context)!.rarelyFewHoursAWeek,
                        overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(
                    value: 'not_at_all',
                    child: Text(AppLocalizations.of(context)!.notAtAll,
                        overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _internetAccess = value),
              validator: (value) => value == null
                  ? AppLocalizations.of(context)!.publicSelectOption
                  : null,
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
          _buildSectionTitle(
              AppLocalizations.of(context)!.publicTeacherScenarios,
              Icons.psychology),
          const SizedBox(height: 24),
          FadeInSlide(
            delay: 0.1,
            child: _buildTextField(
              AppLocalizations.of(context)!.publicTeacherScenarioPrompt,
              AppLocalizations.of(context)!.publicTeacherScenarioHint,
              _scenarioController,
              maxLines: 6,
              required: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppLocalizations.of(context)!
                      .publicTeacherScenarioRequired;
                }
                final wordCount = value.trim().split(RegExp(r'\s+')).length;
                if (wordCount < 100) {
                  return AppLocalizations.of(context)!
                      .publicTeacherMinWords(100, wordCount);
                }
                if (wordCount > 300) {
                  return AppLocalizations.of(context)!
                      .publicTeacherMaxWords(300, wordCount);
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle(
              AppLocalizations.of(context)!.publicTeacherFeedback,
              Icons.feedback_outlined),
          const SizedBox(height: 16),
          FadeInSlide(
            delay: 0.15,
            child: _buildTextField(
              AppLocalizations.of(context)!.publicTeacherFeedbackPrompt,
              AppLocalizations.of(context)!.publicTeacherFeedbackHint,
              _feedbackController,
              maxLines: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramChip(
      String label, String value, IconData icon, Color color) {
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
                color: isSelected
                    ? color.withOpacity(0.2)
                    : const Color(0xffF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  color: isSelected ? color : const Color(0xff6B7280),
                  size: 20),
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
              Icon(Icons.radio_button_unchecked,
                  color: const Color(0xff9CA3AF), size: 24),
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

  Widget _buildTextField(
      String label, String hint, TextEditingController controller,
      {bool required = false,
      TextInputType? keyboardType,
      int maxLines = 1,
      String? Function(String?)? validator}) {
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
              Padding(
                padding: EdgeInsets.only(left: 4, top: 2),
                child: Text(AppLocalizations.of(context)!.commonRequired,
                    style: TextStyle(color: Colors.red, fontSize: 15)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: _inputDecoration(hint, null),
          validator: validator ??
              (required
                  ? (value) => value == null || value.trim().isEmpty
                      ? AppLocalizations.of(context)!.publicRequiredField
                      : null
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
          decoration: _inputDecoration(
              AppLocalizations.of(context)!.publicSelectAnOption, icon),
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
      prefixIcon:
          icon != null ? Icon(icon, color: const Color(0xff9CA3AF)) : null,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(0, 48),
              ),
              child: Text(
                AppLocalizations.of(context)!.previous,
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
            onPressed: _isSubmitting
                ? null
                : () {
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(0, 48),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _currentPage < 4
                        ? AppLocalizations.of(context)!.publicNext
                        : AppLocalizations.of(context)!.publicSubmitApplication,
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
        SnackBar(
            content: Text(
                AppLocalizations.of(context)!.pleaseSelectAtLeastOneTeaching)),
      );
      _pageController.jumpToPage(1);
      return;
    }

    if (_selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context)!.pleaseSelectAtLeastOneLanguage)),
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
        currentStatusOther: _currentStatus == 'other'
            ? _currentStatusOtherController.text.trim()
            : null,
        teachingPrograms: _selectedPrograms,
        teachingProgramOther: _selectedPrograms.contains('other')
            ? _teachingProgramOtherController.text.trim()
            : null,
        englishSubjects: _isEnglishSelected &&
                _englishSubjectsController.text.trim().isNotEmpty
            ? _englishSubjectsController.text
                .trim()
                .split(',')
                .map((e) => e.trim())
                .toList()
            : null,
        languages: _selectedLanguages,
        timeDiscipline: _timeDiscipline!,
        scheduleBalance: _scheduleBalance!,
        tajwidLevel: _isIslamicStudiesSelected ? _tajwidLevel : null,
        quranMemorization:
            _isIslamicStudiesSelected ? _quranMemorization : null,
        arabicProficiency:
            _isIslamicStudiesSelected ? _arabicProficiency : null,
        interestReason: _interestReasonController.text.trim(),
        electricityAccess: _electricityAccess!,
        teachingComfort: _teachingComfort!,
        studentInteractionGuarantee: _studentInteractionGuarantee!,
        availabilityStart: _availabilityStart!,
        availabilityStartOther: _availabilityStart == 'other'
            ? _availabilityOtherController.text.trim()
            : null,
        teachingDevice: _teachingDevice!,
        internetAccess: _internetAccess!,
        scenarioNonParticipatingStudent:
            _scenarioController.text.trim().isNotEmpty
                ? _scenarioController.text.trim()
                : null,
        feedbackOnForm: _feedbackController.text.trim().isNotEmpty
            ? _feedbackController.text.trim()
            : null,
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
          SnackBar(
              content: Text(
                  AppLocalizations.of(context)!.publicApplicationSubmitFailed)),
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
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.applicationSubmitted,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.thankYouForYourInterestWe,
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  AppLocalizations.of(context)!.returnHome,
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
