import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FormSubmissionsDialog extends StatefulWidget {
  final String formId;
  final String formTitle;
  
  const FormSubmissionsDialog({
    super.key, 
    required this.formId, 
    required this.formTitle
  });

  @override
  State<FormSubmissionsDialog> createState() => _FormSubmissionsDialogState();
}

class _FormSubmissionsDialogState extends State<FormSubmissionsDialog> {
  bool _isLoading = true;
  Map<String, dynamic> _template = {};
  List<QueryDocumentSnapshot> _submissions = [];
  DateTimeRange? _range;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final templateDoc = await FirebaseFirestore.instance.collection('form').doc(widget.formId).get();
      final fieldsMap = (templateDoc.data()?['fields'] as Map?)?.cast<String, dynamic>() ?? {};

      Query q = FirebaseFirestore.instance
          .collection('form_responses')
          .where('formId', isEqualTo: widget.formId)
          .orderBy('submittedAt', descending: true);
      final snap = await q.get();

      if (!mounted) return;
      setState(() {
        _template = {'fields': fieldsMap};
        _submissions = snap.docs;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _fieldOrder {
    final fields = (_template['fields'] as Map<String, dynamic>?) ?? {};
    final entries = fields.entries.toList();
    entries.sort((a, b) => ((a.value['order'] ?? 0) as int).compareTo((b.value['order'] ?? 0) as int));
    return entries.map((e) => e.key).toList();
  }

  String _labelFor(String fieldId) {
    final fields = (_template['fields'] as Map<String, dynamic>?) ?? {};
    return (fields[fieldId]?['label'] ?? fieldId).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54, // Semi-transparent overlay
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: MediaQuery.of(context).size.width - 250, // Account for sidebar width
          height: MediaQuery.of(context).size.height,
          color: const Color(0xFFF9FAFB),
        child: Column(
          children: [
            // Header with form title and action buttons
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, color: Color(0xFF6B7280), size: 20),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  // Action buttons
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit form'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Collect', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _buildTab('Submissions', isSelected: true),
                  _buildTab('Users'),
                  _buildTab('Summary'),
                  _buildTab('Activity'),
                ],
              ),
            ),

            // Filter and search bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back, color: Color(0xFF6B7280), size: 20),
                  const SizedBox(width: 12),
                  Text(
                    '01/01 - 12/31',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.calendar_today_outlined, color: Color(0xFF6B7280), size: 16),
                  const SizedBox(width: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF2563EB), width: 1),
                    ),
                    child: Text(
                      '${_submissions.length} submissions',
                      style: GoogleFonts.inter(
                        fontSize: 12,
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
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        if (mounted) {
                          setState(() => _searchQuery = value);
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search',
                        prefixIcon: Icon(Icons.search, color: Color(0xFF6B7280), size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.filter_list, color: Color(0xFF6B7280)),
                ],
              ),
            ),

            // Filter options
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  const Text('Filter', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(width: 16),
                  _buildFilterDropdown('Groups'),
                  const SizedBox(width: 8),
                  _buildFilterDropdown('Direct manager'),
                  const SizedBox(width: 8),
                  _buildFilterDropdown('Status'),
                  const SizedBox(width: 16),
                  const Text('Advanced filters', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
                  const Spacer(),
                  const Text('Rows per page:', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(width: 8),
                  _buildFilterDropdown('10'),
                ],
              ),
            ),

            // Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : _buildTable(),
            )
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTable() {
    final ids = _fieldOrder;
    
    // Filter submissions based on search query
    List<QueryDocumentSnapshot> filteredSubmissions = _submissions;
    if (_searchQuery.isNotEmpty) {
      filteredSubmissions = _submissions.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        final email = (data['userEmail'] ?? '').toString();
        final responses = (data['responses'] as Map?)?.cast<String, dynamic>() ?? {};
        
        return name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               responses.values.any((value) => 
                 value.toString().toLowerCase().contains(_searchQuery.toLowerCase()));
      }).toList();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: _buildTableHeader(ids),
          ),
          // Table body
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                children: filteredSubmissions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final doc = entry.value;
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildTableRow(data, index, ids);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTableWidth(List<String> fieldIds) {
    // Calculate total width: checkbox(40) + gap(16) + #(60) + user(200) + date(140) + fields(180 each) + status(100) + actions(120)
    return 40 + 16 + 60 + 200 + 140 + (fieldIds.length * 180) + 100 + 120;
  }

  Widget _buildTableHeader(List<String> fieldIds) {
    return SizedBox(
      width: _calculateTableWidth(fieldIds),
      child: Row(
        children: [
          // Checkbox column
          SizedBox(
            width: 40,
            child: Checkbox(
              value: false,
              onChanged: (bool? value) {},
              activeColor: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 16),
          // Number column
          SizedBox(
            width: 60,
            child: Text(
              '#',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          // User column
          SizedBox(
            width: 200,
            child: Text(
              'User',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          // Date submitted column
          SizedBox(
            width: 140,
            child: Text(
              'Date submitted',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          // Dynamic form field columns
          ...fieldIds.map((fieldId) => SizedBox(
            width: 180,
            child: Text(
              _labelFor(fieldId),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          )).toList(),
          // Status column
          SizedBox(
            width: 100,
            child: Text(
              'Status',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          // Actions column
          SizedBox(
            width: 120,
            child: Text(
              'Add manager/Tags',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> data, int index, List<String> fieldIds) {
    final responses = (data['responses'] as Map?)?.cast<String, dynamic>() ?? {};
    final timestamp = (data['submittedAt'] as Timestamp?)?.toDate();
    final dateSubmitted = timestamp != null
        ? '${timestamp.month.toString().padLeft(2, '0')}/${timestamp.day.toString().padLeft(2, '0')}/${timestamp.year}'
        : '-';
    final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
    final email = (data['userEmail'] ?? '').toString();
    final displayName = name.isEmpty ? email : name;

    // Generate a random status for demo purposes
    final statuses = ['Seen', 'Done'];
    final status = statuses[index % statuses.length];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 40,
              child: Checkbox(
                value: false,
                onChanged: (bool? value) {},
                activeColor: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 16),
            // Row number
            SizedBox(
              width: 60,
              child: Text(
                '${index + 99}', // Start from 99 like in the screenshot
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF374151),
                ),
              ),
            ),
            // User with avatar
            SizedBox(
              width: 200,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF059669),
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF374151),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Date submitted
            SizedBox(
              width: 140,
              child: Text(
                dateSubmitted,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF374151),
                ),
              ),
            ),
            // Dynamic form field values
            ...fieldIds.map((fieldId) => SizedBox(
              width: 180,
              child: Text(
                '${responses[fieldId] ?? '-'}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF374151),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            )).toList(),
            // Status pill
            SizedBox(
              width: 100,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'Done' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: status == 'Done' ? const Color(0xFF059669) : const Color(0xFFD97706),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // Actions
            SizedBox(
              width: 120,
              child: Row(
                children: [
                  Icon(Icons.more_horiz, color: const Color(0xFF6B7280)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String text, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 32),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD1D5DB)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF6B7280)),
        ],
      ),
    );
  }
}