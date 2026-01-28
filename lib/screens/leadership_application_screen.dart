import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/modern_header.dart';
import '../core/models/leadership_application.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class LeadershipApplicationScreen extends StatefulWidget {
  const LeadershipApplicationScreen({super.key});

  @override
  State<LeadershipApplicationScreen> createState() => _LeadershipApplicationScreenState();
}

class _LeadershipApplicationScreenState extends State<LeadershipApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  
  // Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _locationController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _interestReasonController = TextEditingController();
  final _experienceController = TextEditingController();
  final _currentStatusOtherController = TextEditingController();
  final _availabilityOtherController = TextEditingController();
  
  // State variables
  String _phoneNumber = '';
  String _countryCode = 'US';
  String? _gender;
  String? _currentStatus;
  String? _availabilityStart;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _nationalityController.dispose();
    _phoneController.dispose();
    _interestReasonController.dispose();
    _experienceController.dispose();
    _currentStatusOtherController.dispose();
    _availabilityOtherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Column(
        children: [
          const ModernHeader(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 32,
                  ),
                  padding: const EdgeInsets.all(32),
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
                        _buildPersonalInfoSection(),
                        const SizedBox(height: 32),
                        _buildLeadershipSection(),
                        const SizedBox(height: 32),
                        _buildSubmitButton(),
                      ],
                    ),
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
            color: const Color(0xff10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: const Color(0xff10B981).withOpacity(0.2)),
          ),
          child: Text(
            AppLocalizations.of(context)!.joinOurLeadershipTeam2,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xff10B981),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppLocalizations.of(context)!.joinOurLeadershipTeam,
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
          AppLocalizations.of(context)!.leadInspireAndMakeALasting,
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

  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.personalInformation,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildTextField('First Name', _firstNameController, required: true),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField('Last Name', _lastNameController, required: true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField('Email', _emailController, required: true, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _buildTextField('Current Location (Country and City)', _locationController, required: true),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildDropdownField(
                'Gender *',
                _gender,
                ['male', 'female'],
                ['Male', 'Female'],
                (v) => setState(() => _gender = v),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.whatsappNumber2,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                  const SizedBox(height: 12),
                  IntlPhoneField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.userPhone,
                      hintStyle: GoogleFonts.inter(color: const Color(0xff9CA3AF)),
                      filled: true,
                      fillColor: const Color(0xffFAFAFA),
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
                        borderSide: const BorderSide(color: Color(0xff10B981), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    initialCountryCode: _countryCode,
                    onChanged: (phone) {
                      setState(() {
                        _phoneNumber = phone.completeNumber;
                        _countryCode = phone.countryCode;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField('Nationality', _nationalityController, required: true),
        const SizedBox(height: 16),
        _buildDropdownField(
          'I am currently a... *',
          _currentStatus,
          ['university_student', 'university_graduate', 'professional', 'other'],
          ['University Student', 'University Graduate', 'Professional', 'Other'],
          (v) => setState(() => _currentStatus = v),
        ),
        if (_currentStatus == 'other') ...[
          const SizedBox(height: 16),
          _buildTextField('Please specify', _currentStatusOtherController, required: true),
        ],
      ],
    );
  }

  Widget _buildLeadershipSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.leadershipInterest,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          'Why are you interested in a leadership role? *',
          _interestReasonController,
          required: true,
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'Relevant Leadership/Management Experience (Optional)',
          _experienceController,
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        _buildDropdownField(
          'How soon are you available to start? *',
          _availabilityStart,
          ['one_week', 'two_weeks', 'three_weeks', 'one_month', 'other'],
          ['In One Week', 'In Two Weeks', 'In Three Weeks', 'In a Month', 'Other'],
          (v) => setState(() => _availabilityStart = v),
        ),
        if (_availabilityStart == 'other') ...[
          const SizedBox(height: 16),
          _buildTextField('Please specify availability', _availabilityOtherController, required: true),
        ],
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, TextInputType? keyboardType, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
            ),
            if (required)
              Text(AppLocalizations.of(context)!.text, style: TextStyle(color: Colors.red, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: label,
            hintStyle: GoogleFonts.inter(color: const Color(0xff9CA3AF)),
            filled: true,
            fillColor: const Color(0xffFAFAFA),
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
              borderSide: const BorderSide(color: Color(0xff10B981), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: required
              ? (value) => value == null || value.trim().isEmpty ? 'This field is required' : null
              : null,
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> values,
    List<String> labels,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.formSelectOption,
            hintStyle: GoogleFonts.inter(color: const Color(0xff9CA3AF)),
            filled: true,
            fillColor: const Color(0xffFAFAFA),
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
              borderSide: const BorderSide(color: Color(0xff10B981), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: List.generate(values.length, (index) {
            return DropdownMenuItem(
              value: values[index],
              child: Text(labels[index], overflow: TextOverflow.ellipsis),
            );
          }),
          onChanged: onChanged,
          validator: (value) => value == null ? 'Please select an option' : null,
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _handleSubmit,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xff10B981),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isSubmitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(
              AppLocalizations.of(context)!.submitApplication,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
            ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final application = LeadershipApplication(
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
        interestReason: _interestReasonController.text.trim(),
        relevantExperience: _experienceController.text.trim().isNotEmpty ? _experienceController.text.trim() : null,
        availabilityStart: _availabilityStart!,
        availabilityStartOther: _availabilityStart == 'other' ? _availabilityOtherController.text.trim() : null,
        submittedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('leadership_applications')
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
    setState(() {
      _gender = null;
      _currentStatus = null;
      _availabilityStart = null;
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
              AppLocalizations.of(context)!.applicationSubmitted,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.thankYouForYourInterestIn3,
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
                  backgroundColor: const Color(0xff10B981),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  AppLocalizations.of(context)!.returnHome,
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
