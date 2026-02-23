import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/subject.dart';
import '../../../core/services/subject_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class SubjectManagementScreen extends StatefulWidget {
  const SubjectManagementScreen({super.key});

  @override
  State<SubjectManagementScreen> createState() =>
      _SubjectManagementScreenState();
}

class _SubjectManagementScreenState extends State<SubjectManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    _initializeSubjects();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _buildHeader(),
          _buildToolbar(),
          Expanded(
            child: _buildSubjectsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.subjectManagement,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)!.manageSubjectsForShiftCreation,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _showAddSubjectDialog(),
            icon: const Icon(Icons.add, size: 20),
            label: Text(
              AppLocalizations.of(context)!.addSubject,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
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
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchSubjects,
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF9CA3AF),
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF6B7280),
                  size: 20,
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                  borderSide: const BorderSide(color: Color(0xFF2563EB)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          FilterChip(
            label: Text(
              AppLocalizations.of(context)!.showInactive,
              style: GoogleFonts.inter(fontSize: 14),
            ),
            selected: _showInactive,
            onSelected: (value) {
              setState(() {
                _showInactive = value;
              });
            },
            selectedColor: const Color(0xFF2563EB).withOpacity(0.1),
            checkmarkColor: const Color(0xFF2563EB),
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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading subjects: ${snapshot.error}',
              style: GoogleFonts.inter(color: Colors.red),
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
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'No subjects found'
                      : 'No subjects match your search',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                if (_searchQuery.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.clickAddSubjectToCreateYour,
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
          padding: const EdgeInsets.all(16),
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
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: subject.isActive
              ? const Color(0xFFE5E7EB)
              : const Color(0xFFFCA5A5),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: subject.isActive
                ? const Color(0xFF2563EB).withOpacity(0.1)
                : const Color(0xFFEF4444).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.subject,
            color: subject.isActive
                ? const Color(0xFF2563EB)
                : const Color(0xFFEF4444),
          ),
        ),
        title: Row(
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
                '(${subject.arabicName})',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
            if (!subject.isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppLocalizations.of(context)!.userInactive,
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
        subtitle: subject.description != null
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subject.description!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_showInactive && _searchQuery.isEmpty)
              Icon(
                Icons.drag_handle,
                color: Colors.grey[400],
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit,
                          size: 20, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.commonEdit,
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
                        subject.isActive ? Icons.block : Icons.check_circle,
                        size: 20,
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
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSubjectDialog() {
    final nameController = TextEditingController();
    final displayNameController = TextEditingController();
    final arabicNameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.addNewSubject,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: displayNameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.displayName,
                  hintText: AppLocalizations.of(context)!.eGQuranStudies,
                  labelStyle: GoogleFonts.inter(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.internalName,
                  hintText: AppLocalizations.of(context)!.eGQuranStudies,
                  helperText: AppLocalizations.of(context)!.useLowercaseWithUnderscores,
                  labelStyle: GoogleFonts.inter(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: arabicNameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.arabicNameOptional,
                  hintText: AppLocalizations.of(context)!.eG,
                  labelStyle: GoogleFonts.inter(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.chatGroupDescription,
                  hintText: AppLocalizations.of(context)!.briefDescriptionOfTheSubject,
                  labelStyle: GoogleFonts.inter(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.commonCancel,
              style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final displayName = displayNameController.text.trim();
              final name = nameController.text.trim();

              if (displayName.isEmpty || name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context)!.pleaseFillInAllRequiredFields),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                // Get current max sort order
                final subjects = await SubjectService.getAllSubjects();
                final maxSortOrder = subjects.isEmpty
                    ? 0
                    : subjects
                        .map((s) => s.sortOrder)
                        .reduce((a, b) => a > b ? a : b);

                await SubjectService.addSubject(
                  name: name,
                  displayName: displayName,
                  arabicName: arabicNameController.text.trim().isEmpty
                      ? null
                      : arabicNameController.text.trim(),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  sortOrder: maxSortOrder + 1,
                );

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context)!.subjectDisplaynameAddedSuccessfully(displayName)),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context)!.errorAddingSubjectE),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: Text(
              AppLocalizations.of(context)!.addSubject,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSubjectDialog(Subject subject) {
    final nameController = TextEditingController(text: subject.name);
    final displayNameController =
        TextEditingController(text: subject.displayName);
    final arabicNameController =
        TextEditingController(text: subject.arabicName);
    final descriptionController =
        TextEditingController(text: subject.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.editSubject,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: displayNameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.displayName,
                  labelStyle: GoogleFonts.inter(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.internalName,
                  helperText: AppLocalizations.of(context)!.useLowercaseWithUnderscores,
                  labelStyle: GoogleFonts.inter(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: arabicNameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.arabicNameOptional,
                  labelStyle: GoogleFonts.inter(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.chatGroupDescription,
                  labelStyle: GoogleFonts.inter(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.commonCancel,
              style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final displayName = displayNameController.text.trim();
              final name = nameController.text.trim();

              if (displayName.isEmpty || name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context)!.pleaseFillInAllRequiredFields),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                await SubjectService.updateSubject(subject.id, {
                  'name': name,
                  'displayName': displayName,
                  'arabicName': arabicNameController.text.trim().isEmpty
                      ? null
                      : arabicNameController.text.trim(),
                  'description': descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                });

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(AppLocalizations.of(context)!.subjectDisplaynameUpdatedSuccessfully(displayName)),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context)!.errorUpdatingSubjectE),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: Text(
              AppLocalizations.of(context)!.updateSubject,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSubjectStatus(Subject subject) async {
    try {
      await SubjectService.toggleSubjectStatus(subject.id, !subject.isActive);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            subject.isActive
                ? 'Subject "${subject.displayName}" deactivated'
                : 'Subject "${subject.displayName}" activated',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorUpdatingSubjectStatusE),
          backgroundColor: Colors.red,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorReorderingSubjectsE),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
