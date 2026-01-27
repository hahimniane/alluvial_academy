import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class FormSubmissionsScreen extends StatefulWidget {
  final String formId;
  final String formTitle;
  const FormSubmissionsScreen({super.key, required this.formId, required this.formTitle});

  @override
  State<FormSubmissionsScreen> createState() => _FormSubmissionsScreenState();
}

class _FormSubmissionsScreenState extends State<FormSubmissionsScreen> {
  bool _isLoading = true;
  List<QueryDocumentSnapshot> _submissions = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('form_responses')
          .where('formId', isEqualTo: widget.formId)
          .orderBy('submittedAt', descending: true)
          .get();
      if (!mounted) return;
      setState(() => _submissions = snap.docs);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _submissions.where((doc) {
      if (_search.isEmpty) return true;
      final m = doc.data() as Map<String, dynamic>;
      final user = (m['userEmail'] ?? '').toString().toLowerCase();
      final first = (m['firstName'] ?? '').toString().toLowerCase();
      final last = (m['lastName'] ?? '').toString().toLowerCase();
      return user.contains(_search) || ('$first $last').contains(_search);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        title: Text('Submissions • ${widget.formTitle}', style: GoogleFonts.inter()),
        backgroundColor: const Color(0xff0386FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchUserOrName,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xff0386FF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${filtered.length} submissions',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xff0386FF))),
                )
              ],
            ),
          ),
          // Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xff0386FF)))
                : _SubmissionsTable(rows: filtered),
          ),
        ],
      ),
    );
  }
}

class _SubmissionsTable extends StatelessWidget {
  final List<QueryDocumentSnapshot> rows;
  const _SubmissionsTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text(AppLocalizations.of(context)!.text4)),
            DataColumn(label: Text(AppLocalizations.of(context)!.roleUser)),
            DataColumn(label: Text(AppLocalizations.of(context)!.dateSubmitted)),
            DataColumn(label: Text(AppLocalizations.of(context)!.userStatus)),
            DataColumn(label: Text(AppLocalizations.of(context)!.profileEmail)),
          ],
          rows: [
            for (int i = 0; i < rows.length; i++)
              _buildRow(context, i + 1, rows[i].data() as Map<String, dynamic>),
          ],
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, int index, Map<String, dynamic> m) {
    final ts = (m['submittedAt'] as Timestamp?)?.toDate();
    final submitted = ts != null
        ? '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
        : '-';
    final name = '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim();
    final email = (m['userEmail'] ?? '').toString();
    final status = (m['status'] ?? 'completed').toString();
    return DataRow(cells: [
      DataCell(Text(index.toString())),
      DataCell(Text(name.isEmpty ? email : name)),
      DataCell(Text(submitted)),
      DataCell(_statusPill(status)),
      DataCell(Text(email)),
    ]);
  }

  Widget _statusPill(String statusRaw) {
    final s = statusRaw.toLowerCase();
    final isActive = s == 'completed' || s == 'published' || s == 'active' || s == 'approved';
    final bg = isActive ? const Color(0xffE8FBF3) : const Color(0xffF3F4F6);
    final fg = isActive ? const Color(0xff059669) : const Color(0xff6B7280);
    final label = isActive ? 'Completed' : statusRaw;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? const Color(0xffA7F3D0) : const Color(0xffE5E7EB)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

