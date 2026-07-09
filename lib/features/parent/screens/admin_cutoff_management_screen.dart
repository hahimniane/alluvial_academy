import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/parent/models/invoice.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class AdminCutoffManagementScreen extends StatefulWidget {
  const AdminCutoffManagementScreen({super.key});

  @override
  State<AdminCutoffManagementScreen> createState() =>
      _AdminCutoffManagementScreenState();
}

class _AdminCutoffManagementScreenState
    extends State<AdminCutoffManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _refreshKey = 0;

  void _refresh() => setState(() => _refreshKey++);

  Future<List<_CutoffFamily>> _loadRows(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final builders = <String, _CutoffFamilyBuilder>{};
    for (final doc in docs) {
      final data = doc.data();
      final guardianIds = <String>{
        ...List<String>.from(data['guardian_ids'] ?? const []),
        ...List<String>.from(data['guardianIds'] ?? const []),
        if ((data['parent_id'] ?? '').toString().trim().isNotEmpty)
          data['parent_id'].toString().trim(),
        if ((data['parentId'] ?? '').toString().trim().isNotEmpty)
          data['parentId'].toString().trim(),
      }.toList();
      final fallbackFamilyId =
          guardianIds.isNotEmpty ? guardianIds.first : doc.id;
      final studentSummary = _UserSummary(
        id: doc.id,
        name: _displayName(data),
        email: (data['email'] ?? data['e-mail'] ?? '').toString(),
      );

      final invoiceMap = <String, Invoice>{};
      final studentInvoices = await _firestore
          .collection('invoices')
          .where('student_id', isEqualTo: doc.id)
          .get();
      for (final invoiceDoc in studentInvoices.docs) {
        invoiceMap[invoiceDoc.id] = Invoice.fromFirestore(invoiceDoc);
      }

      for (final parentId in guardianIds) {
        final parentInvoices = await _firestore
            .collection('invoices')
            .where('parent_id', isEqualTo: parentId)
            .get();
        for (final invoiceDoc in parentInvoices.docs) {
          invoiceMap[invoiceDoc.id] = Invoice.fromFirestore(invoiceDoc);
        }
      }
      if (guardianIds.isEmpty) {
        final adultStudentInvoices = await _firestore
            .collection('invoices')
            .where('parent_id', isEqualTo: doc.id)
            .get();
        for (final invoiceDoc in adultStudentInvoices.docs) {
          invoiceMap[invoiceDoc.id] = Invoice.fromFirestore(invoiceDoc);
        }
      }

      final now = DateTime.now();
      final blocking = invoiceMap.values.where((invoice) {
        if (invoice.status == InvoiceStatus.cancelled || invoice.isFullyPaid) {
          return false;
        }
        return !invoice.effectiveAccessCutoffDate.isAfter(now);
      }).toList()
        ..sort((a, b) => a.effectiveAccessCutoffDate.compareTo(
              b.effectiveAccessCutoffDate,
            ));

      if (blocking.isEmpty) {
        builders
            .putIfAbsent(
                fallbackFamilyId, () => _CutoffFamilyBuilder(fallbackFamilyId))
            .addStudent(studentSummary, const []);
        continue;
      }

      final groupedInvoices = <String, List<Invoice>>{};
      for (final invoice in blocking) {
        final familyId = invoice.parentId.trim().isNotEmpty
            ? invoice.parentId.trim()
            : fallbackFamilyId;
        groupedInvoices.putIfAbsent(familyId, () => []).add(invoice);
      }

      for (final entry in groupedInvoices.entries) {
        final builder = builders.putIfAbsent(
            entry.key, () => _CutoffFamilyBuilder(entry.key));
        final studentInvoices = entry.value.where((invoice) {
          final invoiceStudentId = invoice.studentId.trim();
          return invoiceStudentId.isEmpty ||
              invoiceStudentId == doc.id ||
              invoice.parentId == doc.id;
        }).toList();
        builder
          ..addInvoices(entry.value)
          ..addStudent(studentSummary, studentInvoices);
      }
    }

    final families = <_CutoffFamily>[];
    for (final builder in builders.values) {
      final parent = await _loadUserSummary(builder.parentId);
      families.add(builder.build(parent ?? builder.fallbackSummary));
    }
    families.sort((a, b) => b.totalPastDue.compareTo(a.totalPastDue));
    return families;
  }

  Future<_UserSummary?> _loadUserSummary(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return null;
    try {
      final doc = await _firestore.collection('users').doc(id).get();
      if (!doc.exists) return null;
      final data = doc.data() ?? const <String, dynamic>{};
      return _UserSummary(
        id: doc.id,
        name: _displayName(data),
        email: (data['email'] ?? data['e-mail'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _extendCutoff(_CutoffExtensionTarget target) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ExtendCutoffDialog(target: target),
    );
    if (saved == true && mounted) {
      _refresh();
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.cutoffExtendedSuccess),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('users')
            .where('access_suspended', isEqualTo: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _InlineState(
              icon: Icons.error_outline_rounded,
              title: l10n.cutoffLoadError,
              detail: snapshot.error.toString(),
            );
          }

          final docs = snapshot.data?.docs ?? const [];
          return FutureBuilder<List<_CutoffFamily>>(
            key: ValueKey(_refreshKey),
            future: _loadRows(docs),
            builder: (context, rowsSnapshot) {
              if (rowsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (rowsSnapshot.hasError) {
                return _InlineState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.cutoffLoadError,
                  detail: rowsSnapshot.error.toString(),
                );
              }

              final families = rowsSnapshot.data ?? const [];
              if (families.isEmpty) {
                return _InlineState(
                  icon: Icons.verified_user_outlined,
                  title: l10n.cutoffNoStudents,
                  detail: l10n.cutoffNoStudentsDetail,
                );
              }

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _CutoffHeader(families: families)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: families.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final family = families[index];
                        return _CutoffFamilyTile(
                          family: family,
                          onExtendFamily: () => _extendCutoff(
                            _CutoffExtensionTarget.parent(family),
                          ),
                          onExtendStudent: (student) => _extendCutoff(
                            _CutoffExtensionTarget.student(student),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static String _displayName(Map<String, dynamic> data) {
    final name = [
      data['first_name'],
      data['last_name'],
    ]
        .whereType<Object>()
        .map((v) => v.toString().trim())
        .where((v) => v.isNotEmpty)
        .join(' ');
    if (name.isNotEmpty) return name;
    return (data['displayName'] ?? data['name'] ?? 'Student').toString();
  }
}

class _CutoffHeader extends StatelessWidget {
  final List<_CutoffFamily> families;

  const _CutoffHeader({required this.families});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final money = NumberFormat.simpleCurrency(name: 'USD');
    final totalPastDue = families.fold<double>(
      0,
      (total, family) => total + family.totalPastDue,
    );
    final blockingCount = families.fold<int>(
      0,
      (total, family) => total + family.blockingInvoices.length,
    );
    final suspendedCount = families.fold<int>(
      0,
      (total, family) => total + family.students.length,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFEF4444),
                      Color(0xFFF59E0B),
                      Color(0xFF38BDF8),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stats = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeaderStat(
                        label: l10n.cutoffSuspendedStudents,
                        value: suspendedCount.toString(),
                        color: const Color(0xFFFEE2E2),
                      ),
                      _HeaderStat(
                        label: l10n.cutoffParentGroups,
                        value: families.length.toString(),
                        color: const Color(0xFFE0F2FE),
                      ),
                      _HeaderStat(
                        label: l10n.cutoffBlockingInvoices,
                        value: blockingCount.toString(),
                        color: const Color(0xFFFFEDD5),
                      ),
                      _HeaderStat(
                        label: l10n.cutoffTotalPastDue,
                        value: money.format(totalPastDue),
                        color: const Color(0xFFDCFCE7),
                      ),
                    ],
                  );
                  final title = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.cutoffTitle,
                        style: GoogleFonts.inter(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.cutoffSubtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 760) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: 12),
                        stats,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 16),
                      stats,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeaderStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 142,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _CutoffFamilyTile extends StatelessWidget {
  final _CutoffFamily family;
  final VoidCallback onExtendFamily;
  final ValueChanged<_CutoffStudent> onExtendStudent;

  const _CutoffFamilyTile({
    required this.family,
    required this.onExtendFamily,
    required this.onExtendStudent,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final money = NumberFormat.simpleCurrency(name: 'USD');
    final oldest = family.blockingInvoices.isEmpty
        ? null
        : family.blockingInvoices.first.effectiveAccessCutoffDate;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Icon(
                  Icons.lock_clock_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family.parent.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (family.parent.email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        family.parent.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onExtendFamily,
                icon: const Icon(Icons.event_available_rounded, size: 16),
                label: Text(l10n.cutoffExtendParentAction),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniStat(
                label: l10n.cutoffStudentsInGroup,
                value: family.students.length.toString(),
                color: const Color(0xFF0369A1),
              ),
              _MiniStat(
                label: l10n.cutoffBlockingInvoices,
                value: family.blockingInvoices.length.toString(),
                color: const Color(0xFFDC2626),
              ),
              _MiniStat(
                label: l10n.cutoffTotalPastDue,
                value: money.format(family.totalPastDue),
                color: const Color(0xFFB45309),
              ),
              if (oldest != null)
                _MiniStat(
                  label: l10n.cutoffOldestCutoff,
                  value: DateFormat.MMMd().format(oldest),
                  color: const Color(0xFF475569),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...family.students.map(
            (student) => _CutoffStudentRow(
              student: student,
              onExtend: () => onExtendStudent(student),
            ),
          ),
        ],
      ),
    );
  }
}

class _CutoffStudentRow extends StatelessWidget {
  final _CutoffStudent student;
  final VoidCallback onExtend;

  const _CutoffStudentRow({
    required this.student,
    required this.onExtend,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final money = NumberFormat.simpleCurrency(name: 'USD');
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0369A1),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${student.blockingInvoices.length} ${l10n.cutoffBlockingInvoices} • ${money.format(student.totalPastDue)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onExtend,
                icon: const Icon(Icons.person_rounded, size: 15),
                label: Text(l10n.cutoffExtendStudentAction),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFF99F6E4)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  textStyle: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (student.blockingInvoices.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...student.blockingInvoices.take(2).map(
                  (invoice) => _InvoiceLine(invoice: invoice),
                ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceLine extends StatelessWidget {
  final Invoice invoice;

  const _InvoiceLine({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.simpleCurrency(name: invoice.currency);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_rounded,
              size: 15, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              invoice.invoiceNumber.isNotEmpty
                  ? invoice.invoiceNumber
                  : invoice.id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            money.format(invoice.remainingBalance),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtendCutoffDialog extends StatefulWidget {
  final _CutoffExtensionTarget target;

  const _ExtendCutoffDialog({required this.target});

  @override
  State<_ExtendCutoffDialog> createState() => _ExtendCutoffDialogState();
}

class _ExtendCutoffDialogState extends State<_ExtendCutoffDialog> {
  late DateTime _selectedDate;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 7));
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('extendStudentAccessCutoff');
      await callable.call(widget.target.payload(_selectedDate));
      if (mounted) Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.target.isParent
                    ? l10n.cutoffExtendParentTitle
                    : l10n.cutoffExtendTitle,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.target.isParent
                    ? l10n.cutoffExtendParentBody(widget.target.name)
                    : l10n.cutoffExtendBody(widget.target.name),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _presetButton(l10n.cutoffExtendBy7, 7),
                  _presetButton(l10n.cutoffExtendBy14, 14),
                  _presetButton(l10n.cutoffExtendBy30, 30),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _isSaving
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded,
                          size: 17, color: Color(0xFF0F766E)),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat.yMMMd().format(_selectedDate),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      child: Text(l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: Text(l10n.cutoffApplyExtension),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetButton(String label, int days) {
    final selected =
        _selectedDate.difference(DateTime.now()).inDays == days - 1;
    return OutlinedButton(
      onPressed: _isSaving
          ? null
          : () {
              final now = DateTime.now();
              setState(() {
                _selectedDate = DateTime(now.year, now.month, now.day)
                    .add(Duration(days: days));
              });
            },
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? const Color(0xFFEFFDF5) : Colors.white,
        side: BorderSide(
          color: selected ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(label),
    );
  }
}

class _InlineState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _InlineState({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: const Color(0xFF64748B)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserSummary {
  final String id;
  final String name;
  final String email;

  const _UserSummary({
    required this.id,
    required this.name,
    required this.email,
  });
}

class _CutoffFamily {
  final _UserSummary parent;
  final List<_CutoffStudent> students;
  final List<Invoice> blockingInvoices;
  final double totalPastDue;

  const _CutoffFamily({
    required this.parent,
    required this.students,
    required this.blockingInvoices,
    required this.totalPastDue,
  });
}

class _CutoffFamilyBuilder {
  final String parentId;
  final Map<String, Invoice> _invoices = {};
  final Map<String, _CutoffStudentBuilder> _students = {};
  _UserSummary? _fallbackSummary;

  _CutoffFamilyBuilder(this.parentId);

  _UserSummary get fallbackSummary =>
      _fallbackSummary ??
      _UserSummary(
        id: parentId,
        name: parentId,
        email: '',
      );

  void addInvoices(List<Invoice> invoices) {
    for (final invoice in invoices) {
      _invoices[invoice.id] = invoice;
    }
  }

  void addStudent(_UserSummary student, List<Invoice> invoices) {
    _fallbackSummary ??= student;
    _students
        .putIfAbsent(student.id, () => _CutoffStudentBuilder(student))
        .addInvoices(invoices);
  }

  _CutoffFamily build(_UserSummary parent) {
    final invoices = _invoices.values.toList()
      ..sort((a, b) => a.effectiveAccessCutoffDate.compareTo(
            b.effectiveAccessCutoffDate,
          ));
    final students = _students.values.map((builder) => builder.build()).toList()
      ..sort((a, b) => b.totalPastDue.compareTo(a.totalPastDue));
    return _CutoffFamily(
      parent: parent,
      students: students,
      blockingInvoices: invoices,
      totalPastDue: invoices.fold<double>(
        0,
        (total, invoice) => total + invoice.remainingBalance,
      ),
    );
  }
}

class _CutoffStudentBuilder {
  final _UserSummary student;
  final Map<String, Invoice> _invoices = {};

  _CutoffStudentBuilder(this.student);

  void addInvoices(List<Invoice> invoices) {
    for (final invoice in invoices) {
      _invoices[invoice.id] = invoice;
    }
  }

  _CutoffStudent build() {
    final invoices = _invoices.values.toList()
      ..sort((a, b) => a.effectiveAccessCutoffDate.compareTo(
            b.effectiveAccessCutoffDate,
          ));
    return _CutoffStudent(
      id: student.id,
      name: student.name,
      email: student.email,
      blockingInvoices: invoices,
      totalPastDue: invoices.fold<double>(
        0,
        (total, invoice) => total + invoice.remainingBalance,
      ),
    );
  }
}

class _CutoffStudent {
  final String id;
  final String name;
  final String email;
  final List<Invoice> blockingInvoices;
  final double totalPastDue;

  const _CutoffStudent({
    required this.id,
    required this.name,
    required this.email,
    required this.blockingInvoices,
    required this.totalPastDue,
  });
}

class _CutoffExtensionTarget {
  final String id;
  final String name;
  final bool isParent;

  const _CutoffExtensionTarget._({
    required this.id,
    required this.name,
    required this.isParent,
  });

  factory _CutoffExtensionTarget.parent(_CutoffFamily family) {
    return _CutoffExtensionTarget._(
      id: family.parent.id,
      name: family.parent.name,
      isParent: true,
    );
  }

  factory _CutoffExtensionTarget.student(_CutoffStudent student) {
    return _CutoffExtensionTarget._(
      id: student.id,
      name: student.name,
      isParent: false,
    );
  }

  Map<String, dynamic> payload(DateTime extendTo) {
    return {
      if (isParent) 'parentId': id else 'studentId': id,
      'scope': isParent ? 'parent' : 'student',
      'extendTo': extendTo.toIso8601String(),
    };
  }
}
