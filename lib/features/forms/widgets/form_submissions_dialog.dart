import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FormSubmissionsDialog extends StatefulWidget {
  final String formId;
  final String formTitle;

  const FormSubmissionsDialog(
      {super.key, required this.formId, required this.formTitle});

  @override
  State<FormSubmissionsDialog> createState() => _FormSubmissionsDialogState();
}

class _FormSubmissionsDialogState extends State<FormSubmissionsDialog>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _template = {};
  List<QueryDocumentSnapshot> _submissions = [];
  DateTimeRange? _dateRange;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  final Map<String, TextEditingController> _notesControllers = {};
  final Map<String, bool> _editingNotes = {};
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  int _rowsPerPage = 10;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Initialize date range to last 30 days
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    for (final controller in _notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final templateDoc = await FirebaseFirestore.instance
          .collection('form')
          .doc(widget.formId)
          .get();
      final fieldsMap =
          (templateDoc.data()?['fields'] as Map?)?.cast<String, dynamic>() ??
              {};

      Query q = FirebaseFirestore.instance
          .collection('form_responses')
          .where('formId', isEqualTo: widget.formId)
          .orderBy('submittedAt', descending: false);

      // Apply date filter if range is set
      if (_dateRange != null) {
        q = q
            .where('submittedAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(_dateRange!.start))
            .where('submittedAt',
                isLessThanOrEqualTo: Timestamp.fromDate(_dateRange!.end));
      }

      final snap = await q.get();

      if (!mounted) return;
      setState(() {
        _template = {'fields': fieldsMap};
        _submissions = snap.docs;
        // Initialize notes controllers for each submission
        for (final doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final note = (data['adminNote'] ?? '').toString();
          _notesControllers[doc.id] = TextEditingController(text: note);
          _editingNotes[doc.id] = false;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              onSurface: Color(0xFF111827),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
      });
      _load(); // Reload data with new date range
    }
  }

  Future<void> _saveNote(String docId, String note) async {
    try {
      await FirebaseFirestore.instance
          .collection('form_responses')
          .doc(docId)
          .update({'adminNote': note});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note saved successfully'),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<String> get _fieldOrder {
    final fields = (_template['fields'] as Map<String, dynamic>?) ?? {};
    final entries = fields.entries.toList();
    entries.sort((a, b) => ((a.value['order'] ?? 0) as int)
        .compareTo((b.value['order'] ?? 0) as int));
    return entries.map((e) => e.key).toList();
  }

  String _labelFor(String fieldId) {
    final fields = (_template['fields'] as Map<String, dynamic>?) ?? {};
    return (fields[fieldId]?['label'] ?? fieldId).toString();
  }

  List<QueryDocumentSnapshot> get _filteredSubmissions {
    if (_searchQuery.isEmpty) return _submissions;

    return _submissions.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name =
          '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
      final email = (data['userEmail'] ?? '').toString();
      final responses =
          (data['responses'] as Map?)?.cast<String, dynamic>() ?? {};

      return name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          responses.values.any((value) => value
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()));
    }).toList();
  }

  List<QueryDocumentSnapshot> get _paginatedSubmissions {
    final filtered = _filteredSubmissions;
    final start = _currentPage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, filtered.length);
    return filtered.sublist(start.clamp(0, filtered.length), end);
  }

  String get _dateRangeText {
    if (_dateRange == null) return 'Select dates';
    final start = _dateRange!.start;
    final end = _dateRange!.end;
    return '${start.month.toString().padLeft(2, '0')}/${start.day.toString().padLeft(2, '0')} - ${end.month.toString().padLeft(2, '0')}/${end.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: MediaQuery.of(context).size.width - 250,
          height: MediaQuery.of(context).size.height,
          color: const Color(0xFFF9FAFB),
          child: Column(
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined,
                        color: Color(0xFF6B7280), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.formTitle,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Published',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Settings',
                          style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),

              // Tabs
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF2563EB),
                  indicatorWeight: 2,
                  labelColor: const Color(0xFF2563EB),
                  unselectedLabelColor: const Color(0xFF6B7280),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: 'Submissions'),
                    Tab(text: 'Users'),
                    Tab(text: 'Summary'),
                    Tab(text: 'Activity'),
                  ],
                ),
              ),

              // Toolbar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Date range selector
                        InkWell(
                          onTap: _selectDateRange,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: const Color(0xFFD1D5DB)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    color: Color(0xFF6B7280), size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  _dateRangeText,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF374151),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_drop_down,
                                    color: Color(0xFF6B7280), size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Submissions count
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_filteredSubmissions.length} submissions',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Search field
                        Container(
                          width: 300,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              if (mounted) {
                                setState(() {
                                  _searchQuery = value;
                                  _currentPage =
                                      0; // Reset to first page on search
                                });
                              }
                            },
                            style: GoogleFonts.inter(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF9CA3AF),
                              ),
                              prefixIcon: const Icon(Icons.search,
                                  color: Color(0xFF6B7280), size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Table
              Expanded(
                child: _isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF2563EB)))
                    : _buildTable(),
              ),

              // Pagination
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _currentPage > 0
                              ? () {
                                  setState(() => _currentPage--);
                                }
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          'Page ${_currentPage + 1} of ${(_filteredSubmissions.length / _rowsPerPage).ceil() == 0 ? 1 : (_filteredSubmissions.length / _rowsPerPage).ceil()}',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: const Color(0xFF6B7280)),
                        ),
                        IconButton(
                          onPressed: (_currentPage + 1) * _rowsPerPage <
                                  _filteredSubmissions.length
                              ? () {
                                  setState(() => _currentPage++);
                                }
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Rows per page:',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: const Color(0xFF6B7280)),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: _rowsPerPage,
                          items: [10, 25, 50]
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e.toString()),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _rowsPerPage = value;
                                _currentPage = 0;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable() {
    final fieldIds = _fieldOrder;
    final tableWidth = _calculateTableWidth(fieldIds);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  // Table header
                  Container(
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      border:
                          Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    child: _buildTableHeader(fieldIds),
                  ),

                  // Table body
                  Expanded(
                    child: Scrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        scrollDirection: Axis.vertical,
                        child: Column(
                          children: _paginatedSubmissions
                              .asMap()
                              .entries
                              .map((entry) {
                            final globalIndex =
                                (_currentPage * _rowsPerPage) + entry.key;
                            final doc = entry.value;
                            final data = doc.data() as Map<String, dynamic>;
                            return _buildTableRow(
                                doc.id, data, globalIndex + 1, fieldIds);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _calculateTableWidth(List<String> fieldIds) {
    // Calculate total width: checkbox(48) + #(60) + user(220) + dynamic fields + notes(200) + actions(120) + padding(16)
    double width = 48 + 60 + 220 + 16; // checkbox + number + user + padding

    // Add separators: 5 base separators (after checkbox, #, user, notes, actions) + 1 per field
    final separatorCount = 5 + fieldIds.length;
    width += separatorCount * 17; // Each separator is 1px + 16px margin

    // Add dynamic field columns
    for (final fieldId in fieldIds) {
      final label = _labelFor(fieldId);
      // Adjust width based on field type/label
      if (label.toLowerCase().contains('date')) {
        width += 140;
      } else if (label.toLowerCase().contains('email')) {
        width += 200;
      } else {
        width += 180;
      }
    }

    width += 200; // Notes column
    width += 120; // Actions column

    // Ensure minimum width
    final screenWidth = MediaQuery.of(context).size.width -
        250 -
        48; // Account for sidebar and margins (increased for safety)
    return width < screenWidth ? screenWidth : width;
  }

  Widget _buildColumnSeparator() {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFFE5E7EB),
    );
  }

  Widget _buildTableHeader(List<String> fieldIds) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Checkbox
          SizedBox(
            width: 48,
            child: Checkbox(
              value: false,
              onChanged: (bool? value) {},
              activeColor: const Color(0xFF2563EB),
            ),
          ),

          _buildColumnSeparator(),

          // # Column
          SizedBox(
            width: 60,
            child: Text(
              '#',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),

          _buildColumnSeparator(),

          // User Column
          SizedBox(
            width: 220,
            child: Text(
              'User',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),

          _buildColumnSeparator(),

          // Dynamic field columns
          ...fieldIds.expand((fieldId) {
            final label = _labelFor(fieldId);
            double width = 180;
            if (label.toLowerCase().contains('date')) width = 140;
            if (label.toLowerCase().contains('email')) width = 200;

            return [
              SizedBox(
                width: width,
                child: Tooltip(
                  message: label,
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              _buildColumnSeparator(),
            ];
          }),

          // Notes Column
          SizedBox(
            width: 200,
            child: Text(
              'Notes',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),

          _buildColumnSeparator(),

          // Actions Column
          SizedBox(
            width: 120,
            child: Text(
              'Actions',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(String docId, Map<String, dynamic> data, int rowNumber,
      List<String> fieldIds) {
    final responses =
        (data['responses'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
    final email = (data['userEmail'] ?? '').toString();
    final displayName = name.isNotEmpty ? name : email;
    final isEditing = _editingNotes[docId] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: rowNumber % 2 == 0 ? Colors.white : const Color(0xFFFAFBFC),
        border: const Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
      ),
      child: InkWell(
        onTap: () {},
        hoverColor: const Color(0xFFF3F4F6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              // Checkbox
              SizedBox(
                width: 48,
                child: Checkbox(
                  value: false,
                  onChanged: (bool? value) {},
                  activeColor: const Color(0xFF2563EB),
                ),
              ),

              _buildColumnSeparator(),

              // Row number
              SizedBox(
                width: 60,
                child: Text(
                  rowNumber.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),

              _buildColumnSeparator(),

              // User with avatar
              SizedBox(
                width: 220,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _getAvatarColor(displayName),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF111827),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (email.isNotEmpty && email != displayName)
                            Text(
                              email,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF6B7280),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              _buildColumnSeparator(),

              // Dynamic field values
              ...fieldIds.expand((fieldId) {
                final label = _labelFor(fieldId);
                double width = 180;
                if (label.toLowerCase().contains('date')) width = 140;
                if (label.toLowerCase().contains('email')) width = 200;

                String value = '${responses[fieldId] ?? '-'}';

                // Format dates if it's a timestamp
                if (responses[fieldId] is Timestamp) {
                  final date = (responses[fieldId] as Timestamp).toDate();
                  value =
                      '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
                }

                return [
                  SizedBox(
                    width: width,
                    child: Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF374151),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildColumnSeparator(),
                ];
              }),

              // Notes field
              SizedBox(
                width: 200,
                child: isEditing
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _notesControllers[docId],
                              style: GoogleFonts.inter(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Add note...',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF9CA3AF),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFD1D5DB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF2563EB)),
                                ),
                              ),
                              onSubmitted: (value) async {
                                await _saveNote(docId, value);
                                setState(() {
                                  _editingNotes[docId] = false;
                                });
                              },
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            icon: const Icon(Icons.check,
                                size: 16, color: Color(0xFF059669)),
                            onPressed: () async {
                              await _saveNote(
                                  docId, _notesControllers[docId]!.text);
                              setState(() {
                                _editingNotes[docId] = false;
                              });
                            },
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            icon: const Icon(Icons.close,
                                size: 16, color: Color(0xFFDC2626)),
                            onPressed: () {
                              setState(() {
                                _editingNotes[docId] = false;
                                // Reset to saved value
                                final savedNote =
                                    (data['adminNote'] ?? '').toString();
                                _notesControllers[docId]!.text = savedNote;
                              });
                            },
                          ),
                        ],
                      )
                    : InkWell(
                        onTap: () {
                          setState(() {
                            _editingNotes[docId] = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _notesControllers[docId]!.text.isNotEmpty
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _notesControllers[docId]!.text.isEmpty
                                      ? 'Add note...'
                                      : _notesControllers[docId]!.text,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color:
                                        _notesControllers[docId]!.text.isEmpty
                                            ? const Color(0xFF9CA3AF)
                                            : const Color(0xFF92400E),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit,
                                size: 14,
                                color: _notesControllers[docId]!.text.isEmpty
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF92400E),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),

              _buildColumnSeparator(),

              // Actions
              SizedBox(
                width: 120,
                child: Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      onPressed: () {},
                      color: const Color(0xFF6B7280),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      icon: const Icon(Icons.download_outlined, size: 18),
                      onPressed: () {},
                      color: const Color(0xFF6B7280),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      icon: const Icon(Icons.more_vert, size: 18),
                      onPressed: () {},
                      color: const Color(0xFF6B7280),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF059669),
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFFDC2626),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
    ];

    if (name.isEmpty) return colors[0];
    final code = name.codeUnitAt(0);
    return colors[code % colors.length];
  }
}
