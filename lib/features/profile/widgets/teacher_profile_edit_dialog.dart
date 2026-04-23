import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_picture_service.dart';
import '../../../core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

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
  bool _isUploadingPhoto = false;
  String? _profilePictureUrl;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
    _loadProfilePicture();
  }

  Future<void> _loadProfilePicture() async {
    final url = await ProfilePictureService.getProfilePictureUrl();
    if (mounted) {
      setState(() => _profilePictureUrl = url);
    }
  }

  /// Picks a new profile picture, uploads it through the owner-scoped
  /// Storage path and refreshes local state. The service takes care of
  /// deleting the previous picture once the new URL is persisted.
  Future<void> _pickAndUploadPhoto({required ImageSource source}) async {
    if (_isUploadingPhoto) return;
    final l10n = AppLocalizations.of(context)!;
    final picked = await ProfilePictureService.pickImage(source: source);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final newUrl = await ProfilePictureService.uploadProfilePicture(picked);
      if (!mounted) return;
      setState(() => _profilePictureUrl = newUrl);
      widget.onProfileUpdated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profilePhotoUpdated),
          backgroundColor: const Color(0xff10B981),
        ),
      );
    } catch (e) {
      AppLogger.error('Error uploading profile photo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profilePhotoUploadFailed),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.profilePhotoFromGallery),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l10n.profilePhotoFromCamera),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              if (_profilePictureUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    l10n.profilePhotoRemove,
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () => Navigator.pop(ctx, null),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted) return;

    if (source != null) {
      await _pickAndUploadPhoto(source: source);
    } else if (_profilePictureUrl != null) {
      try {
        await ProfilePictureService.removeProfilePicture();
        if (!mounted) return;
        setState(() => _profilePictureUrl = null);
        widget.onProfileUpdated?.call();
      } catch (e) {
        AppLogger.error('Error removing profile photo: $e');
      }
    }
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
            content: Text(AppLocalizations.of(context)!.failedToLoadExistingProfileE),
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
                AppLocalizations.of(context)!.loadingProfile,
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
          AppLocalizations.of(context)!.loadingYourExistingProfileInformation,
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
                                  AppLocalizations.of(context)!.profileCompleteProfile,
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xff111827),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.of(context)!.profileHelpParents,
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
                      const SizedBox(height: 24),

                      Center(child: _buildAvatarEditor()),
                      const SizedBox(height: 24),

                      _buildPrivacyNotice(),
                      const SizedBox(height: 24),

                      // Form Fields
                      _buildFormField(
                        AppLocalizations.of(context)!.profileFullName,
                        AppLocalizations.of(context)!.profileFullNameHint,
                        _nameController,
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 24),

                      _buildFormField(
                        AppLocalizations.of(context)!.profileProfessionalTitle,
                        AppLocalizations.of(context)!.profileProfessionalTitleHint,
                        _titleController,
                        Icons.work_outline,
                      ),
                      const SizedBox(height: 24),

                      _buildFormField(
                        AppLocalizations.of(context)!.profileBiography,
                        AppLocalizations.of(context)!.profileBiographyHint,
                        _bioController,
                        Icons.description_outlined,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 24),

                      _buildFormField(
                        AppLocalizations.of(context)!.profileYearsExperience,
                        AppLocalizations.of(context)!.profileYearsExperienceHint,
                        _experienceController,
                        Icons.timeline_outlined,
                      ),
                      const SizedBox(height: 24),

                      _buildFormField(
                        AppLocalizations.of(context)!.profileSpecialties,
                        AppLocalizations.of(context)!.profileSpecialtiesHint,
                        _specialtiesController,
                        Icons.star_outline,
                      ),
                      const SizedBox(height: 24),

                      _buildFormField(
                        AppLocalizations.of(context)!.profileEducationCerts,
                        AppLocalizations.of(context)!.profileEducationCertsHint,
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
                                AppLocalizations.of(context)!.commonCancel,
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
                                          AppLocalizations.of(context)!.profileSaving,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      AppLocalizations.of(context)!.profileSaveProfile,
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

  /// Reminds teachers the data on this screen is private to the in-app
  /// experience and is NOT what shows on the public website. Publishing a
  /// teacher to the public "Team" page is an admin action on the CMS.
  Widget _buildPrivacyNotice() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff0E72ED).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xff0E72ED).withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: Color(0xff0E72ED),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.profilePrivacyNotice,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.45,
                color: const Color(0xff1E3A5F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarEditor() {
    final l10n = AppLocalizations.of(context)!;
    final initials = _nameController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.characters.first.toUpperCase())
        .join();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xff10B981), width: 2),
              ),
              child: ClipOval(
                child: _profilePictureUrl != null
                    ? Image.network(
                        _profilePictureUrl!,
                        fit: BoxFit.cover,
                        width: 108,
                        height: 108,
                      )
                    : Container(
                        color: const Color(0xff10B981).withOpacity(0.1),
                        alignment: Alignment.center,
                        child: Text(
                          initials.isEmpty ? '?' : initials,
                          style: GoogleFonts.inter(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xff10B981),
                          ),
                        ),
                      ),
              ),
            ),
            Material(
              color: const Color(0xff10B981),
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isUploadingPhoto ? null : _showPhotoSourceSheet,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _isUploadingPhoto
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.photo_camera,
                          color: Colors.white,
                          size: 18,
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.profilePhotoChangeHint,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xff6B7280),
          ),
        ),
      ],
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
                        AppLocalizations.of(context)!.profileSavedSuccess,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)!.profileCompletionpercentageComplete,
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
