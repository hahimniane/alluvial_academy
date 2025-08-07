import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../utility_functions/export_helpers.dart';
import '../../../core/services/user_role_service.dart';

class FormResponsesScreen extends StatefulWidget {
  const FormResponsesScreen({super.key});

  @override
  State<FormResponsesScreen> createState() => _FormResponsesScreenState();
}

class _FormResponsesScreenState extends State<FormResponsesScreen> {
  final _searchController = TextEditingController();
  String _selectedFormId = '';
  String _selectedStatus = 'Completed'; // Default to completed only
  String _selectedCreator = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = true;
  String? _userRole;
  String? _userEmail;
  List<QueryDocumentSnapshot> _allResponses = [];
  List<QueryDocumentSnapshot> _filteredResponses = [];
  Map<String, DocumentSnapshot> _formTemplates = {};
  List<String> _selectedUserIds = [];

  // New user search fields
  String? _selectedCreatedByUserId;
  String? _selectedFilledByUserId;
  List<Map<String, dynamic>> _allUsers = [];
  bool _loadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final role = await UserRoleService.getCurrentUserRole();

      setState(() {
        _userRole = role;
        _userEmail = user.email;
      });

      _loadFormResponses();
      _loadAllUsers();
    } catch (e) {
      print('Error loading user data: $e');
      _loadFormResponses(); // Load responses anyway
      _loadAllUsers();
    }
  }

  Future<void> _loadAllUsers() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('first_name')
          .get();

      setState(() {
        _allUsers = usersSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name':
                '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim(),
            'email': data['email'] ?? '',
            'role': data['user_type'] ?? '',
          };
        }).toList();
        _loadingUsers = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _loadingUsers = false);
    }
  }

  Future<void> _loadFormResponses() async {
    setState(() => _isLoading = true);
    try {
      // Load form templates first
      final formTemplatesSnapshot = await FirebaseFirestore.instance
          .collection('form')
          .where('status', isEqualTo: 'active')
          .get();

      _formTemplates = {
        for (var doc in formTemplatesSnapshot.docs) doc.id: doc,
      };

      // Load form responses - build query properly to avoid index issues
      Query query = FirebaseFirestore.instance.collection('form_responses');

      // If not admin, only show user's own responses
      if (_userRole != 'admin' && _userEmail != null) {
        query = query
            .where('userEmail', isEqualTo: _userEmail)
            .orderBy('submittedAt', descending: true);
      } else {
        query = query.orderBy('submittedAt', descending: true);
      }

      final responsesSnapshot = await query.get();

      setState(() {
        _allResponses = responsesSnapshot.docs;
        _filteredResponses = _allResponses;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading form responses: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterResponses() {
    setState(() {
      _filteredResponses = _allResponses.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        bool matchesSearch = true;
        bool matchesForm = true;
        bool matchesStatus = true;
        bool matchesDate = true;
        bool matchesCreator = true;
        bool matchesUsers = true;

        // Enhanced search filter
        if (_searchController.text.isNotEmpty) {
          final searchTerm = _searchController.text.toLowerCase();
          final firstName =
              data['userFirstName']?.toString().toLowerCase() ?? '';
          final lastName = data['userLastName']?.toString().toLowerCase() ?? '';
          final email = data['userEmail']?.toString().toLowerCase() ?? '';
          final formId = data['formId'] as String? ?? '';
          final formTemplate = _formTemplates[formId];
          final formTitle = formTemplate != null
              ? (formTemplate.data() as Map<String, dynamic>)['title']
                      ?.toString()
                      .toLowerCase() ??
                  ''
              : '';

          // Search in multiple fields
          matchesSearch = email.contains(searchTerm) ||
              firstName.contains(searchTerm) ||
              lastName.contains(searchTerm) ||
              '$firstName $lastName'.contains(searchTerm) ||
              formTitle.contains(searchTerm) ||
              // Search in form responses
              _searchInFormResponses(
                  data['responses'] as Map<String, dynamic>?, searchTerm);
        }

        // Form filter
        if (_selectedFormId.isNotEmpty) {
          matchesForm = data['formId'] == _selectedFormId;
        }

        // Status filter
        if (_selectedStatus != 'All') {
          matchesStatus = data['status'] == _selectedStatus.toLowerCase();
        }

        // Date filter
        if (_startDate != null || _endDate != null) {
          final submittedAt = (data['submittedAt'] as Timestamp).toDate();
          if (_startDate != null && submittedAt.isBefore(_startDate!)) {
            matchesDate = false;
          }
          if (_endDate != null &&
              submittedAt.isAfter(_endDate!.add(const Duration(days: 1)))) {
            matchesDate = false;
          }
        }

        // Creator filter (legacy - keeping for backward compatibility)
        if (_selectedCreator != 'All') {
          final formId = data['formId'] as String;
          final formTemplate = _formTemplates[formId];
          if (formTemplate != null) {
            final formData = formTemplate.data() as Map<String, dynamic>;
            final createdBy = formData['createdBy'] as String?;
            matchesCreator = _selectedCreator == 'Admin'
                ? (formData['createdByRole'] == 'admin')
                : (data['userEmail'] == createdBy);
          } else {
            matchesCreator = false;
          }
        }

        // Forms Created By filter (new)
        bool matchesCreatedBy = true;
        if (_selectedCreatedByUserId != null) {
          final formId = data['formId'] as String;
          final formTemplate = _formTemplates[formId];
          if (formTemplate != null) {
            final formData = formTemplate.data() as Map<String, dynamic>;
            final createdBy = formData['createdBy'] as String?;
            matchesCreatedBy = createdBy == _selectedCreatedByUserId;
          } else {
            matchesCreatedBy = false;
          }
        }

        // Forms Filled By filter (new)
        bool matchesFilledBy = true;
        if (_selectedFilledByUserId != null) {
          final userId = data['userId'] as String?;
          matchesFilledBy = userId == _selectedFilledByUserId;
        }

        // User filter (legacy - keeping for backward compatibility)
        if (_selectedUserIds.isNotEmpty) {
          matchesUsers = _selectedUserIds.contains(data['userId']);
        }

        return matchesSearch &&
            matchesForm &&
            matchesStatus &&
            matchesDate &&
            matchesCreator &&
            matchesCreatedBy &&
            matchesFilledBy &&
            matchesUsers;
      }).toList();
    });
  }

  void _exportResponses() {
    if (_filteredResponses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No form responses to export. Please adjust your filters.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Build comprehensive headers
    final headers = [
      'Form ID',
      'Form Name',
      'Form Created By (Name)',
      'Form Created By (Email)',
      'Form Created By (Role)',
      'Form Creation Date',
      'Response ID',
      'Submitted By (Name)',
      'Submitted By (Email)',
      'Submitted By (Role)',
      'Submission Date',
      'Response Status',
      'Processing Time (Days)',
    ];

    // Get all unique field labels from all forms being exported
    final allFieldLabels = <String>{};
    final formFieldsMap = <String, List<String>>{};

    for (final response in _filteredResponses) {
      final data = response.data() as Map<String, dynamic>;
      final formId = data['formId'] as String;
      final formTemplate = _formTemplates[formId];

      if (formTemplate != null && !formFieldsMap.containsKey(formId)) {
        final fieldLabels = _getFieldLabels(formTemplate);
        formFieldsMap[formId] = fieldLabels;
        allFieldLabels.addAll(fieldLabels);
      }
    }

    // Add field headers
    headers.addAll(allFieldLabels.toList()..sort());

    final data = _filteredResponses.map((doc) {
      final response = doc.data() as Map<String, dynamic>;
      final formTemplate = _formTemplates[response['formId']];
      final submittedAt = (response['submittedAt'] as Timestamp).toDate();

      // Get form creator info
      final formData = formTemplate?.data() as Map<String, dynamic>?;
      final createdBy = formData?['createdBy'] as String?;
      final formCreatedAt = formData?['createdAt'] as Timestamp?;
      final creatorInfo = _getUserInfoById(createdBy);

      // Get submitter info
      final submitterId = response['userId'] as String?;
      final submitterInfo = _getUserInfoById(submitterId);

      // Calculate processing time
      final processingDays = formCreatedAt != null
          ? submittedAt.difference(formCreatedAt.toDate()).inDays
          : 0;

      final List<String> row = [
        response['formId']?.toString() ?? '',
        formTemplate?['title']?.toString() ?? 'Unknown Form',
        creatorInfo['name'] ?? 'Unknown Creator',
        creatorInfo['email'] ?? '',
        creatorInfo['role'] ?? '',
        formCreatedAt?.toDate().toLocal().toString() ?? '',
        doc.id,
        submitterInfo['name'] ??
            '${response['userFirstName'] ?? ''} ${response['userLastName'] ?? ''}'
                .trim(),
        response['userEmail']?.toString() ?? 'Unknown User',
        submitterInfo['role'] ?? '',
        submittedAt.toLocal().toString(),
        response['status']?.toString() ?? 'unknown',
        processingDays.toString(),
      ];

      // Add response values for all possible fields
      final responseValues =
          response['responses'] as Map<String, dynamic>? ?? {};
      final formFieldLabels = formFieldsMap[response['formId']] ?? [];

      for (final fieldLabel in allFieldLabels.toList()..sort()) {
        if (formTemplate != null && formFieldLabels.contains(fieldLabel)) {
          // This form has this field, get the value
          final fieldValue =
              _getFieldValueByLabel(responseValues, formTemplate, fieldLabel);
          row.add(fieldValue);
        } else {
          // This form doesn't have this field
          row.add('N/A (Field not in this form)');
        }
      }

      return row;
    }).toList();

    // Generate filename with filter info
    String filename = 'form_responses_export';
    if (_selectedCreatedByUserId != null) {
      final creatorName =
          _getUserNameById(_selectedCreatedByUserId!)?.replaceAll(' ', '_') ??
              'unknown';
      filename += '_created_by_$creatorName';
    }
    if (_selectedFilledByUserId != null) {
      final fillerName =
          _getUserNameById(_selectedFilledByUserId!)?.replaceAll(' ', '_') ??
              'unknown';
      filename += '_filled_by_$fillerName';
    }
    filename += '_${DateTime.now().millisecondsSinceEpoch}';

    ExportHelpers.showExportDialog(
      context,
      headers.cast<String>(),
      data.map((row) => row.cast<String>()).toList(),
      filename,
    );
  }

  List<String> _getFieldLabels(DocumentSnapshot formTemplate) {
    final fields = (formTemplate.data() as Map<String, dynamic>)['fields']
        as Map<String, dynamic>;
    return fields.values
        .map((field) => (field as Map<String, dynamic>)['label'].toString())
        .toList();
  }

  void _viewResponse(QueryDocumentSnapshot response) {
    final data = response.data() as Map<String, dynamic>;
    final formTemplate = _formTemplates[data['formId']];
    if (formTemplate == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 800,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xff0386FF),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formTemplate['title'] ?? 'Form Response',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Submitted by ${data['userFirstName'] ?? ''} ${data['userLastName'] ?? ''}'
                                    .trim() +
                                ' (${data['userEmail']}) on ${(data['submittedAt'] as Timestamp).toDate().toLocal()}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Response content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._buildResponseFields(
                        Map<String, dynamic>.from(data['responses'] as Map),
                        formTemplate,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildResponseFields(
    Map<String, dynamic> responses,
    DocumentSnapshot formTemplate,
  ) {
    final fields = Map<String, dynamic>.from(
      (formTemplate.data() as Map<String, dynamic>)['fields'] as Map,
    );
    final widgets = <Widget>[];

    for (final entry in fields.entries) {
      final fieldId = entry.key;
      final fieldData = Map<String, dynamic>.from(entry.value as Map);
      final response = responses[fieldId];

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fieldData['label'] ?? 'Untitled Field',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
              ),
              const SizedBox(height: 8),
              if (response == null)
                Text(
                  'No response',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff6B7280),
                    fontStyle: FontStyle.italic,
                  ),
                )
              else if (response is Map)
                _buildImagePreview(Map<String, dynamic>.from(response))
              else if (response is List)
                Text(
                  response.join(', '),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff111827),
                  ),
                )
              else
                Text(
                  response.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff111827),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildImagePreview(Map<String, dynamic> imageData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffE5E7EB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageData['downloadURL'],
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xffF3F4F6),
                child: const Icon(
                  Icons.error_outline,
                  color: Color(0xffEF4444),
                  size: 48,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            // Open image in new tab
            final url = imageData['downloadURL'];
            html.window.open(url.toString(), '_blank');
          },
          icon: const Icon(Icons.download),
          label: const Text('Download Image'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      body: Column(
        children: [
          // Enhanced Header Section
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff0386FF), Color(0xff1E3A8A)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.assignment_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Form Responses Dashboard',
                                style: GoogleFonts.inter(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${_filteredResponses.length} of ${_allResponses.length} responses',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                  if (_filteredResponses.length !=
                                      _allResponses.length)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Filtered',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _exportResponses,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.file_download_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Export',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
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

          // Enhanced Filter Section
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xffE2E8F0)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildEnhancedFilterBar(),
            ),
          ),

          // Main Content Area
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xff0386FF),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading responses...',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: const Color(0xff6B7280),
                          ),
                        ),
                      ],
                    ),
                  )
                : _filteredResponses.isEmpty
                    ? _buildEmptyState()
                    : _buildResponsesGrid(),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xff10B981);
      case 'draft':
        return const Color(0xff6B7280);
      case 'pending':
        return const Color(0xffF59E0B);
      default:
        return const Color(0xff6B7280);
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0);

    final DateTimeRange? result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: currentMonthStart,
              end: currentMonthEnd,
            ),
      currentDate: now,
      helpText: 'Select Date Range for Form Responses',
      cancelText: 'Cancel',
      confirmText: 'Apply Filter',
      saveText: 'Apply',
      builder: (context, child) {
        return Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 400,
                maxHeight: 800,
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: const Color(0xff0386FF),
                      ),
                ),
                child: child!,
              ),
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
        _filterResponses();
      });
    }
  }

  Widget _buildEnhancedFilterBar() {
    return Column(
      children: [
        // Search and quick filters row
        Row(
          children: [
            // Enhanced search
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xffF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, or form title...',
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.search,
                        size: 20,
                        color: Color(0xff6B7280),
                      ),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _filterResponses();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  onChanged: (value) => _filterResponses(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Form dropdown
            Expanded(
              child: _buildFilterDropdown(
                value: _selectedFormId.isEmpty ? null : _selectedFormId,
                hint: 'All Forms',
                items: [
                  const DropdownMenuItem(value: '', child: Text('All Forms')),
                  ..._formTemplates.entries.map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        entry.value['title'] ?? 'Untitled Form',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedFormId = value ?? '';
                    _filterResponses();
                  });
                },
                icon: Icons.description_outlined,
              ),
            ),
            const SizedBox(width: 16),
            // Status dropdown
            Expanded(
              child: _buildFilterDropdown(
                value: _selectedStatus,
                hint: 'Status',
                items: const [
                  DropdownMenuItem(
                      value: 'Completed', child: Text('✅ Completed Only')),
                  DropdownMenuItem(value: 'All', child: Text('All Status')),
                  DropdownMenuItem(value: 'Draft', child: Text('📝 Draft')),
                  DropdownMenuItem(value: 'Pending', child: Text('⏳ Pending')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value ?? 'Completed';
                    _filterResponses();
                  });
                },
                icon: Icons.flag_outlined,
              ),
            ),
            const SizedBox(width: 16),
            // Date range picker
            _buildDateRangeButton(),
          ],
        ),
        const SizedBox(height: 16),
        // Additional filters row
        Row(
          children: [
            // Forms Created By dropdown
            Expanded(
              child: _buildUserFilterDropdown(
                value: _selectedCreatedByUserId,
                hint: 'Forms Created By',
                icon: Icons.create_outlined,
                onChanged: (value) {
                  setState(() {
                    _selectedCreatedByUserId = value;
                    _filterResponses();
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            // Forms Filled By dropdown
            Expanded(
              child: _buildUserFilterDropdown(
                value: _selectedFilledByUserId,
                hint: 'Forms Filled By',
                icon: Icons.edit_outlined,
                onChanged: (value) {
                  setState(() {
                    _selectedFilledByUserId = value;
                    _filterResponses();
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            // Clear filters button
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xffE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _clearAllFilters,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.clear_all,
                          size: 18,
                          color: Color(0xff6B7280),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Clear Filters',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xff6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            // Results count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xff0386FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_filteredResponses.length} results',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff0386FF),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xff6B7280)),
              const SizedBox(width: 8),
              Text(
                hint,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xff6B7280),
                ),
              ),
            ],
          ),
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xff6B7280)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildUserFilterDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: value != null
            ? const Color(0xff0386FF).withOpacity(0.1)
            : const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              value != null ? const Color(0xff0386FF) : const Color(0xffE2E8F0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showUserSelectionDialog(hint, icon, value, onChanged),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: value != null
                      ? const Color(0xff0386FF)
                      : const Color(0xff6B7280),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value != null
                        ? _getUserNameById(value) ?? 'Unknown User'
                        : hint,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: value != null
                          ? const Color(0xff0386FF)
                          : const Color(0xff6B7280),
                      fontWeight:
                          value != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (value != null)
                  GestureDetector(
                    onTap: () => onChanged(null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Color(0xff6B7280),
                      ),
                    ),
                  )
                else
                  const Icon(Icons.search, color: Color(0xff6B7280)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeButton() {
    return Container(
      decoration: BoxDecoration(
        color: _startDate != null && _endDate != null
            ? const Color(0xff0386FF).withOpacity(0.1)
            : const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _startDate != null && _endDate != null
              ? const Color(0xff0386FF)
              : const Color(0xffE2E8F0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectDateRange(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: _startDate != null && _endDate != null
                      ? const Color(0xff0386FF)
                      : const Color(0xff6B7280),
                ),
                const SizedBox(width: 8),
                Text(
                  _startDate != null && _endDate != null
                      ? '${_startDate!.toLocal().toString().split(' ')[0]} - ${_endDate!.toLocal().toString().split(' ')[0]}'
                      : 'Date Range',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _startDate != null && _endDate != null
                        ? const Color(0xff0386FF)
                        : const Color(0xff6B7280),
                  ),
                ),
                if (_startDate != null && _endDate != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                        _filterResponses();
                      });
                    },
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xff6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xff0386FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 64,
                color: Color(0xff0386FF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No responses found',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no form responses matching your current filters.',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xff6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _clearAllFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear All Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsesGrid() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 3 : 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 1.5,
        ),
        itemCount: _filteredResponses.length,
        itemBuilder: (context, index) {
          final response = _filteredResponses[index];
          final data = response.data() as Map<String, dynamic>;
          final formTemplate = _formTemplates[data['formId']];
          final submittedAt = (data['submittedAt'] as Timestamp).toDate();

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _viewResponse(response),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with status
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formTemplate?['title'] ?? 'Unknown Form',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xff111827),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _getStatusColor(data['status'] ?? 'unknown'),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              data['status']?.toString().toUpperCase() ??
                                  'UNKNOWN',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // User info
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xff0386FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              size: 16,
                              color: Color(0xff0386FF),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${data['userFirstName'] ?? ''} ${data['userLastName'] ?? ''}'
                                      .trim(),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xff111827),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  data['userEmail'] ?? 'Unknown User',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xff6B7280),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Date and actions
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatDateTime(submittedAt),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xff6B7280),
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xff0386FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 18,
                                color: Color(0xff0386FF),
                              ),
                              onPressed: () => _viewResponse(response),
                              tooltip: 'View Details',
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
        },
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _selectedFormId = '';
      _selectedStatus = 'Completed'; // Keep default as completed
      _selectedCreator = 'All';
      _startDate = null;
      _endDate = null;
      _selectedUserIds.clear();
      _selectedCreatedByUserId = null;
      _selectedFilledByUserId = null;
      _filterResponses();
    });
  }

  String? _getUserNameById(String userId) {
    try {
      final user = _allUsers.firstWhere((user) => user['id'] == userId);
      return user['name'];
    } catch (e) {
      return null;
    }
  }

  Map<String, String> _getUserInfoById(String? userId) {
    if (userId == null) {
      return {'name': '', 'email': '', 'role': ''};
    }

    try {
      final user = _allUsers.firstWhere((user) => user['id'] == userId);
      return {
        'name': user['name'] ?? '',
        'email': user['email'] ?? '',
        'role': user['role'] ?? '',
      };
    } catch (e) {
      return {'name': '', 'email': '', 'role': ''};
    }
  }

  String _getFieldValueByLabel(Map<String, dynamic> responses,
      DocumentSnapshot formTemplate, String targetLabel) {
    final fields = (formTemplate.data() as Map<String, dynamic>)['fields']
        as Map<String, dynamic>;

    for (final entry in fields.entries) {
      final fieldData = entry.value as Map<String, dynamic>;
      final fieldLabel = fieldData['label']?.toString() ?? '';

      if (fieldLabel == targetLabel) {
        final value = responses[entry.key];
        if (value == null) return '';
        if (value is List) return value.map((e) => e.toString()).join(', ');
        if (value is Map && value['downloadURL'] != null) {
          return '${value['downloadURL']} (${value['fileName'] ?? 'file'})';
        }
        return value.toString();
      }
    }

    return '';
  }

  bool _searchInFormResponses(
      Map<String, dynamic>? responses, String searchTerm) {
    if (responses == null) return false;

    for (final value in responses.values) {
      if (value == null) continue;

      String searchableText = '';
      if (value is String) {
        searchableText = value.toLowerCase();
      } else if (value is List) {
        searchableText = value.map((e) => e.toString()).join(' ').toLowerCase();
      } else if (value is Map && value['downloadURL'] != null) {
        // For file uploads, search in filename if available
        searchableText = value['fileName']?.toString().toLowerCase() ?? '';
      } else {
        searchableText = value.toString().toLowerCase();
      }

      if (searchableText.contains(searchTerm)) {
        return true;
      }
    }
    return false;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  void _showUserSelectionDialog(String title, IconData icon,
      String? currentValue, void Function(String?) onChanged) {
    showDialog(
      context: context,
      builder: (context) => _UserSelectionDialog(
        title: title,
        icon: icon,
        users: _allUsers,
        currentValue: currentValue,
        onChanged: onChanged,
        isLoading: _loadingUsers,
      ),
    );
  }

  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _UserSelectionDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> users;
  final String? currentValue;
  final void Function(String?) onChanged;
  final bool isLoading;

  const _UserSelectionDialog({
    required this.title,
    required this.icon,
    required this.users,
    required this.currentValue,
    required this.onChanged,
    required this.isLoading,
  });

  @override
  State<_UserSelectionDialog> createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<_UserSelectionDialog> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _filteredUsers = widget.users;
    _searchController.addListener(_filterUsers);
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = widget.users;
      } else {
        _filteredUsers = widget.users.where((user) {
          final name = user['name']?.toString().toLowerCase() ?? '';
          final email = user['email']?.toString().toLowerCase() ?? '';
          final role = user['role']?.toString().toLowerCase() ?? '';
          return name.contains(query) ||
              email.contains(query) ||
              role.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        height: 600,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xff0386FF),
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
                    child: Icon(widget.icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search users by name, email, or role...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xffF8FAFC),
                ),
              ),
            ),

            // Clear Selection Option
            if (widget.currentValue != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      widget.onChanged(null);
                      Navigator.of(context).pop();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.clear, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Clear Selection',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Users List
            Expanded(
              child: widget.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No users found',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your search terms',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            final isSelected =
                                user['id'] == widget.currentValue;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xff0386FF).withOpacity(0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xff0386FF)
                                      : const Color(0xffE2E8F0),
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    widget.onChanged(user['id']);
                                    Navigator.of(context).pop();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xff0386FF)
                                                : const Color(0xff0386FF)
                                                    .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            size: 16,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xff0386FF),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user['name'] ?? 'Unknown',
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected
                                                      ? const Color(0xff0386FF)
                                                      : const Color(0xff111827),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                user['email'] ?? '',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color:
                                                      const Color(0xff6B7280),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xff6B7280)
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  user['role']
                                                          ?.toString()
                                                          .toUpperCase() ??
                                                      '',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        const Color(0xff6B7280),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
                                            color: Color(0xff0386FF),
                                            size: 24,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
