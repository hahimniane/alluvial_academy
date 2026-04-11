import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class CircleMemberProfileSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final bool isEditing;

  const CircleMemberProfileSetupScreen({
    super.key,
    required this.onComplete,
    this.isEditing = false,
  });

  @override
  State<CircleMemberProfileSetupScreen> createState() =>
      _CircleMemberProfileSetupScreenState();
}

class _CircleMemberProfileSetupScreenState
    extends State<CircleMemberProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _professionController = TextEditingController();
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        _firstNameController.text = (data['first_name'] as String?) ?? '';
        _lastNameController.text = (data['last_name'] as String?) ?? '';
        final age = data['age'];
        if (age != null) _ageController.text = age.toString();
        _professionController.text = (data['profession'] as String?) ?? '';
      }
    } catch (e) {
      AppLogger.error('CircleMemberProfileSetup: Failed to load data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final age = int.tryParse(_ageController.text.trim());
      final profession = _professionController.text.trim();

      final updates = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'name': '$firstName $lastName'.trim(),
        'profile_completed': true,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (age != null) updates['age'] = age;
      if (profession.isNotEmpty) updates['profession'] = profession;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updates);

      AppLogger.info(
          'CircleMemberProfileSetup: Profile saved for ${user.uid}');

      if (mounted) widget.onComplete();
    } catch (e) {
      AppLogger.error('CircleMemberProfileSetup: Failed to save: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save. Please try again.'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isEditing = widget.isEditing;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: isEditing
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: Text(
                'Edit Profile',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isEditing) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFBF1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 40,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to Alluwal!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us a bit about yourself so your circle members can recognize you.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                _buildField(
                  controller: _firstNameController,
                  label: 'First Name',
                  icon: Icons.person_rounded,
                  required: true,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _lastNameController,
                  label: 'Last Name',
                  icon: Icons.person_outline_rounded,
                  required: true,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _ageController,
                  label: 'Age (optional)',
                  icon: Icons.cake_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _professionController,
                  label: 'Profession (optional)',
                  icon: Icons.work_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEditing ? 'Save' : 'Continue',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                if (!isEditing) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _isSaving ? null : widget.onComplete,
                      child: Text(
                        'Skip for now',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: GoogleFonts.inter(fontSize: 16),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'This field is required';
              }
              return null;
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 22),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
