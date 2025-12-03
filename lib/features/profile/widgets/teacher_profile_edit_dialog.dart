import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/utils/app_logger.dart';

/// Reusable dialog for editing teacher profile information
class TeacherProfileEditDialog extends StatefulWidget {
  final VoidCallback? onProfileUpdated;

  const TeacherProfileEditDialog({
    super.key,
    this.onProfileUpdated,
  });

  @override
  State<TeacherProfileEditDialog> createState() => _TeacherProfileEditDialogState();
}

class _TeacherProfileEditDialogState extends State<TeacherProfileEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  final _specialtiesController = TextEditingController();
  final _educationController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _specialtiesController.dispose();
    _educationController.dispose();
    super.dispose();
  }

  /// Load existing teacher profile data from Firestore
  Future<void> _loadExistingProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final profileDoc = await FirebaseFirestore.instance
          .collection('teacher_profiles')
          .doc(user.uid)
          .get();

      if (profileDoc.exists) {
        final data = profileDoc.data()!;
        _nameController.text = data['full_name'] ?? '';
        _titleController.text = data['professional_title'] ?? '';
        _bioController.text = data['biography'] ?? '';
        _experienceController.text = data['years_of_experience'] ?? '';
        _specialtiesController.text = data['specialties'] ?? '';
        _educationController.text = data['education_certifications'] ?? '';
      }
    } catch (e) {
      AppLogger.error('Error loading teacher profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load existing profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Builds loading state widget
  Widget _buildLoadingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xff10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Color(0xff10B981),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Loading Profile...',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff111827),
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              color: const Color(0xff6B7280),
            ),
          ],
        ),
        const SizedBox(height: 40),
        const CircularProgressIndicator(
          color: Color(0xff10B981),
        ),
        const SizedBox(height: 24),
        Text(
          'Loading your existing profile information...',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xff6B7280),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: _isLoading
            ? _buildLoadingState()
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xff10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Color(0xff10B981),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Complete Your Profile',
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xff111827),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Help parents and students learn about your expertise',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xff6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            color: const Color(0xff6B7280),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Form Fields
                      _buildFormField(
                        'Full Name',
                        'Enter your full name as it should appear publicly',
                        _nameController,
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 24),

                      _buildFormField(
                        'Professional Title',
                        'e.g., Quran & Tajweed Specialist, Arabic Teacher',
                        _titleController,
                        Icons.work_outline,
                      ),
                      const SizedBox(height: 24),

                      _buildFormField(
                        'Biography',
                        'Tell parents and students about your background and teaching approach',
                        _bioController,
                        Icons.description_outlined,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 24),

                      _buildFormField(
                        'Years of Experience',
                        'e.g., 10+ years',
                        _experienceController,
                        Icons.timeline_outlined,
                      ),
                      const SizedBox(height: 24),

                      _buildFormField(
                        'Specialties',
                        'e.g., Quran Memorization, Tajweed, Arabic Grammar, Islamic Studies',
                        _specialtiesController,
                        Icons.star_outline,
                      ),
                      const SizedBox(height: 24),

                      _buildFormField(
                        'Education & Certifications',
                        'e.g., PhD in Islamic Theology from Al-Azhar University, Ijazah in Quran',
                        _educationController,
                        Icons.school_outlined,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xff6B7280),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSaving
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Saving...',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      'Save Profile',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFormField(
    String label,
    String hint,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: const Color(0xff9CA3AF),
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: const Color(0xff6B7280)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xff10B981), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xffF9FAFB),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (value) {
            // No required validation - allow partial saves
            return null;
          },
        ),
      ],
    );
  }

  /// Save teacher profile to Firestore (allows partial saves)
  Future<void> _saveProfile() async {
    if (_isSaving) return; // Prevent double saves

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Prepare profile data - allow empty fields for partial saves
      final profileData = {
        'full_name': _nameController.text.trim(),
        'professional_title': _titleController.text.trim(),
        'biography': _bioController.text.trim(),
        'years_of_experience': _experienceController.text.trim(),
        'specialties': _specialtiesController.text.trim(),
        'education_certifications': _educationController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
        'user_id': user.uid,
        'user_email': user.email,
      };

      // Only add created_at if this is a new profile
      final existingDoc = await FirebaseFirestore.instance
          .collection('teacher_profiles')
          .doc(user.uid)
          .get();

      if (!existingDoc.exists) {
        profileData['created_at'] = FieldValue.serverTimestamp();
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('teacher_profiles')
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));

      // Calculate and show completion percentage
      int completedFields = 0;
      const totalFields = 6;

      if (_nameController.text.trim().isNotEmpty) completedFields++;
      if (_titleController.text.trim().isNotEmpty) completedFields++;
      if (_bioController.text.trim().isNotEmpty) completedFields++;
      if (_experienceController.text.trim().isNotEmpty) completedFields++;
      if (_specialtiesController.text.trim().isNotEmpty) completedFields++;
      if (_educationController.text.trim().isNotEmpty) completedFields++;

      final completionPercentage =
          ((completedFields / totalFields) * 100).round();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Profile saved successfully!',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Profile $completionPercentage% complete',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xff10B981),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.of(context).pop();

        // Notify parent to refresh completion percentage
        if (widget.onProfileUpdated != null) {
          widget.onProfileUpdated!();
        }
      }
    } catch (e) {
      AppLogger.error('Error saving teacher profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to save profile: ${e.toString()}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

