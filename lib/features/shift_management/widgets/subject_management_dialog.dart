import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/subject.dart';
import '../../../core/services/subject_service.dart';

class SubjectManagementDialog extends StatefulWidget {
  const SubjectManagementDialog({super.key});

  @override
  State<SubjectManagementDialog> createState() =>
      _SubjectManagementDialogState();
}

class _SubjectManagementDialogState extends State<SubjectManagementDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showInactive = false;

  void _safeShowSnackBar(String message, {Color backgroundColor = Colors.green}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeSubjects();
  }

  void _showDeleteConfirmationDialog(Subject subject) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text('Delete Subject', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${subject.displayName}"? This cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await SubjectService.hardDeleteSubject(subject.id);
                _safeShowSnackBar('Subject "${subject.displayName}" deleted');
              } catch (e) {
                _safeShowSnackBar('Error deleting subject: $e', backgroundColor: Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeSubjects() async {
    await SubjectService.initializeDefaultSubjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 800,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(
              child: _buildSubjectsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0386FF).withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0386FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.subject,
              color: Color(0xFF0386FF),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subject Management',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add and manage subjects for shifts',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            color: const Color(0xFF6B7280),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search subjects...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF9CA3AF),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF6B7280),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showAddSubjectDialog(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0386FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add Subject',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilterChip(
            label: Text(
              'Show Inactive',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            selected: _showInactive,
            onSelected: (value) {
              setState(() {
                _showInactive = value;
              });
            },
            selectedColor: const Color(0xFF0386FF).withOpacity(0.1),
            checkmarkColor: const Color(0xFF0386FF),
            backgroundColor: const Color(0xFFF9FAFB),
            side: BorderSide(
              color: _showInactive
                  ? const Color(0xFF0386FF)
                  : const Color(0xFFE5E7EB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsList() {
    return StreamBuilder<List<Subject>>(
      stream: _showInactive
          ? SubjectService.getSubjectsStream()
          : SubjectService.getActiveSubjectsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF0386FF),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading subjects',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final subjects = snapshot.data ?? [];
        final filteredSubjects = subjects.where((subject) {
          if (_searchQuery.isEmpty) return true;
          final query = _searchQuery.toLowerCase();
          return subject.displayName.toLowerCase().contains(query) ||
              subject.name.toLowerCase().contains(query) ||
              (subject.arabicName?.contains(_searchQuery) ?? false) ||
              (subject.description?.toLowerCase().contains(query) ?? false);
        }).toList();

        if (filteredSubjects.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.subject,
                  size: 64,
                  color: const Color(0xFF6B7280).withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'No subjects found'
                      : 'No subjects match your search',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                if (_searchQuery.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Click "Add Subject" to create your first subject',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filteredSubjects.length,
          onReorder: (oldIndex, newIndex) {
            if (!_showInactive && _searchQuery.isEmpty) {
              _reorderSubjects(filteredSubjects, oldIndex, newIndex);
            }
          },
          itemBuilder: (context, index) {
            final subject = filteredSubjects[index];
            return _buildSubjectCard(subject, Key(subject.id));
          },
        );
      },
    );
  }

  Widget _buildSubjectCard(Subject subject, Key key) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEditSubjectDialog(subject),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: subject.isActive ? Colors.white : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: subject.isActive
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFFFCA5A5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Subject Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: subject.isActive
                        ? const Color(0xFF0386FF).withOpacity(0.1)
                        : const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _getSubjectEmoji(subject.name),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Subject Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            subject.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: subject.isActive
                                  ? const Color(0xFF111827)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                          if (subject.arabicName != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              subject.arabicName!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                                fontFamily: 'Arial',
                              ),
                            ),
                          ],
                          if (!subject.isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Inactive',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFFEF4444),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subject.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subject.description!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF6B7280),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (subject.defaultWage != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.attach_money, size: 14, color: Colors.green),
                              Text(
                                'Rate: \$${subject.defaultWage!.toStringAsFixed(2)}/hr',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_showInactive && _searchQuery.isEmpty)
                      Icon(
                        Icons.drag_handle,
                        color: const Color(0xFF6B7280).withOpacity(0.5),
                      ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Color(0xFF6B7280),
                        size: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit,
                                  size: 18, color: Color(0xFF6B7280)),
                              const SizedBox(width: 8),
                              Text(
                                'Edit',
                                style: GoogleFonts.inter(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: subject.isActive ? 'deactivate' : 'activate',
                          child: Row(
                            children: [
                              Icon(
                                subject.isActive
                                    ? Icons.block
                                    : Icons.check_circle,
                                size: 18,
                                color: subject.isActive
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                subject.isActive ? 'Deactivate' : 'Activate',
                                style: GoogleFonts.inter(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete_forever,
                                size: 18,
                                color: Color(0xFFEF4444),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Delete Permanently',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _showEditSubjectDialog(subject);
                            break;
                          case 'activate':
                          case 'deactivate':
                            _toggleSubjectStatus(subject);
                            break;
                          case 'delete':
                            _showDeleteConfirmationDialog(subject);
                            break;
                        }
                      },
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

  String _getSubjectEmoji(String subjectName) {
    switch (subjectName) {
      case 'quran_studies':
        return '📖';
      case 'hadith_studies':
        return '📚';
      case 'fiqh':
        return '⚖️';
      case 'arabic_language':
        return '🌍';
      case 'islamic_history':
        return '🕌';
      case 'aqeedah':
        return '🤲';
      case 'tafseer':
        return '📜';
      case 'seerah':
        return '👤';
      default:
        return '📚';
    }
  }

  void _showAddSubjectDialog() {
    final displayNameController = TextEditingController();
    final arabicNameController = TextEditingController();
    final descriptionController = TextEditingController();
    final wageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0386FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_circle,
                color: Color(0xFF0386FF),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Add New Subject',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                controller: displayNameController,
                label: 'Display Name *',
                hint: 'e.g., Quran Studies',
                icon: Icons.label,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: arabicNameController,
                label: 'Arabic Name (Optional)',
                hint: 'e.g., دراسات القرآن',
                icon: Icons.language,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: wageController,
                label: 'Default Hourly Wage (Optional)',
                hint: 'e.g., 15.00',
                icon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: descriptionController,
                label: 'Description (Optional)',
                hint: 'Brief description of the subject',
                maxLines: 3,
                icon: Icons.description,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final displayName = displayNameController.text.trim();
              final wageText = wageController.text.trim();
              
              if (displayName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              double? wage;
              if (wageText.isNotEmpty) {
                wage = double.tryParse(wageText);
                if (wage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid wage amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              }

              try {
                // Get current max sort order
                final subjects = await SubjectService.getAllSubjects();
                final maxSortOrder = subjects.isEmpty
                    ? 0
                    : subjects
                        .map((s) => s.sortOrder)
                        .reduce((a, b) => a > b ? a : b);

                await SubjectService.addSubjectAutoName(
                  displayName: displayName,
                  arabicName: arabicNameController.text.trim().isEmpty
                      ? null
                      : arabicNameController.text.trim(),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  sortOrder: maxSortOrder + 1,
                  defaultWage: wage,
                );

                Navigator.of(context).pop();
                _safeShowSnackBar('Subject "$displayName" added successfully');
              } catch (e) {
                _safeShowSnackBar('Error adding subject: $e', backgroundColor: Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0386FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Add Subject',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSubjectDialog(Subject subject) {
    final displayNameController =
        TextEditingController(text: subject.displayName);
    final arabicNameController =
        TextEditingController(text: subject.arabicName);
    final descriptionController =
        TextEditingController(text: subject.description);
    final wageController = TextEditingController(
        text: subject.defaultWage != null ? subject.defaultWage!.toStringAsFixed(2) : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0386FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.edit,
                color: Color(0xFF0386FF),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Edit Subject',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                controller: displayNameController,
                label: 'Display Name *',
                icon: Icons.label,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: arabicNameController,
                label: 'Arabic Name (Optional)',
                icon: Icons.language,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: wageController,
                label: 'Default Hourly Wage (Optional)',
                hint: 'e.g., 15.00',
                icon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: descriptionController,
                label: 'Description (Optional)',
                maxLines: 3,
                icon: Icons.description,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final displayName = displayNameController.text.trim();
              final wageText = wageController.text.trim();

              if (displayName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              double? wage;
              if (wageText.isNotEmpty) {
                wage = double.tryParse(wageText);
                if (wage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid wage amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              }

              try {
                await SubjectService.updateSubject(subject.id, {
                  'displayName': displayName,
                  'arabicName': arabicNameController.text.trim().isEmpty
                      ? null
                      : arabicNameController.text.trim(),
                  'description': descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  'defaultWage': wage,
                });

                Navigator.of(context).pop();
                _safeShowSnackBar('Subject "$displayName" updated successfully');
              } catch (e) {
                _safeShowSnackBar('Error updating subject: $e', backgroundColor: Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0386FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Update Subject',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helperText,
    int maxLines = 1,
    IconData? icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF9CA3AF),
            ),
            helperStyle: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
            prefixIcon: icon != null
                ? Icon(icon, size: 20, color: const Color(0xFF6B7280))
                : null,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0386FF)),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: icon != null ? 12 : 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  void _toggleSubjectStatus(Subject subject) async {
    try {
      await SubjectService.toggleSubjectStatus(subject.id, !subject.isActive);
      _safeShowSnackBar(subject.isActive
          ? 'Subject "${subject.displayName}" deactivated'
          : 'Subject "${subject.displayName}" activated');
    } catch (e) {
      _safeShowSnackBar('Error updating subject status: $e', backgroundColor: Colors.red);
    }
  }

  void _reorderSubjects(
      List<Subject> subjects, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final item = subjects.removeAt(oldIndex);
    subjects.insert(newIndex, item);

    try {
      await SubjectService.reorderSubjects(subjects);
    } catch (e) {
      _safeShowSnackBar('Error reordering subjects: $e', backgroundColor: Colors.red);
    }
  }
}
