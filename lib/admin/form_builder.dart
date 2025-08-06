import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../core/services/form_draft_service.dart';
import '../core/models/form_draft.dart';
import 'draft_management_screen.dart';

class FormBuilder extends StatefulWidget {
  const FormBuilder({super.key});

  @override
  State<FormBuilder> createState() => _FormBuilderState();
}

class _FormBuilderState extends State<FormBuilder>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: TabBarView(
                controller: _tabController,
                children: [
                  FormsListView(),
                  FormBuilderView(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xffE2E8F0), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header with title and description
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xff3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment,
                    color: Color(0xff3B82F6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Forms',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff111827),
                        ),
                      ),
                      Text(
                        'Create, edit, and manage all your forms',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const DraftManagementScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.drafts, size: 18),
                  label: const Text('View Drafts'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff10B981),
                    side: const BorderSide(color: Color(0xff10B981)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tab bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xff3B82F6),
              unselectedLabelColor: const Color(0xff6B7280),
              indicatorColor: const Color(0xff3B82F6),
              indicatorWeight: 2,
              labelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.list_alt),
                  text: 'Forms List',
                ),
                Tab(
                  icon: Icon(Icons.add_circle_outline),
                  text: 'Create New Form',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Forms List View - for managing existing forms
class FormsListView extends StatefulWidget {
  @override
  State<FormsListView> createState() => _FormsListViewState();
}

class _FormsListViewState extends State<FormsListView> {
  String searchQuery = '';
  String statusFilter = 'all'; // all, active, inactive
  String sortBy = 'newest'; // newest, oldest, alphabetical

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFiltersAndSearch(),
        Expanded(
          child: _buildFormsList(),
        ),
      ],
    );
  }

  Widget _buildFiltersAndSearch() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xffE2E8F0), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Search bar and status filter
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xffF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xffE2E8F0)),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search forms...',
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xff9CA3AF),
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xff9CA3AF),
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xffF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: statusFilter,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Forms')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                          value: 'inactive', child: Text('Inactive')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        statusFilter = value!;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quick stats and sort
          Row(
            children: [
              StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('form').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();

                  final forms = snapshot.data!.docs;
                  final activeForms = forms.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['status'] == 'active';
                  }).length;

                  return Row(
                    children: [
                      _buildStatChip(
                          'Total', forms.length.toString(), Colors.blue),
                      const SizedBox(width: 12),
                      _buildStatChip(
                          'Active', activeForms.toString(), Colors.green),
                      const SizedBox(width: 12),
                      _buildStatChip(
                          'Inactive',
                          (forms.length - activeForms).toString(),
                          Colors.orange),
                    ],
                  );
                },
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xffF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: sortBy,
                    items: const [
                      DropdownMenuItem(
                          value: 'newest', child: Text('Newest First')),
                      DropdownMenuItem(
                          value: 'oldest', child: Text('Oldest First')),
                      DropdownMenuItem(
                          value: 'alphabetical', child: Text('A-Z')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        sortBy = value!;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('form').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState();
        }

        if (!snapshot.hasData) {
          return _buildLoadingState();
        }

        var forms = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Filter by search query
          if (searchQuery.isNotEmpty) {
            final title = (data['title'] ?? '').toString().toLowerCase();
            if (!title.contains(searchQuery)) return false;
          }

          // Filter by status
          if (statusFilter != 'all') {
            final status = data['status'] ?? 'active';
            if (status != statusFilter) return false;
          }

          return true;
        }).toList();

        // Sort forms
        switch (sortBy) {
          case 'oldest':
            forms.sort((a, b) {
              final aTime =
                  (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final bTime =
                  (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return aTime.compareTo(bTime);
            });
            break;
          case 'alphabetical':
            forms.sort((a, b) {
              final aTitle = ((a.data() as Map<String, dynamic>)['title'] ?? '')
                  .toString();
              final bTitle = ((b.data() as Map<String, dynamic>)['title'] ?? '')
                  .toString();
              return aTitle.compareTo(bTitle);
            });
            break;
          default: // newest
            forms.sort((a, b) {
              final aTime =
                  (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final bTime =
                  (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });
        }

        if (forms.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: forms.length,
          itemBuilder: (context, index) {
            final form = forms[index];
            final data = form.data() as Map<String, dynamic>;
            return _buildFormCard(form.id, data);
          },
        );
      },
    );
  }

  Widget _buildFormCard(String formId, Map<String, dynamic> data) {
    final title = data['title'] ?? 'Untitled Form';
    final description = data['description'] ?? '';
    final status = data['status'] ?? 'active';
    final createdAt = data['createdAt'] as Timestamp?;
    final responseCount = data['responseCount'] ?? 0;
    final fieldCount = data['fieldCount'] ?? 0;
    final isActive = status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xffE2E8F0) : const Color(0xffFEE2E2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff111827),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildStatusBadge(status),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xff6B7280),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                PopupMenuButton<String>(
                  onSelected: (action) =>
                      _handleFormAction(action, formId, data),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit,
                              size: 16, color: Colors.blue.shade600),
                          const SizedBox(width: 8),
                          const Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy,
                              size: 16, color: Colors.green.shade600),
                          const SizedBox(width: 8),
                          const Text('Duplicate'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: isActive ? 'deactivate' : 'activate',
                      child: Row(
                        children: [
                          Icon(
                            isActive ? Icons.pause : Icons.play_arrow,
                            size: 16,
                            color: isActive
                                ? Colors.orange.shade600
                                : Colors.green.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(isActive ? 'Deactivate' : 'Activate'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete,
                              size: 16, color: Colors.red.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: Colors.red.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xffF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.more_vert,
                      color: Color(0xff6B7280),
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(Icons.quiz, '$fieldCount fields', Colors.blue),
                const SizedBox(width: 12),
                _buildInfoChip(
                    Icons.reply, '$responseCount responses', Colors.green),
                const SizedBox(width: 12),
                if (createdAt != null)
                  _buildInfoChip(
                    Icons.schedule,
                    _formatDate(createdAt.toDate()),
                    Colors.orange,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? Colors.green.shade600 : Colors.red.shade600,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isActive ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'Error loading forms',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xff374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xffF9FAFB),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment,
              size: 48,
              color: Color(0xff9CA3AF),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            searchQuery.isNotEmpty ? 'No forms found' : 'No forms created yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xff374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            searchQuery.isNotEmpty
                ? 'Try adjusting your search or filters'
                : 'Create your first form to get started',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff6B7280),
            ),
          ),
        ],
      ),
    );
  }

  void _handleFormAction(
      String action, String formId, Map<String, dynamic> data) {
    switch (action) {
      case 'edit':
        _editForm(formId, data);
        break;
      case 'duplicate':
        _duplicateForm(formId, data);
        break;
      case 'activate':
      case 'deactivate':
        _toggleFormStatus(formId, action == 'activate');
        break;
      case 'delete':
        _deleteForm(formId, data['title'] ?? 'this form');
        break;
    }
  }

  void _editForm(String formId, Map<String, dynamic> data) {
    // Navigate to form builder in edit mode
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FormBuilderView(
          editFormId: formId,
          editFormData: data,
        ),
      ),
    );
  }

  void _duplicateForm(String formId, Map<String, dynamic> data) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Create a copy of the form data
      final newFormData = Map<String, dynamic>.from(data);
      newFormData['title'] = '${data['title']} (Copy)';
      newFormData['createdAt'] = FieldValue.serverTimestamp();
      newFormData['updatedAt'] = FieldValue.serverTimestamp();
      newFormData['createdBy'] = user.uid;
      newFormData['responseCount'] = 0;
      newFormData['responses'] = {};

      await FirebaseFirestore.instance.collection('form').add(newFormData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Form duplicated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to duplicate form: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleFormStatus(String formId, bool activate) async {
    try {
      await FirebaseFirestore.instance.collection('form').doc(formId).update({
        'status': activate ? 'active' : 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Form ${activate ? 'activated' : 'deactivated'} successfully!'),
            backgroundColor: activate ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update form status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteForm(String formId, String formTitle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Form',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Are you sure you want to delete "$formTitle"? This action cannot be undone and will also delete all responses.',
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _confirmDeleteForm(formId),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteForm(String formId) async {
    Navigator.of(context).pop(); // Close dialog

    try {
      // Delete form document
      await FirebaseFirestore.instance.collection('form').doc(formId).delete();

      // Delete all form responses
      final responsesQuery = await FirebaseFirestore.instance
          .collection('form_responses')
          .where('formId', isEqualTo: formId)
          .get();

      for (var doc in responsesQuery.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Form deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete form: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Form Builder View - the complete form creation interface
class FormBuilderView extends StatefulWidget {
  final String? editFormId;
  final Map<String, dynamic>? editFormData;

  const FormBuilderView({
    super.key,
    this.editFormId,
    this.editFormData,
  });

  @override
  State<FormBuilderView> createState() => _FormBuilderViewState();
}

class _FormBuilderViewState extends State<FormBuilderView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<FormFieldData> fields = [];
  bool _isSaving = false;
  bool _showPreview = false;
  bool _isEditMode = false;

  // Map to store preview field values
  Map<String, dynamic> _previewValues = {};

  // Autosave functionality
  Timer? _autosaveTimer;
  final FormDraftService _draftService = FormDraftService();
  String? _currentDraftId;
  bool _hasUnsavedChanges = false;
  bool _isSavingDraft = false;
  DateTime? _lastAutosaveTime;

  // Field type templates with icons and descriptions
  final List<FieldTemplate> fieldTemplates = [
    FieldTemplate(
      type: 'openEnded',
      title: 'Text Input',
      description: 'Single line text field',
      icon: Icons.text_fields,
      color: const Color(0xff3B82F6),
    ),
    FieldTemplate(
      type: 'description',
      title: 'Long Text',
      description: 'Multi-line text area',
      icon: Icons.notes,
      color: const Color(0xff10B981),
    ),
    FieldTemplate(
      type: 'dropdown',
      title: 'Dropdown',
      description: 'Select one option',
      icon: Icons.arrow_drop_down_circle,
      color: const Color(0xff8B5CF6),
    ),
    FieldTemplate(
      type: 'multiSelect',
      title: 'Multi-Select',
      description: 'Select multiple options',
      icon: Icons.checklist,
      color: const Color(0xffF59E0B),
    ),
    FieldTemplate(
      type: 'yesNo',
      title: 'Yes/No',
      description: 'Boolean choice',
      icon: Icons.toggle_on,
      color: const Color(0xffF59E0B),
    ),
    FieldTemplate(
      type: 'number',
      title: 'Number',
      description: 'Numeric input',
      icon: Icons.pin,
      color: const Color(0xffEF4444),
    ),
    FieldTemplate(
      type: 'date',
      title: 'Date',
      description: 'Date picker',
      icon: Icons.calendar_today,
      color: const Color(0xff06B6D4),
    ),
    FieldTemplate(
      type: 'imageUpload',
      title: 'Image Upload',
      description: 'Upload photos',
      icon: Icons.image,
      color: const Color(0xffEC4899),
    ),
    FieldTemplate(
      type: 'signature',
      title: 'Signature',
      description: 'Digital signature',
      icon: Icons.draw,
      color: const Color(0xff84CC16),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.editFormId != null;

    if (_isEditMode && widget.editFormData != null) {
      _populateFormForEditing();
    } else {
      _titleController.text = 'Untitled Form';
      _descriptionController.text = 'Enter a description for your form...';
    }

    // Initialize autosave functionality
    _initializeAutosave();
  }

  /// Initialize autosave timer and listeners
  void _initializeAutosave() {
    // Add listeners to text controllers to detect changes
    _titleController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);

    // Start autosave timer (30-second intervals)
    _autosaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_hasUnsavedChanges && !_isSaving && !_isSavingDraft) {
        _performAutosave();
      }
    });

    // Check for existing drafts on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForExistingDrafts();
    });
  }

  /// Called when form content changes
  void _onFormChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  /// Check for existing drafts when loading the form builder
  Future<void> _checkForExistingDrafts() async {
    if (_isEditMode && widget.editFormId != null) {
      // Check if there's a draft for this existing form
      final existingDraft = await _draftService.getDraftForForm(widget.editFormId!);
      if (existingDraft != null && mounted) {
        _showDraftRestoreDialog(existingDraft);
      }
    }
  }

  /// Show dialog to restore from draft
  void _showDraftRestoreDialog(FormDraft draft) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Draft Found',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We found an unsaved draft from ${draft.lastModifiedFormatted}.',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text(
                'Would you like to restore your progress?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _draftService.deleteDraft(draft.id); // Delete the draft
              },
              child: Text(
                'Discard',
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _restoreFromDraft(draft);
              },
              child: Text(
                'Restore',
                style: GoogleFonts.inter(
                  color: const Color(0xff3B82F6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Restore form from draft
  void _restoreFromDraft(FormDraft draft) {
    setState(() {
      _titleController.text = draft.title;
      _descriptionController.text = draft.description;
      
      // Convert draft fields back to FormFieldData objects
      final draftFieldsList = _draftService.convertDraftFieldsToFormFields(draft.fields);
      fields = draftFieldsList.map((fieldData) {
        return FormFieldData(
          id: fieldData['id'],
          type: fieldData['type'],
          label: fieldData['label'],
          placeholder: fieldData['placeholder'],
          required: fieldData['required'],
          order: fieldData['order'],
          options: List<String>.from(fieldData['options'] ?? []),
          additionalConfig: fieldData['additionalConfig'],
          conditionalLogic: fieldData['conditionalLogic'] != null 
              ? ConditionalLogic.fromMap(fieldData['conditionalLogic'])
              : null,
        );
      }).toList();
      
      _currentDraftId = draft.id;
      _hasUnsavedChanges = false;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Draft restored successfully!',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _populateFormForEditing() {
    final data = widget.editFormData!;

    // Populate basic form info
    _titleController.text = data['title'] ?? 'Untitled Form';
    _descriptionController.text = data['description'] ?? '';

    // Populate fields if they exist
    final fieldsData = data['fields'] as Map<String, dynamic>?;
    if (fieldsData != null) {
      List<FormFieldData> loadedFields = [];

      // Sort fields by order
      final sortedEntries = fieldsData.entries.toList()
        ..sort((a, b) {
          final aOrder =
              (a.value as Map<String, dynamic>)['order'] as int? ?? 0;
          final bOrder =
              (b.value as Map<String, dynamic>)['order'] as int? ?? 0;
          return aOrder.compareTo(bOrder);
        });

      for (var entry in sortedEntries) {
        final fieldId = entry.key;
        final fieldData = entry.value as Map<String, dynamic>;

        // Map Firestore field types back to internal types
        String internalType =
            _getInternalFieldType(fieldData['type'] ?? 'text');

        loadedFields.add(FormFieldData(
          id: fieldId,
          type: internalType,
          label: fieldData['label'] ?? 'Field Label',
          placeholder: fieldData['placeholder'] ?? '',
          required: fieldData['required'] ?? false,
          order: fieldData['order'] ?? loadedFields.length,
          options: fieldData['options'] != null
              ? List<String>.from(fieldData['options'])
              : [],
          additionalConfig: fieldData.containsKey('minValue') ||
                  fieldData.containsKey('maxValue')
              ? {
                  if (fieldData['minValue'] != null)
                    'minValue': fieldData['minValue'],
                  if (fieldData['maxValue'] != null)
                    'maxValue': fieldData['maxValue'],
                }
              : null,
          conditionalLogic: fieldData['conditionalLogic'] != null
              ? ConditionalLogic.fromMap(fieldData['conditionalLogic'])
              : null,
        ));
      }

      setState(() {
        fields = loadedFields;
      });
    }
  }

  String _getInternalFieldType(String firestoreType) {
    switch (firestoreType) {
      case 'text':
        return 'openEnded';
      case 'long_text':
        return 'description';
      case 'dropdown':
        return 'dropdown';
      case 'multi_select':
        return 'multiSelect';
      case 'radio':
        return 'yesNo';
      case 'number':
        return 'number';
      case 'date':
        return 'date';
      case 'image_upload':
        return 'imageUpload';
      case 'signature':
        return 'signature';
      default:
        return firestoreType;
    }
  }

  /// Perform autosave in background
  Future<void> _performAutosave() async {
    if (_isSavingDraft || _isSaving) return;

    setState(() {
      _isSavingDraft = true;
    });

    try {
      // Prepare fields data for draft storage
      final fieldsMap = <String, dynamic>{};
      for (var field in fields) {
        fieldsMap[field.id] = {
          'type': field.type,
          'label': field.label,
          'placeholder': field.placeholder,
          'required': field.required,
          'order': field.order,
          if (field.options.isNotEmpty) 'options': field.options,
          if (field.additionalConfig != null) 'additionalConfig': field.additionalConfig,
          if (field.conditionalLogic != null) 'conditionalLogic': field.conditionalLogic!.toMap(),
        };
      }

      // Save draft
      _currentDraftId = await _draftService.saveDraft(
        draftId: _currentDraftId,
        title: _titleController.text.trim().isEmpty ? 'Untitled Form' : _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        fields: fieldsMap,
        originalFormId: _isEditMode ? widget.editFormId : null,
        originalFormData: _isEditMode ? widget.editFormData : null,
      );

      setState(() {
        _hasUnsavedChanges = false;
        _lastAutosaveTime = DateTime.now();
      });

      print('FormBuilder: Autosave completed at ${_lastAutosaveTime}');
    } catch (e) {
      print('FormBuilder: Autosave failed: $e');
    } finally {
      setState(() {
        _isSavingDraft = false;
      });
    }
  }

  /// Manual save progress functionality
  Future<void> _saveProgress() async {
    if (_isSavingDraft || _isSaving) return;

    setState(() {
      _isSavingDraft = true;
    });

    try {
      // Prepare fields data for draft storage
      final fieldsMap = <String, dynamic>{};
      for (var field in fields) {
        fieldsMap[field.id] = {
          'type': field.type,
          'label': field.label,
          'placeholder': field.placeholder,
          'required': field.required,
          'order': field.order,
          if (field.options.isNotEmpty) 'options': field.options,
          if (field.additionalConfig != null) 'additionalConfig': field.additionalConfig,
          if (field.conditionalLogic != null) 'conditionalLogic': field.conditionalLogic!.toMap(),
        };
      }

      // Save draft
      _currentDraftId = await _draftService.saveDraft(
        draftId: _currentDraftId,
        title: _titleController.text.trim().isEmpty ? 'Untitled Form' : _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        fields: fieldsMap,
        originalFormId: _isEditMode ? widget.editFormId : null,
        originalFormData: _isEditMode ? widget.editFormData : null,
      );

      setState(() {
        _hasUnsavedChanges = false;
        _lastAutosaveTime = DateTime.now();
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Progress saved successfully!',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Failed to save progress. Please try again.',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isSavingDraft = false;
      });
    }
  }

  /// Trigger form change detection when fields are modified
  void _markFormAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  /// Get human-readable time ago string
  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _titleController.removeListener(_onFormChanged);
    _descriptionController.removeListener(_onFormChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Row(
              children: [
                // Left Panel - Field Palette & Form Settings
                Container(
                  width: 350,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      right: BorderSide(color: Color(0xffE2E8F0), width: 1),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFormSettings(),
                        const Divider(height: 1, color: Color(0xffE2E8F0)),
                        _buildFieldPalette(),
                      ],
                    ),
                  ),
                ),
                // Right Panel - Form Builder & Preview
                Expanded(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height - 160, // Adjust for header height
                      child: _showPreview ? _buildPreview() : _buildFormBuilder(),
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

  Widget _buildHeader() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xffE2E8F0), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.dynamic_form,
              color: Color(0xff3B82F6),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isEditMode ? 'Edit Form' : 'Form Builder',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
              Row(
                children: [
                  Text(
                    _isEditMode
                        ? 'Modify your existing form'
                        : 'Create dynamic forms with drag & drop',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                  if (_lastAutosaveTime != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.green[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Saved ${_getTimeAgo(_lastAutosaveTime!)}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                  ] else if (_hasUnsavedChanges) ...[
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.edit,
                          size: 14,
                          color: Colors.orange[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Unsaved changes',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.orange[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              if (_isEditMode) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back to Forms'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff6B7280),
                    side: const BorderSide(color: Color(0xffE2E8F0)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showPreview = !_showPreview;
                  });
                },
                icon: Icon(
                  _showPreview ? Icons.edit : Icons.preview,
                  size: 18,
                ),
                label: Text(_showPreview ? 'Edit' : 'Preview'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff6B7280),
                  side: const BorderSide(color: Color(0xffE2E8F0)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              // Save Progress button
              OutlinedButton.icon(
                onPressed: _isSavingDraft ? null : _saveProgress,
                icon: _isSavingDraft
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xff10B981)),
                        ),
                      )
                    : const Icon(Icons.bookmark_outline, size: 18),
                label: Text(_isSavingDraft ? 'Saving...' : 'Save Progress'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff10B981),
                  side: const BorderSide(color: Color(0xff10B981)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveForm,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(_isSaving
                    ? (_isEditMode ? 'Updating...' : 'Saving...')
                    : (_isEditMode ? 'Update Form' : 'Save Form')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormSettings() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Form Settings',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 20),
          _buildStyledTextField(
            controller: _titleController,
            label: 'Form Title',
            hint: 'Enter form title',
            icon: Icons.title,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Title is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildStyledTextField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Describe your form',
            icon: Icons.description,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          onChanged: onChanged,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xff111827),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: const Color(0xff9CA3AF),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              icon,
              color: const Color(0xff6B7280),
              size: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xff3B82F6), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xffF9FAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldPalette() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Field Types',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 400, // Fixed height for the grid
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: fieldTemplates.length,
              itemBuilder: (context, index) {
                final template = fieldTemplates[index];
                return _buildFieldTemplateCard(template);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldTemplateCard(FieldTemplate template) {
    return GestureDetector(
      onTap: () => _addFieldFromTemplate(template),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xffE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: template.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  template.icon,
                  color: template.color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  template.title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff111827),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  template.description,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: const Color(0xff6B7280),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormBuilder() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Form Fields',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${fields.length} fields',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff3B82F6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (fields.isEmpty) _buildEmptyState(),
          if (fields.isNotEmpty)
            Expanded(
              child: ReorderableListView.builder(
                itemCount: fields.length,
                onReorder: _reorderFields,
                itemBuilder: (context, index) {
                  final field = fields[index];
                  return _buildFieldEditor(field, index);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xffF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffE2E8F0)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.dynamic_form,
                    size: 64,
                    color: Color(0xff9CA3AF),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No fields yet',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add fields from the palette to start building your form',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addFieldFromTemplate(FieldTemplate template) {
    setState(() {
      fields.add(FormFieldData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        label: template.title,
        type: template.type,
        placeholder: 'Enter ${template.title.toLowerCase()}...',
        required: false,
        order: fields.length,
        allowMultiple: template.type == 'multiSelect',
      ));
    });
    _markFormAsChanged();
  }

  void _reorderFields(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final field = fields.removeAt(oldIndex);
      fields.insert(newIndex, field);

      // Update order
      for (int i = 0; i < fields.length; i++) {
        fields[i].order = i;
      }
    });
    _markFormAsChanged();
  }

  Widget _buildFieldEditor(FormFieldData field, int index) {
    final template = fieldTemplates.firstWhere(
      (t) => t.type == field.type,
      orElse: () => fieldTemplates.first,
    );

    return Container(
      key: ValueKey(field.id),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: template.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            template.icon,
            color: template.color,
            size: 20,
          ),
        ),
        title: Text(
          field.label.isEmpty ? 'Untitled Field' : field.label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xff111827),
          ),
        ),
        subtitle: Text(
          template.title,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xff6B7280),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (field.required)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xffFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Required',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xffD97706),
                  ),
                ),
              ),
            if (field.conditionalLogic != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xff8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: const Color(0xff8B5CF6).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.alt_route,
                        size: 10, color: Color(0xff8B5CF6)),
                    const SizedBox(width: 2),
                    Text(
                      _getConditionalSummary(field.conditionalLogic!),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff8B5CF6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(width: 8),
            const Icon(
              Icons.drag_handle,
              color: Color(0xff9CA3AF),
              size: 20,
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFieldConfiguration(field),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldConfiguration(FormFieldData field) {
    final labelController = TextEditingController(text: field.label);
    final placeholderController =
        TextEditingController(text: field.placeholder);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStyledTextField(
                controller: labelController,
                label: 'Field Label',
                hint: 'Enter field label',
                icon: Icons.label,
                onChanged: (value) {
                  field.label = value;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStyledTextField(
                controller: placeholderController,
                label: 'Placeholder',
                hint: 'Enter placeholder text',
                icon: Icons.text_format,
                onChanged: (value) {
                  field.placeholder = value;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (field.type == 'dropdown' || field.type == 'multiSelect')
          _buildDropdownOptions(field),
        const SizedBox(height: 16),
        _buildConditionalLogicSection(field),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                title: Text(
                  'Required Field',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: field.required,
                onChanged: (value) {
                  setState(() {
                    field.required = value ?? false;
                  });
                },
                activeColor: const Color(0xff3B82F6),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            IconButton(
              onPressed: () => _removeField(field),
              icon: const Icon(Icons.delete_outline),
              color: const Color(0xffEF4444),
              tooltip: 'Delete field',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownOptions(FormFieldData field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.type == 'multiSelect'
              ? 'Multi-Select Options'
              : 'Dropdown Options',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: field.options.join(', '),
          decoration: InputDecoration(
            hintText: 'Option 1, Option 2, Option 3',
            hintStyle: GoogleFonts.inter(
              color: const Color(0xff9CA3AF),
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.list,
              color: Color(0xff6B7280),
              size: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xff3B82F6), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xffF9FAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (value) {
            field.options = value
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          },
        ),
      ],
    );
  }

  Widget _buildConditionalLogicSection(FormFieldData field) {
    // Get available fields that can be dependencies (only fields that come before this one)
    final availableFields = fields
        .where((f) =>
            f.order < field.order &&
            (f.type == 'yesNo' ||
                f.type == 'dropdown' ||
                f.type == 'multiSelect'))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route, color: Color(0xff8B5CF6), size: 18),
              const SizedBox(width: 8),
              Text(
                'Conditional Logic',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Show or hide this field based on another field\'s answer',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xff6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xff3B82F6).withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: const Color(0xff3B82F6).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 Condition Types for Multi-Select:',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff3B82F6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Contains any of: Show if ANY selected\n'
                  '• Contains all of: Show if ALL are selected\n'
                  '• Contains exactly: Show if ONLY those are selected',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xff3B82F6),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: Text(
              'Enable conditional logic for this field',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            value: field.conditionalLogic != null,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  field.conditionalLogic = ConditionalLogic();
                } else {
                  field.conditionalLogic = null;
                }
              });
            },
            activeColor: const Color(0xff8B5CF6),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (field.conditionalLogic != null) ...[
            const SizedBox(height: 16),
            if (availableFields.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xffFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: const Color(0xffF59E0B).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: Color(0xffF59E0B), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No compatible fields available. Add Yes/No, Dropdown, or Multi-Select fields above this one.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xffD97706),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Text(
                    'Show this field when',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xff374151),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Field dependency dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Depends on field',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xffE2E8F0)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                value: field.conditionalLogic!.dependsOnFieldId,
                items: availableFields
                    .map((f) => DropdownMenuItem(
                          value: f.id,
                          child: Text(
                            f.label.isEmpty ? 'Untitled Field' : f.label,
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    field.conditionalLogic!.dependsOnFieldId = value;
                    field.conditionalLogic!.expectedValue =
                        null; // Reset expected value
                  });
                },
              ),

              if (field.conditionalLogic!.dependsOnFieldId != null) ...[
                const SizedBox(height: 12),
                _buildConditionSelector(field),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildConditionSelector(FormFieldData field) {
    final dependentField = fields.firstWhere(
      (f) => f.id == field.conditionalLogic!.dependsOnFieldId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Condition',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xffE2E8F0)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                value: field.conditionalLogic!.condition,
                items: _getConditionOptions(dependentField.type),
                onChanged: (value) {
                  setState(() {
                    field.conditionalLogic!.condition = value;
                    field.conditionalLogic!.expectedValue =
                        null; // Reset expected value
                  });
                },
              ),
            ),
          ],
        ),
        if (field.conditionalLogic!.condition != null &&
            field.conditionalLogic!.condition != 'is_empty' &&
            field.conditionalLogic!.condition != 'is_not_empty') ...[
          const SizedBox(height: 12),
          _buildExpectedValueInput(field, dependentField),
        ],
      ],
    );
  }

  List<DropdownMenuItem<String>> _getConditionOptions(String fieldType) {
    switch (fieldType) {
      case 'yesNo':
        return [
          DropdownMenuItem(
            value: 'equals',
            child: Text('equals', style: GoogleFonts.inter(fontSize: 13)),
          ),
        ];
      case 'dropdown':
      case 'multiSelect':
        return [
          DropdownMenuItem(
            value: 'equals',
            child: Text('equals', style: GoogleFonts.inter(fontSize: 13)),
          ),
          DropdownMenuItem(
            value: 'not_equals',
            child:
                Text('does not equal', style: GoogleFonts.inter(fontSize: 13)),
          ),
          DropdownMenuItem(
            value: 'contains',
            child:
                Text('contains any of', style: GoogleFonts.inter(fontSize: 13)),
          ),
          DropdownMenuItem(
            value: 'contains_all',
            child:
                Text('contains all of', style: GoogleFonts.inter(fontSize: 13)),
          ),
          DropdownMenuItem(
            value: 'contains_exactly',
            child: Text('contains exactly',
                style: GoogleFonts.inter(fontSize: 13)),
          ),
          DropdownMenuItem(
            value: 'is_empty',
            child: Text('is empty', style: GoogleFonts.inter(fontSize: 13)),
          ),
          DropdownMenuItem(
            value: 'is_not_empty',
            child: Text('is not empty', style: GoogleFonts.inter(fontSize: 13)),
          ),
        ];
      default:
        return [
          DropdownMenuItem(
            value: 'equals',
            child: Text('equals', style: GoogleFonts.inter(fontSize: 13)),
          ),
          DropdownMenuItem(
            value: 'not_equals',
            child:
                Text('does not equal', style: GoogleFonts.inter(fontSize: 13)),
          ),
          DropdownMenuItem(
            value: 'is_empty',
            child: Text('is empty', style: GoogleFonts.inter(fontSize: 13)),
          ),
          DropdownMenuItem(
            value: 'is_not_empty',
            child: Text('is not empty', style: GoogleFonts.inter(fontSize: 13)),
          ),
        ];
    }
  }

  Widget _buildExpectedValueInput(
      FormFieldData field, FormFieldData dependentField) {
    final condition = field.conditionalLogic!.condition;

    if (dependentField.type == 'yesNo') {
      return DropdownButtonFormField<bool>(
        decoration: InputDecoration(
          labelText: 'Expected answer',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xffE2E8F0)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        value: field.conditionalLogic!.expectedValue as bool?,
        items: [
          DropdownMenuItem(
            value: true,
            child: Text('Yes', style: GoogleFonts.inter(fontSize: 13)),
          ),
          DropdownMenuItem(
            value: false,
            child: Text('No', style: GoogleFonts.inter(fontSize: 13)),
          ),
        ],
        onChanged: (value) {
          setState(() {
            field.conditionalLogic!.expectedValue = value;
          });
        },
      );
    } else if (dependentField.type == 'dropdown' ||
        dependentField.type == 'multiSelect') {
      final options = dependentField.options.isEmpty
          ? ['Option 1', 'Option 2', 'Option 3']
          : dependentField.options;

      // For multi-value conditions, show multi-select widget
      if (condition == 'contains_all' ||
          condition == 'contains_exactly' ||
          (condition == 'contains' && dependentField.type == 'multiSelect')) {
        return _buildMultiValueSelector(field, options);
      }

      // For single-value conditions, show dropdown
      return DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Expected value',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xffE2E8F0)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        value: field.conditionalLogic!.expectedValue as String?,
        items: options
            .map((option) => DropdownMenuItem(
                  value: option,
                  child: Text(option, style: GoogleFonts.inter(fontSize: 13)),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            field.conditionalLogic!.expectedValue = value;
            field.conditionalLogic!.expectedValues = null; // Clear multi-values
          });
        },
      );
    }

    // Fallback to text input for other field types
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Expected value',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xffE2E8F0)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      initialValue: field.conditionalLogic!.expectedValue?.toString() ?? '',
      onChanged: (value) {
        field.conditionalLogic!.expectedValue = value;
      },
    );
  }

  Widget _buildMultiValueSelector(FormFieldData field, List<String> options) {
    List<String> selectedValues = field.conditionalLogic!.expectedValues != null
        ? List<String>.from(field.conditionalLogic!.expectedValues!)
        : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select expected values:',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffE2E8F0)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: options.map((option) {
              final isSelected = selectedValues.contains(option);
              return CheckboxListTile(
                title: Text(
                  option,
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      selectedValues.add(option);
                    } else {
                      selectedValues.remove(option);
                    }
                    field.conditionalLogic!.expectedValues =
                        selectedValues.toList();
                    field.conditionalLogic!.expectedValue =
                        null; // Clear single value
                  });
                },
                activeColor: const Color(0xff8B5CF6),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              );
            }).toList(),
          ),
        ),
        if (selectedValues.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: selectedValues.map((value) {
              return Chip(
                label: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff8B5CF6),
                  ),
                ),
                backgroundColor: const Color(0xff8B5CF6).withOpacity(0.1),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() {
                    selectedValues.remove(value);
                    field.conditionalLogic!.expectedValues =
                        selectedValues.toList();
                  });
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPreview() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Form Preview',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_titleController.text.isNotEmpty) ...[
                      Text(
                        _titleController.text,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_descriptionController.text.isNotEmpty) ...[
                      Text(
                        _descriptionController.text,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    ...fields
                        .where((field) => _shouldShowFieldInPreview(field))
                        .map((field) => _buildPreviewField(field)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowFieldInPreview(FormFieldData field) {
    // If no conditional logic, always show
    if (field.conditionalLogic == null) return true;

    final conditionalLogic = field.conditionalLogic!;

    // If no dependency set up yet, show the field
    if (conditionalLogic.dependsOnFieldId == null ||
        conditionalLogic.condition == null) {
      return true;
    }

    // Get the current value of the dependent field
    final dependentValue = _previewValues[conditionalLogic.dependsOnFieldId];

    // Check the condition
    bool conditionMet = false;
    switch (conditionalLogic.condition) {
      case 'equals':
        conditionMet = dependentValue == conditionalLogic.expectedValue;
        break;
      case 'not_equals':
        conditionMet = dependentValue != conditionalLogic.expectedValue;
        break;
      case 'contains':
        if (conditionalLogic.expectedValues != null &&
            conditionalLogic.expectedValues!.isNotEmpty) {
          // Check if dependent value contains ANY of the expected values
          if (dependentValue is List) {
            conditionMet = conditionalLogic.expectedValues!
                .any((expectedVal) => dependentValue.contains(expectedVal));
          }
        } else {
          // Fallback to single value check for backwards compatibility
          if (dependentValue is List) {
            conditionMet =
                dependentValue.contains(conditionalLogic.expectedValue);
          } else if (dependentValue is String) {
            conditionMet = dependentValue
                .contains(conditionalLogic.expectedValue?.toString() ?? '');
          }
        }
        break;
      case 'contains_all':
        if (conditionalLogic.expectedValues != null &&
            conditionalLogic.expectedValues!.isNotEmpty) {
          // Check if dependent value contains ALL of the expected values
          if (dependentValue is List) {
            conditionMet = conditionalLogic.expectedValues!
                .every((expectedVal) => dependentValue.contains(expectedVal));
          }
        }
        break;
      case 'contains_exactly':
        if (conditionalLogic.expectedValues != null &&
            conditionalLogic.expectedValues!.isNotEmpty) {
          // Check if dependent value contains EXACTLY the expected values (same set)
          if (dependentValue is List) {
            final dependentSet = Set.from(dependentValue);
            final expectedSet = Set.from(conditionalLogic.expectedValues!);
            conditionMet = dependentSet.length == expectedSet.length &&
                dependentSet.containsAll(expectedSet);
          }
        }
        break;
      case 'is_empty':
        conditionMet = dependentValue == null ||
            dependentValue == '' ||
            (dependentValue is List && dependentValue.isEmpty);
        break;
      case 'is_not_empty':
        conditionMet = dependentValue != null &&
            dependentValue != '' &&
            !(dependentValue is List && dependentValue.isEmpty);
        break;
      default:
        conditionMet = false;
    }

    // Return whether field should be visible based on condition and isVisible setting
    return conditionalLogic.isVisible ? conditionMet : !conditionMet;
  }

  Widget _buildPreviewField(FormFieldData field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Flexible(
                child: Text(
                  field.label.isEmpty ? 'Untitled Field' : field.label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff374151),
                  ),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
              if (field.required) ...[
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(color: Color(0xffEF4444)),
                ),
              ],
              if (field.conditionalLogic != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xff8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: const Color(0xff8B5CF6).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.alt_route,
                          size: 12, color: Color(0xff8B5CF6)),
                      const SizedBox(width: 4),
                      Text(
                        _getConditionalSummary(field.conditionalLogic!),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff8B5CF6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _buildPreviewFieldWidget(field),
        ],
      ),
    );
  }

  Widget _buildPreviewFieldWidget(FormFieldData field) {
    switch (field.type) {
      case 'dropdown':
        return DropdownButtonFormField<String>(
          decoration: _previewInputDecoration(field.placeholder),
          value: _previewValues[field.id] as String?,
          isExpanded: true, // Allow dropdown to expand to full width
          items: field.options.isEmpty
              ? [
                  const DropdownMenuItem(
                      value: 'Option 1', 
                      child: Text('Option 1', softWrap: true, overflow: TextOverflow.visible))
                ]
              : field.options
                  .map((option) =>
                      DropdownMenuItem(
                        value: option, 
                        child: Text(
                          option,
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        )))
                  .toList(),
          onChanged: (value) {
            setState(() {
              _previewValues[field.id] = value;
            });
          },
        );
      case 'multiSelect':
        return _buildMultiSelectPreview(field);
      case 'yesNo':
        return _buildYesNoPreview(field);
      case 'date':
        return _buildDatePreview(field);
      case 'description':
        return TextFormField(
          decoration: _previewInputDecoration(field.placeholder),
          maxLines: null,
          minLines: 3,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
          ),
          textInputAction: TextInputAction.newline,
        );
      case 'number':
        return TextFormField(
          decoration: _previewInputDecoration(field.placeholder),
          keyboardType: TextInputType.number,
          style: GoogleFonts.inter(fontSize: 14),
        );
      default:
        return TextFormField(
          decoration: _previewInputDecoration(field.placeholder),
          maxLines: null,
          minLines: 1,
          style: GoogleFonts.inter(fontSize: 14),
          textInputAction: TextInputAction.done,
        );
    }
  }

  Widget _buildMultiSelectPreview(FormFieldData field) {
    List<String> selectedValues = _previewValues[field.id] != null
        ? List<String>.from(_previewValues[field.id])
        : [];
    final availableOptions = field.options.isEmpty
        ? ['Option 1', 'Option 2', 'Option 3']
        : field.options;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xff3B82F6), width: 2),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xffF0F9FF),
      ),
      child: Column(
        children: availableOptions.map((option) {
          final isSelected = selectedValues.contains(option);
          return CheckboxListTile(
            title: Text(
              option,
              style: GoogleFonts.inter(fontSize: 14),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  selectedValues.add(option);
                } else {
                  selectedValues.remove(option);
                }
                _previewValues[field.id] = selectedValues;
              });
            },
            activeColor: const Color(0xff3B82F6),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildYesNoPreview(FormFieldData field) {
    return Row(
      children: [
        Radio<bool>(
          value: true,
          groupValue: _previewValues[field.id] as bool?,
          onChanged: (value) {
            setState(() {
              _previewValues[field.id] = value;
            });
          },
        ),
        const Text('Yes'),
        const SizedBox(width: 24),
        Radio<bool>(
          value: false,
          groupValue: _previewValues[field.id] as bool?,
          onChanged: (value) {
            setState(() {
              _previewValues[field.id] = value;
            });
          },
        ),
        const Text('No'),
      ],
    );
  }

  Widget _buildDatePreview(FormFieldData field) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          setState(() {
            _previewValues[field.id] = date.toIso8601String().split('T')[0];
          });
        }
      },
      child: AbsorbPointer(
        child: TextFormField(
          decoration: _previewInputDecoration(field.placeholder).copyWith(
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          controller: TextEditingController(
            text: _previewValues[field.id] ?? 'Select date...',
          ),
        ),
      ),
    );
  }

  InputDecoration _previewInputDecoration(String placeholder) {
    return InputDecoration(
      hintText: placeholder.isEmpty ? 'Enter value...' : placeholder,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffE2E8F0)),
      ),
      filled: true,
      fillColor: const Color(0xffF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  void _removeField(FormFieldData field) {
    setState(() {
      fields.remove(field);
    });
    _markFormAsChanged();
  }

  String _getConditionalSummary(ConditionalLogic logic) {
    if (logic.condition == null) return 'Conditional';

    switch (logic.condition) {
      case 'contains_all':
        return 'All of';
      case 'contains_exactly':
        return 'Exactly';
      case 'contains':
        if (logic.expectedValues != null && logic.expectedValues!.length > 1) {
          return 'Any of';
        }
        return 'Contains';
      default:
        return 'Conditional';
    }
  }

  Future<void> _saveForm() async {
    // First validate the form
    if (!_validateForm()) return;

    // Show user selection dialog (or use existing permissions for edit mode)
    Map<String, dynamic> formPermissions;
    if (_isEditMode && widget.editFormData != null) {
      // For edit mode, get existing permissions or default to public
      formPermissions =
          widget.editFormData!['permissions'] as Map<String, dynamic>? ??
              {'type': 'public'};

      // Still show the dialog to allow changing permissions
      final updatedPermissions = await _showUserSelectionDialog();
      if (updatedPermissions == null) return; // User cancelled
      formPermissions = updatedPermissions;
    } else {
      // For new forms, always show the dialog
      final selectedPermissions = await _showUserSelectionDialog();
      if (selectedPermissions == null) return; // User cancelled
      formPermissions = selectedPermissions;
    }

    // Proceed with saving
    await _saveFormToFirestore(formPermissions);
  }

  Future<Map<String, dynamic>?> _showUserSelectionDialog() async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return UserSelectionDialog(formTitle: _titleController.text.trim());
      },
    );
  }

  Future<void> _saveFormToFirestore(
      Map<String, dynamic> formPermissions) async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Must be logged in');

      // Convert fields to map with correct field type names
      final fieldsMap = <String, dynamic>{};
      for (var field in fields) {
        // Map internal field types to the expected types in forms page
        String fieldType = _getFieldTypeForFirestore(field.type);

        fieldsMap[field.id] = {
          'type': fieldType,
          'label': field.label,
          'placeholder': field.placeholder,
          'required': field.required,
          'order': field.order,
          if (field.options.isNotEmpty) 'options': field.options,
          if (field.additionalConfig != null) ...field.additionalConfig!,
          if (field.conditionalLogic != null)
            'conditionalLogic': field.conditionalLogic!.toMap(),
        };
      }

      if (_isEditMode && widget.editFormId != null) {
        // Update existing form
        await FirebaseFirestore.instance
            .collection('form')
            .doc(widget.editFormId!)
            .update({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
          'fieldCount': fields.length,
          'fields': fieldsMap,
          'permissions': formPermissions,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Form "${_titleController.text.trim()}" updated successfully!'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xff10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Clean up draft after successful update
        if (_currentDraftId != null) {
          try {
            await _draftService.deleteDraft(_currentDraftId!);
            _currentDraftId = null;
            _hasUnsavedChanges = false;
            print('FormBuilder: Draft cleaned up after successful update');
          } catch (e) {
            print('FormBuilder: Failed to clean up draft: $e');
          }
        }
      } else {
        // Create new form
        // Get user info for creator details
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final userData = userDoc.data();
        final creatorName = userData != null
            ? '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                .trim()
            : 'Unknown User';

        await FirebaseFirestore.instance.collection('form').add({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdBy': user.uid,
          'createdByName': creatorName,
          'status': 'active',
          'isPublished': true,
          'fieldCount': fields.length,
          'fields': fieldsMap,
          'responses': {}, // Initialize empty responses object
          'responseCount': 0,
          'permissions': formPermissions, // Add user permissions
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Form "${_titleController.text.trim()}" created successfully!'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xff10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Clean up draft after successful creation
        if (_currentDraftId != null) {
          try {
            await _draftService.deleteDraft(_currentDraftId!);
            _currentDraftId = null;
            print('FormBuilder: Draft cleaned up after successful creation');
          } catch (e) {
            print('FormBuilder: Failed to clean up draft: $e');
          }
        }

        // Clear form after successful save (only for new forms)
        _titleController.clear();
        _descriptionController.clear();
        setState(() {
          fields.clear();
          _previewValues.clear();
          _hasUnsavedChanges = false;
          _lastAutosaveTime = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error ${_isEditMode ? 'updating' : 'saving'} form: $e'),
            backgroundColor: const Color(0xffEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _getFieldTypeForFirestore(String internalType) {
    switch (internalType) {
      case 'openEnded':
        return 'text';
      case 'description':
        return 'long_text';
      case 'dropdown':
        return 'dropdown';
      case 'multiSelect':
        return 'multi_select';
      case 'yesNo':
        return 'radio';
      case 'number':
        return 'number';
      case 'date':
        return 'date';
      case 'imageUpload':
        return 'image_upload';
      case 'signature':
        return 'signature';
      default:
        return internalType;
    }
  }

  bool _validateForm() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Form title is required'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one field to the form'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }
}

class FormFieldData {
  String id;
  String label;
  String type;
  String placeholder;
  bool required;
  int order;
  List<String> options;
  double? minValue;
  double? maxValue;
  bool allowMultiple;
  Map<String, dynamic>? additionalConfig;
  // Add conditional logic support
  ConditionalLogic? conditionalLogic;

  FormFieldData({
    required this.id,
    required this.label,
    required this.type,
    required this.placeholder,
    required this.required,
    required this.order,
    this.options = const [],
    this.minValue,
    this.maxValue,
    this.allowMultiple = false,
    this.additionalConfig,
    this.conditionalLogic,
  });
}

class FieldTemplate {
  final String type;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  FieldTemplate({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class UserSelectionDialog extends StatefulWidget {
  final String formTitle;

  const UserSelectionDialog({super.key, required this.formTitle});

  @override
  State<UserSelectionDialog> createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<UserSelectionDialog> {
  String? selectedRole;
  List<String> selectedUsers = [];
  bool isLoading = false;
  List<Map<String, dynamic>> availableUsers = [];

  final List<Map<String, String>> userRoles = [
    {'id': 'students', 'name': 'Students', 'icon': '🎓'},
    {'id': 'parents', 'name': 'Parents', 'icon': '👨‍👩‍👧‍👦'},
    {'id': 'teachers', 'name': 'Teachers', 'icon': '👩‍🏫'},
    {'id': 'admins', 'name': 'Admins', 'icon': '👨‍💼'},
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildContent(),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xff3B82F6),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.people, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Form Permissions',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Who can fill "${widget.formTitle}"?',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Expanded(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPermissionToggle(),
              if (selectedRole != null) ...[
                const SizedBox(height: 24),
                _buildRoleSelection(),
                const SizedBox(height: 24),
                _buildUserSelection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: Color(0xff3B82F6), size: 20),
              const SizedBox(width: 8),
              Text(
                'Form Access',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'By default, this form is accessible to everyone. You can optionally restrict access to specific user groups.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff6B7280),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Radio<String?>(
                value: null,
                groupValue: selectedRole,
                onChanged: (value) {
                  setState(() {
                    selectedRole = value;
                    selectedUsers.clear();
                  });
                },
                activeColor: const Color(0xff3B82F6),
              ),
              Text(
                'Everyone can access this form',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff111827),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Radio<String?>(
                value: 'restricted',
                groupValue: selectedRole,
                onChanged: (value) {
                  setState(() {
                    selectedRole = value;
                    selectedUsers.clear();
                  });
                },
                activeColor: const Color(0xff3B82F6),
              ),
              Text(
                'Restrict to specific users',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff111827),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select User Group',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: userRoles.map((role) {
            final isSelected = selectedRole == role['id'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedRole = role['id'];
                  selectedUsers.clear();
                });
                _loadUsers(role['id']!);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xff3B82F6) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xff3B82F6)
                        : const Color(0xffE2E8F0),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      role['icon']!,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      role['name']!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color:
                            isSelected ? Colors.white : const Color(0xff111827),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUserSelection() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xff3B82F6)),
      );
    }

    if (availableUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xffF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xffE2E8F0)),
        ),
        child: Center(
          child: Text(
            'No users found in this group',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff6B7280),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Select Users',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  if (selectedUsers.length == availableUsers.length) {
                    selectedUsers.clear();
                  } else {
                    selectedUsers = availableUsers
                        .map((user) => user['id'] as String)
                        .toList();
                  }
                });
              },
              child: Text(
                selectedUsers.length == availableUsers.length
                    ? 'Deselect All'
                    : 'Select All',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xff3B82F6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 150),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableUsers.length,
            itemBuilder: (context, index) {
              final user = availableUsers[index];
              final isSelected = selectedUsers.contains(user['id']);

              return CheckboxListTile(
                title: Text(
                  user['name'] ?? 'Unknown User',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: user['email'] != null
                    ? Text(
                        user['email'],
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xff6B7280),
                        ),
                      )
                    : null,
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      selectedUsers.add(user['id']);
                    } else {
                      selectedUsers.remove(user['id']);
                    }
                  });
                },
                activeColor: const Color(0xff3B82F6),
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xff6B7280),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _canSave() ? _handleSave : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Save Form',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canSave() {
    // Always can save if no restrictions
    if (selectedRole == null) return true;

    // Can save if role is selected and at least one user is selected
    return selectedRole != null && selectedUsers.isNotEmpty;
  }

  void _handleSave() {
    Map<String, dynamic> permissions = {};

    if (selectedRole == null) {
      permissions = {'type': 'public'};
    } else {
      permissions = {
        'type': 'restricted',
        'role': selectedRole,
        'users': selectedUsers,
      };
    }

    Navigator.of(context).pop(permissions);
  }

  Future<void> _loadUsers(String role) async {
    setState(() {
      isLoading = true;
      availableUsers.clear();
    });

    try {
      // Convert role from plural to singular for Firestore query
      String userType;
      switch (role) {
        case 'students':
          userType = 'student';
          break;
        case 'parents':
          userType = 'parent';
          break;
        case 'teachers':
          userType = 'teacher';
          break;
        case 'admins':
          userType = 'admin';
          break;
        default:
          userType = role;
      }

      // Query Firestore for users with the specified user_type
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('user_type', isEqualTo: userType)
          .get();

      List<Map<String, dynamic>> users = [];

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Build user name from first_name and lastName, or use email as fallback
        String displayName = 'Unknown User';
        if (data['first_name'] != null && data['lastName'] != null) {
          displayName = '${data['first_name']} ${data['lastName']}';
        } else if (data['first_name'] != null) {
          displayName = data['first_name'];
        } else if (data['lastName'] != null) {
          displayName = data['lastName'];
        } else if (data['email'] != null) {
          displayName = data['email'].split('@')[0]; // Use email prefix as name
        }

        users.add({
          'id': doc.id,
          'name': displayName,
          'email': data['email'] ?? '',
          'user_type': data['user_type'] ?? '',
          'title': data['title'] ?? '',
        });
      }

      // Sort users alphabetically by name
      users
          .sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

      setState(() {
        availableUsers = users;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        isLoading = false;
      });

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// New class for conditional logic
class ConditionalLogic {
  String? dependsOnFieldId;
  String?
      condition; // 'equals', 'not_equals', 'contains', 'contains_all', 'contains_exactly', 'is_empty', 'is_not_empty'
  dynamic expectedValue; // Single value for backwards compatibility
  List<dynamic>? expectedValues; // Multiple values for new conditions
  bool isVisible; // whether field should be visible when condition is met

  ConditionalLogic({
    this.dependsOnFieldId,
    this.condition,
    this.expectedValue,
    this.expectedValues,
    this.isVisible = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'dependsOnFieldId': dependsOnFieldId,
      'condition': condition,
      'expectedValue': expectedValue,
      'expectedValues': expectedValues,
      'isVisible': isVisible,
    };
  }

  static ConditionalLogic fromMap(Map<String, dynamic> map) {
    return ConditionalLogic(
      dependsOnFieldId: map['dependsOnFieldId'],
      condition: map['condition'],
      expectedValue: map['expectedValue'],
      expectedValues: map['expectedValues'] != null
          ? List<dynamic>.from(map['expectedValues'])
          : null,
      isVisible: map['isVisible'] ?? true,
    );
  }
}
