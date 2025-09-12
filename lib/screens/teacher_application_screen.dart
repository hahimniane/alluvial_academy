import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/foundation.dart';
import '../shared/widgets/persistent_app_bar.dart';

class TeacherApplicationScreen extends StatefulWidget {
  const TeacherApplicationScreen({super.key});

  @override
  State<TeacherApplicationScreen> createState() => _TeacherApplicationScreenState();
}

class _TeacherApplicationScreenState extends State<TeacherApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _additionalInfoController = TextEditingController();
  
  Country? _selectedCountryOfOrigin;
  Country? _selectedCountryOfResidence;
  String _phoneNumber = '';
  String _countryCode = '';
  final List<String> _selectedLanguages = [];
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
    'Other'
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: const PersistentAppBar(currentPage: 'Teacher Application'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
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
                  _buildPersonalInfoSection(),
                  const SizedBox(height: 32),
                  _buildContactInfoSection(),
                  const SizedBox(height: 32),
                  _buildLanguagesSection(),
                  const SizedBox(height: 32),
                  _buildAdditionalInfoSection(),
                  const SizedBox(height: 48),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xff3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: const Color(0xff3B82F6).withOpacity(0.2)),
          ),
          child: Text(
            '👨‍🏫 Join Our Team',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xff3B82F6),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Teacher Application',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Share the gift of Islamic knowledge with students worldwide',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xff6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Information',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildTextField('First Name', _firstNameController, required: true)),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField('Last Name', _lastNameController, required: true)),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField('Email Address', _emailController, 
            keyboardType: TextInputType.emailAddress, required: true),
        const SizedBox(height: 16),
        _buildCountryOfOriginDropdown(),
        const SizedBox(height: 16),
        _buildCountryOfResidenceDropdown(),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Information',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 16),
        _buildPhoneField(),
      ],
    );
  }

  Widget _buildLanguagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Languages Spoken',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select all languages you can teach in (minimum 1 required)',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xff6B7280),
          ),
        ),
        const SizedBox(height: 16),
        _buildLanguageSelection(),
      ],
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Information',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tell us about your qualifications, teaching experience, or any other relevant information',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xff6B7280),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextArea('Share your background, qualifications, and why you want to teach with us...', 
            _additionalInfoController),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType? keyboardType, bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xff374151),
            ),
            children: required ? [
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ] : null,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xff111827),
          ),
          decoration: _inputDecoration('Enter your ${label.toLowerCase()}'),
          validator: required ? (value) {
            if (value == null || value.trim().isEmpty) {
              return '$label is required';
            }
            if (label == 'Email Address' && !_isValidEmail(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          } : null,
        ),
      ],
    );
  }

  Widget _buildTextArea(String hint, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      maxLines: 4,
      style: GoogleFonts.inter(
        fontSize: 16,
        color: const Color(0xff111827),
      ),
      decoration: _inputDecoration(hint),
    );
  }

  Widget _buildCountryOfOriginDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Country of Origin',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xff374151),
            ),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showCountryPicker(true), // true for country of origin
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xffF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xffD1D5DB),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (_selectedCountryOfOrigin != null) ...[
                  Text(
                    _selectedCountryOfOrigin!.flagEmoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedCountryOfOrigin!.name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xff111827),
                      ),
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      'Select your country of origin',
                      style: GoogleFonts.inter(
                        color: const Color(0xff9CA3AF),
                        fontSize: 16,
                      ),
                    ),
                  ),
                const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xff6B7280),
                ),
              ],
            ),
          ),
        ),
        if (_selectedCountryOfOrigin == null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              'Please select your country of origin',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCountryOfResidenceDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Country of Residence',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xff374151),
            ),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showCountryPicker(false), // false for country of residence
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xffF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xffD1D5DB),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (_selectedCountryOfResidence != null) ...[
                  Text(
                    _selectedCountryOfResidence!.flagEmoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedCountryOfResidence!.name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xff111827),
                      ),
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      'Select your current country of residence',
                      style: GoogleFonts.inter(
                        color: const Color(0xff9CA3AF),
                        fontSize: 16,
                      ),
                    ),
                  ),
                const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xff6B7280),
                ),
              ],
            ),
          ),
        ),
        if (_selectedCountryOfResidence == null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              'Please select your country of residence',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  void _showCountryPicker(bool isCountryOfOrigin) {
    showCountryPicker(
      context: context,
      countryListTheme: CountryListThemeData(
        backgroundColor: Colors.white,
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.7,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        inputDecoration: InputDecoration(
          hintText: 'Search for your country',
          hintStyle: GoogleFonts.inter(
            color: const Color(0xff9CA3AF),
            fontSize: 16,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xff6B7280),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xffD1D5DB),
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xffD1D5DB),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xff0386FF),
              width: 2,
            ),
          ),
          filled: true,
          fillColor: const Color(0xffF9FAFB),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        searchTextStyle: GoogleFonts.inter(
          fontSize: 16,
          color: const Color(0xff111827),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          color: const Color(0xff111827),
        ),
        flagSize: 24,
      ),
      onSelect: (Country country) {
        setState(() {
          if (isCountryOfOrigin) {
            _selectedCountryOfOrigin = country;
          } else {
            _selectedCountryOfResidence = country;
          }
        });
      },
      showPhoneCode: false,
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Phone Number',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xff374151),
            ),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        IntlPhoneField(
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xff111827),
          ),
          decoration: InputDecoration(
            hintText: 'Enter your phone number',
            hintStyle: GoogleFonts.inter(
              color: const Color(0xff9CA3AF),
              fontSize: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xffD1D5DB),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xffD1D5DB),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xff0386FF),
                width: 2,
              ),
            ),
            filled: true,
            fillColor: const Color(0xffF9FAFB),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          onChanged: (phone) {
            setState(() {
              _phoneNumber = phone.number;
              _countryCode = phone.countryCode;
            });
            print('Phone updated: ${phone.completeNumber}, Country Code: ${phone.countryCode}');
          },
          validator: (phone) {
            if (phone == null || phone.number.isEmpty) {
              return 'Phone number is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildLanguageSelection() {
    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _availableLanguages.map((language) {
            final isSelected = _selectedLanguages.contains(language);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedLanguages.remove(language);
                  } else {
                    _selectedLanguages.add(language);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xff0386FF) : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected ? const Color(0xff0386FF) : const Color(0xffD1D5DB),
                    width: 1,
                  ),
                ),
                child: Text(
                  language,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xff374151),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedLanguages.isEmpty) 
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please select at least one language',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff0386FF),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: const Color(0xff9CA3AF),
        ),
        child: _isSubmitting 
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Submitting Application...',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Text(
              'Submit Application',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: const Color(0xff9CA3AF),
        fontSize: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xffD1D5DB),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xffD1D5DB),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xff0386FF),
          width: 2,
        ),
      ),
      filled: true,
      fillColor: const Color(0xffF9FAFB),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCountryOfOrigin == null) {
      _showErrorDialog('Please select your country of origin.');
      return;
    }

    if (_selectedCountryOfResidence == null) {
      _showErrorDialog('Please select your country of residence.');
      return;
    }

    if (_selectedLanguages.isEmpty) {
      _showErrorDialog('Please select at least one language you can teach in.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Validate phone number first
      if (_phoneNumber.isEmpty || _countryCode.isEmpty) {
        _showErrorDialog('Please enter a valid phone number.');
        setState(() {
          _isSubmitting = false;
        });
        return;
      }
      
      // Create application data
      final applicationData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'country_of_origin': _selectedCountryOfOrigin!.name,
        'country_of_residence': _selectedCountryOfResidence!.name,
        'languages': _selectedLanguages,
        'phone_number': _phoneNumber,
        'country_code': _countryCode,
        'additional_info': _additionalInfoController.text.trim().isNotEmpty 
            ? _additionalInfoController.text.trim() : null,
        'submitted_at': kIsWeb ? DateTime.now().toIso8601String() : FieldValue.serverTimestamp(),
        'status': 'pending',
        'review_notes': null,
        'reviewed_by': null,
        'reviewed_at': null,
      };

      // Submit to Firestore with web-compatible approach
      final firestore = FirebaseFirestore.instance;
      late DocumentReference docRef;
      
      if (kIsWeb) {
        // Web-specific submission to handle JavaScript interop issues
        docRef = firestore.collection('teacher_applications').doc();
        
        // Create a simpler data structure for web
        final webData = <String, dynamic>{};
        applicationData.forEach((key, value) {
          if (value != null) {
            webData[key] = value;
          }
        });
        
        await docRef.set(webData);
      } else {
        // Mobile/desktop submission
        docRef = firestore.collection('teacher_applications').doc();
        await docRef.set(applicationData, SetOptions(merge: true));
      }

      if (kDebugMode) {
        print('Application submitted successfully with ID: ${docRef.id}');
      }

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error submitting application: $e');
        print('Error type: ${e.runtimeType}');
      }
      
      if (mounted) {
        String errorMessage = 'Failed to submit application. Please try again later.';
        
        // Handle Firebase web exceptions properly
        try {
          // Try to cast as FirebaseException for web compatibility
          if (e is FirebaseException) {
            switch (e.code) {
              case 'permission-denied':
                errorMessage = 'Permission denied. Please contact support.';
                break;
              case 'unavailable':
                errorMessage = 'Service temporarily unavailable. Please try again.';
                break;
              case 'deadline-exceeded':
                errorMessage = 'Request timed out. Please try again.';
                break;
              case 'network-request-failed':
                errorMessage = 'Network error. Please check your internet connection.';
                break;
              default:
                errorMessage = 'Error: ${e.message ?? 'Unknown error occurred'}';
            }
          } else {
            // Handle other types of errors and string parsing for web
            final errorString = e.toString().toLowerCase();
            if (errorString.contains('permission-denied') || errorString.contains('permission denied')) {
              errorMessage = 'Permission denied. Please contact support.';
            } else if (errorString.contains('network') || errorString.contains('connection')) {
              errorMessage = 'Network error. Please check your internet connection.';
            } else if (errorString.contains('unavailable')) {
              errorMessage = 'Service temporarily unavailable. Please try again.';
            } else if (errorString.contains('timeout') || errorString.contains('deadline')) {
              errorMessage = 'Request timed out. Please try again.';
            }
          }
        } catch (castError) {
          if (kDebugMode) {
            print('Error casting exception: $castError');
          }
          // Fallback to string-based error handling
          final errorString = e.toString().toLowerCase();
          if (errorString.contains('permission')) {
            errorMessage = 'Permission denied. Please contact support.';
          } else if (errorString.contains('network')) {
            errorMessage = 'Network error. Please check your internet connection.';
          }
        }
        
        // Show error message (without technical details in production)
        if (kDebugMode) {
          _showErrorDialog('$errorMessage\n\nTechnical details: ${e.toString()}');
        } else {
          _showErrorDialog(errorMessage);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xff10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Application Submitted!',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xff111827),
              ),
            ),
          ],
        ),
        content: Text(
          'Thank you for your interest in joining our team! We\'ve received your application and will review it carefully. You can expect to hear back from us within 5-7 business days.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xff6B7280),
            height: 1.5,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to previous screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Done',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Error',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xff6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff0386FF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}