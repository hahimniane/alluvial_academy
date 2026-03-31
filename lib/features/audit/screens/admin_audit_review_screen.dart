import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/teacher_audit_full.dart';
import '../widgets/audit_detail_panel.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class AdminAuditReviewScreen extends StatefulWidget {
  final List<TeacherAuditFull> audits;

  const AdminAuditReviewScreen({super.key, required this.audits});

  @override
  State<AdminAuditReviewScreen> createState() => _AdminAuditReviewScreenState();
}

class _AdminAuditReviewScreenState extends State<AdminAuditReviewScreen> {
  TeacherAuditFull? _selectedAudit;
  String _search = '';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppLocalizations.of(context)!.auditReviewModeTitle,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xff1E293B)),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xffE2E8F0)),
        ),
      ),
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  Widget _wideLayout() {
    return Row(
      children: [
        SizedBox(width: 260, child: Container(color: Colors.white, child: _masterList())),
        Container(width: 1, color: const Color(0xffE2E8F0)),
        Expanded(
          child: _selectedAudit == null
              ? _emptyPrompt()
              : AuditDetailFullPanel(
                  key: ValueKey(_selectedAudit!.id),
                  audit: _selectedAudit!,
                  enableEditing: true,
                  onAuditChanged: (updated) => setState(() => _selectedAudit = updated),
                ),
        ),
      ],
    );
  }

  Widget _narrowLayout() {
    if (_selectedAudit == null) return _masterList();
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _selectedAudit = null),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: Text(AppLocalizations.of(context)!.auditReviewBackToList),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xffE2E8F0)),
        Expanded(
          child: AuditDetailFullPanel(
            key: ValueKey(_selectedAudit!.id),
            audit: _selectedAudit!,
            enableEditing: true,
            onAuditChanged: (updated) => setState(() => _selectedAudit = updated),
          ),
        ),
      ],
    );
  }

  Widget _masterList() {
    final audits = _filteredAudits();
    final month = audits.isNotEmpty ? audits.first.yearMonth : '-';

    Widget chip(String id, String label) {
      final selected = _filter == id;
      return InkWell(
        onTap: () => setState(() => _filter = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? const Color(0xff1a6ef5) : const Color(0xffE2E8F0), width: 0.5),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: selected ? const Color(0xff1a6ef5) : const Color(0xff64748B), fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.auditManagement, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(month, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xff94A3B8))),
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: AppLocalizations.of(context)!.searchByNameOrEmail,
                    hintStyle: GoogleFonts.inter(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  chip('all', AppLocalizations.of(context)!.commonAll),
                  const SizedBox(width: 6),
                  chip('pending', AppLocalizations.of(context)!.auditStatusPending),
                  const SizedBox(width: 6),
                  chip('done', AppLocalizations.of(context)!.auditFilterDone),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: audits.length,
            itemBuilder: (context, index) {
              final a = audits[index];
              final selected = _selectedAudit?.id == a.id;
              final dot = a.status == AuditStatus.completed
                  ? const Color(0xFF10B981)
                  : a.status == AuditStatus.coachSubmitted
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFFF59E0B);
              return InkWell(
                onTap: () => setState(() => _selectedAudit = a),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : const Color(0xFFF8FAFC),
                    border: Border(
                      left: BorderSide(color: selected ? const Color(0xff1a6ef5) : Colors.transparent, width: 3),
                      bottom: const BorderSide(color: Color(0xffE2E8F0), width: 0.5),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: _tierColor(a.performanceTier).withValues(alpha: 0.12),
                        child: Text(
                          a.teacherName.isNotEmpty ? a.teacherName[0].toUpperCase() : '?',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _tierColor(a.performanceTier)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.teacherName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('${_dept(a)} · ${a.overallScore.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<TeacherAuditFull> _filteredAudits() {
    final q = _search.trim().toLowerCase();
    final rows = widget.audits.where((a) {
      final matchesSearch = q.isEmpty || a.teacherName.toLowerCase().contains(q) || a.teacherEmail.toLowerCase().contains(q);
      if (!matchesSearch) return false;
      if (_filter == 'all') return true;
      if (_filter == 'pending') return !(a.status == AuditStatus.completed || a.status == AuditStatus.coachSubmitted);
      return a.status == AuditStatus.completed || a.status == AuditStatus.coachSubmitted;
    }).toList()
      ..sort((a, b) => b.yearMonth.compareTo(a.yearMonth));
    return rows;
  }

  String _dept(TeacherAuditFull audit) {
    if (audit.hoursTaughtBySubject.isEmpty) return 'N/A';
    return audit.hoursTaughtBySubject.keys.first;
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'excellent':
        return const Color(0xFF10B981);
      case 'good':
        return const Color(0xFF3B82F6);
      case 'needsImprovement':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }

  Widget _emptyPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assessment_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.auditReviewSelectTeacher,
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xff94A3B8)),
          ),
        ],
      ),
    );
  }
}
