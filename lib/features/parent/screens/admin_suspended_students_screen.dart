import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/services/web_app_stability_screen_ids.dart';
import 'package:alluwalacademyadmin/core/services/web_app_stability_service.dart';
import 'package:alluwalacademyadmin/features/parent/models/invoice.dart';
import 'package:alluwalacademyadmin/features/parent/screens/invoice_detail_screen.dart';

class AdminSuspendedStudentsScreen extends StatefulWidget {
  const AdminSuspendedStudentsScreen({super.key});

  @override
  State<AdminSuspendedStudentsScreen> createState() =>
      _AdminSuspendedStudentsScreenState();
}

class _AdminSuspendedStudentsScreenState
    extends State<AdminSuspendedStudentsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  final _money = NumberFormat.simpleCurrency(name: 'USD');
  final _dateFormat = DateFormat.yMMMd();
  Stream<List<_SuspendedStudentRow>>? _rows;

  static const Duration _loadTimeout = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    _resetRowsStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetRowsStream() {
    WebAppStabilityService.instance.clearScreenStuck(
      WebAppStabilityScreenIds.adminSuspendedStudents,
    );
    _rows = _firestore
        .collection('users')
        .where('access_suspended', isEqualTo: true)
        .snapshots()
        .timeout(_loadTimeout, onTimeout: (sink) {
      final error = TimeoutException(
        'Timed out loading cut off students. Firestore may need to reconnect.',
        _loadTimeout,
      );
      WebAppStabilityService.instance.reportScreenStuck(
        screenId: WebAppStabilityScreenIds.adminSuspendedStudents,
        reason: 'Cutoffs could not load from Firestore. Try Recover or Reload.',
      );
      sink.addError(error);
    }).asyncMap((snapshot) async {
      try {
        final rows = await _buildRows(snapshot).timeout(_loadTimeout);
        WebAppStabilityService.instance.clearScreenStuck(
          WebAppStabilityScreenIds.adminSuspendedStudents,
        );
        WebAppStabilityService.instance.pokeFirestoreActivity();
        return rows;
      } catch (error) {
        WebAppStabilityService.instance.noteFirestoreError(error);
        WebAppStabilityService.instance.reportScreenStuck(
          screenId: WebAppStabilityScreenIds.adminSuspendedStudents,
          reason:
              'Cutoffs could not finish loading from Firestore. Try Recover or Reload.',
        );
        rethrow;
      }
    });
  }

  void _retryLoad() {
    setState(_resetRowsStream);
  }

  Future<List<_SuspendedStudentRow>> _buildRows(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final rows = <_SuspendedStudentRow>[];
    for (final doc in snapshot.docs) {
      final student = _SuspendedStudent.fromDoc(doc);
      final parentIds = student.parentIds.isNotEmpty
          ? student.parentIds
          : student.isAdultStudent
              ? <String>[student.id]
              : const <String>[];
      final parents = <_ParentSummary>[];
      final invoicesById = <String, Invoice>{};

      for (final parentId in parentIds) {
        final parent = await _loadParent(parentId);
        parents.add(parent);

        final parentInvoices = await _loadCutoffInvoicesForParent(parentId);
        for (final invoice in parentInvoices) {
          invoicesById[invoice.id] = invoice;
        }
      }

      final directInvoices = await _loadCutoffInvoicesForStudent(student.id);
      for (final invoice in directInvoices) {
        invoicesById[invoice.id] = invoice;
      }

      final invoices = invoicesById.values.toList()
        ..sort((a, b) => b.remainingBalance.compareTo(a.remainingBalance));

      rows.add(
        _SuspendedStudentRow(
          student: student,
          parents: parents,
          invoices: invoices,
        ),
      );
    }

    rows.sort((a, b) {
      final highestA = a.highestBalance;
      final highestB = b.highestBalance;
      if (highestA != highestB) return highestB.compareTo(highestA);
      return a.student.name
          .toLowerCase()
          .compareTo(b.student.name.toLowerCase());
    });
    return rows;
  }

  Future<_ParentSummary> _loadParent(String parentId) async {
    final doc = await _getDocWithCacheFallback(
      _firestore.collection('users').doc(parentId),
    );
    final data = doc.data() ?? const <String, dynamic>{};
    return _ParentSummary(
      id: parentId,
      name: _displayName(data, fallback: parentId),
      email: _emailFromUser(data),
      phone:
          (data['phone'] ?? data['phone_number'] ?? data['phoneNumber'] ?? '')
              .toString()
              .trim(),
    );
  }

  Future<List<Invoice>> _loadCutoffInvoicesForParent(String parentId) async {
    final query = _firestore
        .collection('invoices')
        .where('parent_id', isEqualTo: parentId);
    final snap = await _getQueryWithCacheFallback(query);
    return _cutoffInvoicesFromSnapshot(snap);
  }

  Future<List<Invoice>> _loadCutoffInvoicesForStudent(String studentId) async {
    final query = _firestore
        .collection('invoices')
        .where('student_id', isEqualTo: studentId);
    final snap = await _getQueryWithCacheFallback(query);
    return _cutoffInvoicesFromSnapshot(snap);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getDocWithCacheFallback(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      return await ref
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(_loadTimeout);
    } catch (e) {
      WebAppStabilityService.instance.noteFirestoreError(e);
      try {
        return await ref
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        rethrow;
      }
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _getQueryWithCacheFallback(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      return await query
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(_loadTimeout);
    } catch (e) {
      WebAppStabilityService.instance.noteFirestoreError(e);
      try {
        return await query
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        rethrow;
      }
    }
  }

  List<Invoice> _cutoffInvoicesFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final now = DateTime.now();
    return snapshot.docs
        .map(Invoice.fromFirestore)
        .where((invoice) =>
            invoice.status != InvoiceStatus.paid &&
            invoice.status != InvoiceStatus.cancelled &&
            invoice.remainingBalance > 0 &&
            !invoice.effectiveAccessCutoffDate.isAfter(now))
        .toList();
  }

  List<_SuspendedStudentRow> _filterRows(List<_SuspendedStudentRow> rows) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return rows;

    return rows.where((row) {
      final haystacks = <String>[
        row.student.name,
        row.student.email,
        row.student.id,
        ...row.parents.expand((parent) => [
              parent.name,
              parent.email,
              parent.phone,
              parent.id,
            ]),
        ...row.invoices.expand((invoice) => [
              invoice.id,
              invoice.invoiceNumber,
              invoice.displayBillingPeriod ?? '',
            ]),
      ];
      return haystacks.any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<List<_SuspendedStudentRow>>(
        stream: _rows,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final rows = _filterRows(snapshot.data ?? const []);
          final totalBalance = rows.fold<double>(
            0,
            (total, row) => total + row.totalBalance,
          );
          final invoicesCount =
              rows.fold<int>(0, (total, row) => total + row.invoices.length);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(
                          suspendedCount: snapshot.data?.length ?? 0,
                          invoicesCount: invoicesCount,
                          totalBalance: totalBalance,
                        ),
                        const SizedBox(height: 16),
                        _buildSearch(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : snapshot.hasError
                            ? _buildError(snapshot.error)
                            : rows.isEmpty
                                ? _buildEmptyState()
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                        24, 0, 24, 32),
                                    itemCount: rows.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      return _buildStudentCard(
                                        rows[index],
                                        isWide: isWide,
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader({
    required int suspendedCount,
    required int invoicesCount,
    required double totalBalance,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.no_meeting_room_rounded,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class Access Cutoffs',
                      style: GoogleFonts.inter(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Students currently blocked from joining classes because of unpaid invoices.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricPill('$suspendedCount', 'students cut off'),
              _metricPill('$invoicesCount', 'unpaid invoices',
                  color: const Color(0xFFF97316)),
              _metricPill(_money.format(totalBalance), 'outstanding',
                  color: const Color(0xFF38BDF8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricPill(String value, String label, {Color? color}) {
    final accent = color ?? const Color(0xFFFCA5A5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.inter(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search student, parent, invoice, email, or phone',
          hintStyle:
              GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14),
          prefixIcon:
              const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
          suffixIcon: _searchController.text.trim().isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildStudentCard(_SuspendedStudentRow row, {required bool isWide}) {
    final firstInvoice = row.invoices.isEmpty ? null : row.invoices.first;
    final subtitle = row.parents.isEmpty
        ? 'No parent record linked'
        : row.parents.map((parent) => parent.name).join(', ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _studentIdentity(row.student, subtitle)),
                const SizedBox(width: 14),
                _studentStatusChips(row),
              ],
            )
          else ...[
            _studentIdentity(row.student, subtitle),
            const SizedBox(height: 14),
            _studentStatusChips(row),
          ],
          const SizedBox(height: 14),
          if (row.invoices.isEmpty)
            _warningPanel(
              'This student is marked as suspended, but no unpaid cutoff invoice was found. Check the student access flag or invoice parent link.',
            )
          else ...[
            _invoiceSummary(row.invoices),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    firstInvoice == null
                        ? ''
                        : 'Cutoff date: ${_dateFormat.format(firstInvoice.effectiveAccessCutoffDate)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                if (firstInvoice != null)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              InvoiceDetailScreen(invoiceId: firstInvoice.id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('View invoice'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0386FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _studentIdentity(_SuspendedStudent student, String subtitle) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              student.initials,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFB91C1C),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.name,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _studentStatusChips(_SuspendedStudentRow row) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        _statusChip('Cut off', const Color(0xFFDC2626)),
        _infoChip(
          Icons.account_balance_wallet_rounded,
          _money.format(row.totalBalance),
        ),
        _infoChip(
          Icons.receipt_long_rounded,
          '${row.invoices.length} invoice${row.invoices.length == 1 ? '' : 's'}',
        ),
      ],
    );
  }

  Widget _invoiceSummary(List<Invoice> invoices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: invoices.take(3).map((invoice) {
        final label = invoice.invoiceNumber.isNotEmpty
            ? invoice.invoiceNumber
            : invoice.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              const Icon(Icons.receipt_outlined,
                  size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$label • ${invoice.displayBillingPeriod ?? _dateFormat.format(invoice.issuedDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _money.format(invoice.remainingBalance),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _warningPanel(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFF16A34A),
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No students are cut off right now',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Students with unpaid invoices past their access cutoff will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFDC2626),
                size: 34,
              ),
              const SizedBox(height: 10),
              Text(
                'Cutoffs could not load',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Firestore is unavailable in this browser tab. Try again, or use the page reload banner if it appears.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF991B1B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _retryLoad,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0386FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _displayName(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final first = (data['first_name'] ?? data['firstName'] ?? '').toString();
    final last = (data['last_name'] ?? data['lastName'] ?? '').toString();
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    final name = (data['name'] ?? data['display_name'] ?? '').toString().trim();
    return name.isNotEmpty ? name : fallback;
  }

  static String _emailFromUser(Map<String, dynamic> data) {
    return (data['e-mail'] ?? data['email'] ?? '').toString().trim();
  }
}

class _SuspendedStudent {
  final String id;
  final String name;
  final String email;
  final List<String> parentIds;
  final bool isAdultStudent;

  const _SuspendedStudent({
    required this.id,
    required this.name,
    required this.email,
    required this.parentIds,
    required this.isAdultStudent,
  });

  factory _SuspendedStudent.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _SuspendedStudent(
      id: doc.id,
      name: _AdminSuspendedStudentsScreenState._displayName(
        data,
        fallback: doc.id,
      ),
      email: _AdminSuspendedStudentsScreenState._emailFromUser(data),
      parentIds: List<String>.from(
        data['guardian_ids'] ?? data['guardianIds'] ?? const [],
      ),
      isAdultStudent:
          data['is_adult_student'] == true || data['isAdultStudent'] == true,
    );
  }

  String get initials {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'ST';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _ParentSummary {
  final String id;
  final String name;
  final String email;
  final String phone;

  const _ParentSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });
}

class _SuspendedStudentRow {
  final _SuspendedStudent student;
  final List<_ParentSummary> parents;
  final List<Invoice> invoices;

  const _SuspendedStudentRow({
    required this.student,
    required this.parents,
    required this.invoices,
  });

  double get totalBalance => invoices.fold<double>(
        0,
        (total, invoice) => total + invoice.remainingBalance,
      );

  double get highestBalance {
    if (invoices.isEmpty) return 0;
    return invoices
        .map((invoice) => invoice.remainingBalance)
        .reduce((a, b) => a > b ? a : b);
  }
}
