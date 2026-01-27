import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/core/models/invoice.dart';
import 'package:alluwalacademyadmin/core/services/invoice_service.dart';
import 'package:alluwalacademyadmin/features/parent/screens/invoice_detail_screen.dart';
import 'package:alluwalacademyadmin/features/parent/screens/payment_screen.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/invoice_card.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ParentInvoicesScreen extends StatefulWidget {
  final String parentId;
  final InvoiceStatus? initialStatus;

  const ParentInvoicesScreen({
    super.key,
    required this.parentId,
    this.initialStatus,
  });

  @override
  State<ParentInvoicesScreen> createState() => _ParentInvoicesScreenState();
}

class _ParentInvoicesScreenState extends State<ParentInvoicesScreen> {
  InvoiceStatus? _statusFilter;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String> _studentNameCache = {};

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatus;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String> _getStudentName(String studentId) async {
    final cached = _studentNameCache[studentId];
    if (cached != null) return cached;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(studentId).get();
      final data = doc.data();
      final first = (data?['first_name'] ?? '').toString().trim();
      final last = (data?['last_name'] ?? '').toString().trim();
      final name = ('$first $last').trim();
      final resolved = name.isNotEmpty ? name : studentId;
      _studentNameCache[studentId] = resolved;
      return resolved;
    } catch (_) {
      _studentNameCache[studentId] = studentId;
      return studentId;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.invoices,
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchInvoiceNumber,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                _buildFilters(),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Invoice>>(
              stream: InvoiceService.getParentInvoices(
                widget.parentId,
                status: _statusFilter,
                limit: 100,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _errorState('${snapshot.error}');
                }

                final invoices = snapshot.data ?? const <Invoice>[];
                final query = _searchController.text.trim().toLowerCase();
                final filtered = query.isEmpty
                    ? invoices
                    : invoices
                        .where((i) => i.invoiceNumber.toLowerCase().contains(query))
                        .toList();

                if (filtered.isEmpty) {
                  return _emptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemBuilder: (context, index) {
                    final invoice = filtered[index];
                    return FutureBuilder<String>(
                      future: _getStudentName(invoice.studentId),
                      builder: (context, studentSnapshot) {
                        final studentName = studentSnapshot.data;
                        return InvoiceCard(
                          invoice: invoice,
                          studentName: studentName,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id),
                              ),
                            );
                          },
                          onPayNow: invoice.isFullyPaid || invoice.status == InvoiceStatus.cancelled
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PaymentScreen(invoiceId: invoice.id),
                                    ),
                                  );
                                },
                        );
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: filtered.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip(label: 'All', selected: _statusFilter == null, onTap: () => setState(() => _statusFilter = null)),
          const SizedBox(width: 8),
          _filterChip(
            label: 'Pending',
            selected: _statusFilter == InvoiceStatus.pending,
            onTap: () => setState(() => _statusFilter = InvoiceStatus.pending),
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: 'Paid',
            selected: _statusFilter == InvoiceStatus.paid,
            onTap: () => setState(() => _statusFilter = InvoiceStatus.paid),
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: 'Overdue',
            selected: _statusFilter == InvoiceStatus.overdue,
            onTap: () => setState(() => _statusFilter = InvoiceStatus.overdue),
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: 'Cancelled',
            selected: _statusFilter == InvoiceStatus.cancelled,
            onTap: () => setState(() => _statusFilter = InvoiceStatus.cancelled),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0386FF) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? const Color(0xFF0386FF) : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          AppLocalizations.of(context)!.noInvoicesFound,
          style: GoogleFonts.inter(color: const Color(0xFF6B7280), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          AppLocalizations.of(context)!.failedToLoadInvoicesNMessage,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: const Color(0xFF6B7280), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

