import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import 'package:alluwalacademyadmin/features/parent/models/invoice.dart';
import 'package:alluwalacademyadmin/features/parent/utils/invoice_printing.dart';
import 'package:alluwalacademyadmin/features/parent/screens/invoice_detail_screen.dart';
import 'package:alluwalacademyadmin/features/parent/services/invoice_pdf_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Admin screen to view, edit, and delete all invoices.
class AdminInvoicesScreen extends StatefulWidget {
  const AdminInvoicesScreen({super.key});

  @override
  State<AdminInvoicesScreen> createState() => _AdminInvoicesScreenState();
}

class _AdminInvoicesScreenState extends State<AdminInvoicesScreen> {
  final _searchController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  InvoiceStatus? _statusFilter;
  final Map<String, String> _nameCache = {};
  final Map<String, _InvoiceUserSearchData?> _userSearchCache = {};
  final Map<String, Future<_InvoiceUserSearchData?>> _userSearchFutures = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String> _resolveName(String userId) async {
    if (_nameCache.containsKey(userId)) return _nameCache[userId]!;
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final name =
            '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
        _nameCache[userId] = name.isNotEmpty ? name : userId;
      } else {
        _nameCache[userId] = userId;
      }
    } catch (_) {
      _nameCache[userId] = userId;
    }
    return _nameCache[userId]!;
  }

  Future<_InvoiceUserSearchData?> _resolveUserSearchData(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return Future.value(null);
    if (_userSearchCache.containsKey(id)) {
      return Future.value(_userSearchCache[id]);
    }
    return _userSearchFutures.putIfAbsent(id, () async {
      try {
        final doc = await _firestore.collection('users').doc(id).get();
        if (!doc.exists) {
          _userSearchCache[id] = _InvoiceUserSearchData(id: id);
          return _userSearchCache[id];
        }
        final data = doc.data() ?? const <String, dynamic>{};
        final user = _InvoiceUserSearchData.fromMap(id, data);
        _userSearchCache[id] = user;
        return user;
      } catch (e) {
        AppLogger.error(
            'AdminInvoices: failed to load user $id for search: $e');
        _userSearchCache[id] = _InvoiceUserSearchData(id: id);
        return _userSearchCache[id];
      } finally {
        _userSearchFutures.remove(id);
      }
    });
  }

  Future<String> _invoiceSearchText(Invoice invoice) async {
    final parts = <String>[
      invoice.id,
      invoice.invoiceNumber,
      invoice.parentId,
      invoice.studentId,
      invoice.status.name,
      invoice.currency,
      invoice.totalAmount.toStringAsFixed(2),
      invoice.remainingBalance.toStringAsFixed(2),
      DateFormat.yMd().format(invoice.issuedDate),
      DateFormat.yMd().format(invoice.dueDate),
      invoice.period ?? '',
      invoice.displayBillingPeriod ?? '',
    ];

    final parent = await _resolveUserSearchData(invoice.parentId);
    if (parent != null) {
      parts.addAll(parent.searchTerms);
      for (final childId in parent.childrenIds.take(30)) {
        final child = await _resolveUserSearchData(childId);
        if (child != null) parts.addAll(child.searchTerms);
      }
    }

    final student = await _resolveUserSearchData(invoice.studentId);
    if (student != null) parts.addAll(student.searchTerms);

    return parts.join(' ').toLowerCase();
  }

  Future<List<Invoice>> _filterInvoicesForSearch(
    List<Invoice> invoices,
    String query,
  ) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return invoices;

    final terms = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((term) => term.trim().isNotEmpty)
        .toList();
    final queryDigits = _digitsOnly(normalizedQuery);
    final matches = await Future.wait(invoices.map((invoice) async {
      final text = await _invoiceSearchText(invoice);
      final textDigits = _digitsOnly(text);
      final textMatch = terms.every(text.contains);
      final phoneMatch = queryDigits.length >= 3 &&
          textDigits.isNotEmpty &&
          textDigits.contains(queryDigits);
      return textMatch || phoneMatch;
    }));

    return [
      for (var i = 0; i < invoices.length; i++)
        if (matches[i]) invoices[i],
    ];
  }

  static String _digitsOnly(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  Stream<List<Invoice>> _invoiceStream({bool expanded = false}) {
    Query query = _firestore.collection('invoices');
    if (_statusFilter != null) {
      query = query.where('status', isEqualTo: _statusFilter!.name);
    }
    query = query.orderBy('created_at', descending: true);
    if (!expanded) {
      query = query.limit(200);
    }

    return query.snapshots().map((snap) {
      return snap.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
    });
  }

  Future<void> _deleteInvoice(Invoice invoice) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.adminInvoiceDeleteTitle,
            style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
          l10n.adminInvoiceDeleteConfirm(
            invoice.invoiceNumber.isNotEmpty
                ? invoice.invoiceNumber
                : invoice.id,
          ),
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(l10n.adminInvoiceDelete,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('invoices').doc(invoice.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('${l10n.adminInvoiceDelete}: ${invoice.invoiceNumber}'),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.error}: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  Future<void> _editInvoice(Invoice invoice) async {
    await showDialog(
      context: context,
      builder: (ctx) => _EditInvoiceDialog(invoice: invoice),
    );
  }

  Future<void> _recordPayment(Invoice invoice) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _RecordPaymentDialog(invoice: invoice),
    );
    if (saved == true && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.adminInvoicePaymentSuccess),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    }
  }

  Future<Uint8List> _buildPdfBytes(Invoice invoice) {
    return InvoicePdfService.generateInvoicePDF(invoice).timeout(
      const Duration(seconds: 45),
      onTimeout: () => throw TimeoutException('invoice_pdf'),
    );
  }

  Future<void> _downloadPdf(Invoice invoice) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final pdfBytes = await _buildPdfBytes(invoice);
      final safeName = (invoice.invoiceNumber.isNotEmpty
              ? invoice.invoiceNumber
              : invoice.id)
          .replaceAll(RegExp(r'[^\w\-]+'), '_');

      if (!mounted) return;
      Navigator.of(context).pop();

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Invoice_$safeName.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminInvoiceDownloadPdf)),
        );
      }
    } catch (e) {
      AppLogger.error('AdminInvoices: PDF download failed: $e');
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _printPdf(Invoice invoice) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final pdfBytes = await _buildPdfBytes(invoice);
      if (!mounted) return;
      Navigator.of(context).pop();
      final safeName = (invoice.invoiceNumber.isNotEmpty
              ? invoice.invoiceNumber
              : invoice.id)
          .replaceAll(RegExp(r'[^\w\-]+'), '_');
      await presentInvoicePdfBytes(
        bytes: pdfBytes,
        filename: 'Invoice_${safeName}_print.pdf',
      );
    } catch (e) {
      AppLogger.error('AdminInvoices: PDF print failed: $e');
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;
    final contentWidth = isWide ? 900.0 : double.infinity;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentWidth),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.receipt_long,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.adminInvoicesTitle,
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.adminInvoicesSubtitle,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.inter(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: l10n.searchInvoiceNumber,
                          hintStyle: GoogleFonts.inter(
                              color: const Color(0xFF94A3B8), fontSize: 14),
                          prefixIcon: const Icon(Icons.search,
                              color: Color(0xFF94A3B8), size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFilterChips(l10n),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Invoice>>(
                  stream: _invoiceStream(
                    expanded: _searchController.text.trim().isNotEmpty,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '${l10n.failedToLoadInvoicesNMessage}: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                color: const Color(0xFF94A3B8)),
                          ),
                        ),
                      );
                    }

                    final allInvoices = snapshot.data ?? [];
                    final query = _searchController.text.trim().toLowerCase();
                    if (query.isEmpty) {
                      return _buildInvoiceList(allInvoices, l10n);
                    }
                    return FutureBuilder<List<Invoice>>(
                      future: _filterInvoicesForSearch(allInvoices, query),
                      builder: (context, filteredSnapshot) {
                        if (filteredSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            query.isNotEmpty) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (filteredSnapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '${l10n.failedToLoadInvoicesNMessage}: ${filteredSnapshot.error}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                    color: const Color(0xFF94A3B8)),
                              ),
                            ),
                          );
                        }

                        final invoices =
                            filteredSnapshot.data ?? const <Invoice>[];
                        return _buildInvoiceList(invoices, l10n);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceList(List<Invoice> invoices, AppLocalizations l10n) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 48, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              l10n.noInvoicesFound,
              style: GoogleFonts.inter(
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      itemCount: invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        return _buildInvoiceCard(context, invoice, l10n);
      },
    );
  }

  Widget _buildFilterChips(AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(l10n.adminInvoiceFilterAll, _statusFilter == null,
              () => setState(() => _statusFilter = null)),
          const SizedBox(width: 8),
          _chip(l10n.shiftStatusPending, _statusFilter == InvoiceStatus.pending,
              () => setState(() => _statusFilter = InvoiceStatus.pending)),
          const SizedBox(width: 8),
          _chip(l10n.parentInvoicesPaid, _statusFilter == InvoiceStatus.paid,
              () => setState(() => _statusFilter = InvoiceStatus.paid)),
          const SizedBox(width: 8),
          _chip(l10n.overdue, _statusFilter == InvoiceStatus.overdue,
              () => setState(() => _statusFilter = InvoiceStatus.overdue)),
          const SizedBox(width: 8),
          _chip(
              l10n.shiftStatusCancelled,
              _statusFilter == InvoiceStatus.cancelled,
              () => setState(() => _statusFilter = InvoiceStatus.cancelled)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0386FF) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color:
                  selected ? const Color(0xFF0386FF) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(
      BuildContext context, Invoice invoice, AppLocalizations l10n) {
    final money = NumberFormat.simpleCurrency(name: invoice.currency);
    final statusLabel = invoice.isOverdue
        ? l10n.overdue.toUpperCase()
        : invoice.status.name.toUpperCase();
    final statusColor = _statusColor(invoice);
    final dateLabel = DateFormat.yMMMd().format(invoice.issuedDate);
    final billing = invoice.displayBillingPeriod;
    final notificationStatus =
        (invoice.notificationStatus ?? '').toLowerCase().trim();

    return FutureBuilder<String>(
      future: _resolveName(invoice.parentId),
      builder: (context, parentSnap) {
        final parentName = parentSnap.data ?? '...';
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          InvoiceDetailScreen(invoiceId: invoice.id),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Icon(Icons.receipt,
                                  color: statusColor, size: 18),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  invoice.invoiceNumber.isNotEmpty
                                      ? invoice.invoiceNumber
                                      : l10n.invoices,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  parentName,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: const Color(0xFFCBD5E1), size: 22),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusLabel,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _infoTag(Icons.calendar_today_rounded, dateLabel),
                          _infoTag(Icons.attach_money_rounded,
                              money.format(invoice.totalAmount),
                              bold: true),
                          if (billing != null)
                            _infoTag(
                              Icons.date_range_rounded,
                              l10n.adminInvoiceBillingPeriodChip(billing),
                              color: const Color(0xFF0369A1),
                            ),
                          if (notificationStatus == 'failed')
                            _infoTag(
                              Icons.mark_email_unread_rounded,
                              l10n.adminInvoiceSendFailed,
                              color: const Color(0xFFDC2626),
                            ),
                          if (notificationStatus == 'pending')
                            _infoTag(
                              Icons.schedule_send_rounded,
                              l10n.adminInvoiceSendPending,
                              color: const Color(0xFFD97706),
                            ),
                          if (invoice.remainingBalance > 0 &&
                              !invoice.isFullyPaid)
                            _infoTag(
                                Icons.pending_rounded,
                                l10n.adminInvoiceBalanceDue(
                                    money.format(invoice.remainingBalance)),
                                color: const Color(0xFFDC2626)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _actionButton(
                      icon: Icons.download_rounded,
                      label: l10n.adminInvoiceDownloadPdf,
                      onTap: () => _downloadPdf(invoice),
                    ),
                    const SizedBox(width: 8),
                    _actionButton(
                      icon: Icons.print_rounded,
                      label: l10n.adminInvoicePrintPdf,
                      onTap: () => _printPdf(invoice),
                    ),
                    if (invoice.remainingBalance > 0 &&
                        invoice.status != InvoiceStatus.cancelled) ...[
                      const SizedBox(width: 8),
                      _actionButton(
                        icon: Icons.payments_rounded,
                        label: l10n.adminInvoiceRecordPayment,
                        color: const Color(0xFF047857),
                        onTap: () => _recordPayment(invoice),
                      ),
                    ],
                    const SizedBox(width: 8),
                    _actionButton(
                      icon: Icons.edit_rounded,
                      label: l10n.adminInvoiceEdit,
                      onTap: () => _editInvoice(invoice),
                    ),
                    const SizedBox(width: 8),
                    _actionButton(
                      icon: Icons.delete_outline_rounded,
                      label: l10n.adminInvoiceDelete,
                      color: const Color(0xFFDC2626),
                      onTap: () => _deleteInvoice(invoice),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoTag(IconData icon, String label,
      {bool bold = false, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? const Color(0xFF334155);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40, maxWidth: 200),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: c),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: c,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Color _statusColor(Invoice invoice) {
    if (invoice.isOverdue) return const Color(0xFFDC2626);
    switch (invoice.status) {
      case InvoiceStatus.paid:
        return const Color(0xFF16A34A);
      case InvoiceStatus.cancelled:
        return const Color(0xFF6B7280);
      case InvoiceStatus.pending:
      case InvoiceStatus.overdue:
        return const Color(0xFFF59E0B);
    }
  }
}

class _InvoiceUserSearchData {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String studentCode;
  final String kioskCode;
  final List<String> childrenIds;

  const _InvoiceUserSearchData({
    required this.id,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.studentCode = '',
    this.kioskCode = '',
    this.childrenIds = const [],
  });

  factory _InvoiceUserSearchData.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final first = (data['first_name'] ?? '').toString().trim();
    final last = (data['last_name'] ?? '').toString().trim();
    final displayName =
        (data['displayName'] ?? data['name'] ?? '').toString().trim();
    final name = ('$first $last').trim();
    final countryCode =
        (data['country_code'] ?? data['countryCode'] ?? '').toString().trim();
    final phone = (data['phone_number'] ??
            data['mobile_phone'] ??
            data['phone'] ??
            data['mobilePhone'] ??
            '')
        .toString()
        .trim();
    return _InvoiceUserSearchData(
      id: id,
      name: name.isNotEmpty ? name : displayName,
      email: (data['e-mail'] ?? data['email'] ?? '').toString(),
      phone: [countryCode, phone]
          .where((part) => part.trim().isNotEmpty)
          .join(' '),
      studentCode: (data['student_code'] ??
              data['studentCode'] ??
              data['student_id'] ??
              '')
          .toString(),
      kioskCode: (data['kiosk_code'] ?? data['kiosqueCode'] ?? '').toString(),
      childrenIds: {
        ...((data['children_ids'] as List?)?.map((e) => e.toString()) ??
            const <String>[]),
        ...((data['childrenIds'] as List?)?.map((e) => e.toString()) ??
            const <String>[]),
      }.where((id) => id.trim().isNotEmpty).toList(),
    );
  }

  List<String> get searchTerms => [
        id,
        name,
        email,
        phone,
        studentCode,
        kioskCode,
        _digitsOnly(phone),
      ].where((term) => term.trim().isNotEmpty).toList();

  static String _digitsOnly(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');
}

class _RecordPaymentDialog extends StatefulWidget {
  final Invoice invoice;

  const _RecordPaymentDialog({required this.invoice});

  @override
  State<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<_RecordPaymentDialog> {
  late final TextEditingController _amountController;
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();
  String _method = 'zelle';
  late DateTime _receivedDate;
  bool _isSaving = false;
  String? _error;

  static const _methods = [
    'zelle',
    'cash_app',
    'bank_transfer',
    'moneygram',
    'western_union',
    'cash',
    'check',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.invoice.remainingBalance.toStringAsFixed(2),
    );
    final now = DateTime.now();
    _receivedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null ||
        amount <= 0 ||
        amount > widget.invoice.remainingBalance) {
      setState(() => _error = l10n.adminInvoicePaymentInvalidAmount);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('recordManualPayment');
      await callable.call({
        'invoiceId': widget.invoice.id,
        'amount': amount,
        'paymentMethod': _method,
        'reference': _referenceController.text.trim(),
        'note': _noteController.text.trim(),
        'receivedAt': _receivedDate.toIso8601String(),
      });
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
    final money = NumberFormat.simpleCurrency(name: widget.invoice.currency);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Icon(
                      Icons.payments_rounded,
                      color: Color(0xFF047857),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.adminInvoiceRecordPaymentTitle,
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.invoice.invoiceNumber} · ${l10n.adminInvoiceBalanceDue(money.format(widget.invoice.remainingBalance))}',
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
                  IconButton(
                    tooltip: l10n.commonClose,
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _dialogLabel(l10n.adminInvoicePaymentAmount),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                decoration:
                    _inputDecoration(prefixText: '${widget.invoice.currency} '),
              ),
              const SizedBox(height: 12),
              _dialogLabel(l10n.adminInvoicePaymentMethod),
              const SizedBox(height: 6),
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _method,
                    isExpanded: true,
                    items: _methods
                        .map(
                          (method) => DropdownMenuItem(
                            value: method,
                            child: Text(
                              _methodLabel(l10n, method),
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value != null) setState(() => _method = value);
                          },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _dialogLabel(l10n.adminInvoicePaymentReceivedDate),
              const SizedBox(height: 6),
              InkWell(
                onTap: _isSaving
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _receivedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) {
                          setState(() => _receivedDate = picked);
                        }
                      },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat.yMMMd().format(_receivedDate),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _dialogLabel(l10n.adminInvoicePaymentReference),
              const SizedBox(height: 6),
              TextField(
                controller: _referenceController,
                decoration: _inputDecoration(
                  hintText: l10n.adminInvoicePaymentReferenceHint,
                ),
              ),
              const SizedBox(height: 12),
              _dialogLabel(l10n.adminInvoicePaymentNote),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 3,
                decoration: _inputDecoration(
                  hintText: l10n.adminInvoicePaymentNoteHint,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    _error!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF991B1B),
                    ),
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
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(l10n.adminInvoiceRecordPayment),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
    );
  }

  Widget _dialogLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF475569),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText, String? prefixText}) {
    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFF94A3B8),
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  String _methodLabel(AppLocalizations l10n, String method) {
    switch (method) {
      case 'zelle':
        return l10n.adminInvoicePaymentMethodZelle;
      case 'cash_app':
        return l10n.adminInvoicePaymentMethodCashApp;
      case 'bank_transfer':
        return l10n.adminInvoicePaymentMethodBankTransfer;
      case 'moneygram':
        return l10n.adminInvoicePaymentMethodMoneyGram;
      case 'western_union':
        return l10n.adminInvoicePaymentMethodWesternUnion;
      case 'cash':
        return l10n.adminInvoicePaymentMethodCash;
      case 'check':
        return l10n.adminInvoicePaymentMethodCheck;
      default:
        return l10n.adminInvoicePaymentMethodOther;
    }
  }
}

class _EditInvoiceDialog extends StatefulWidget {
  final Invoice invoice;
  const _EditInvoiceDialog({required this.invoice});

  @override
  State<_EditInvoiceDialog> createState() => _EditInvoiceDialogState();
}

class _EditInvoiceDialogState extends State<_EditInvoiceDialog> {
  late InvoiceStatus _status;
  late TextEditingController _totalController;
  late TextEditingController _paidController;
  late TextEditingController _periodController;
  late DateTime _dueDate;
  late DateTime _accessCutoffDate;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _status = widget.invoice.status;
    _totalController = TextEditingController(
        text: widget.invoice.totalAmount.toStringAsFixed(2));
    _paidController = TextEditingController(
        text: widget.invoice.paidAmount.toStringAsFixed(2));
    _periodController =
        TextEditingController(text: widget.invoice.period ?? '');
    _dueDate = widget.invoice.dueDate;
    _accessCutoffDate = widget.invoice.effectiveAccessCutoffDate;
  }

  @override
  void dispose() {
    _totalController.dispose();
    _paidController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final total = double.tryParse(_totalController.text.trim());
    final paid = double.tryParse(_paidController.text.trim());
    if (total == null || paid == null || total < 0 || paid < 0) {
      setState(() => _error = l10n.adminInvoiceInvalidNumbers);
      return;
    }

    final periodTrim = _periodController.text.trim();
    if (periodTrim.isNotEmpty &&
        !RegExp(r'^\d{4}-\d{2}$').hasMatch(periodTrim)) {
      setState(() => _error = l10n.adminInvoiceEditBillingPeriodHint);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final updateData = <String, dynamic>{
        'status': _status.name,
        'total_amount': total,
        'paid_amount': paid,
        'due_date': Timestamp.fromDate(_dueDate),
        'access_cutoff_date': Timestamp.fromDate(_accessCutoffDate),
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (periodTrim.isEmpty) {
        updateData['period'] = FieldValue.delete();
      } else {
        updateData['period'] = periodTrim;
      }

      await FirebaseFirestore.instance
          .collection('invoices')
          .doc(widget.invoice.id)
          .update(updateData);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cur = widget.invoice.currency;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit,
                        color: Color(0xFF0386FF), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${l10n.adminInvoiceEdit} ${widget.invoice.invoiceNumber}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(l10n.status,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<InvoiceStatus>(
                    value: _status,
                    isExpanded: true,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: const Color(0xFF0F172A)),
                    items: InvoiceStatus.values
                        .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.name.toUpperCase(),
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _field('${l10n.total} ($cur)', _totalController),
              const SizedBox(height: 12),
              _field('${l10n.parentInvoicesPaid} ($cur)', _paidController),
              const SizedBox(height: 16),
              Text(l10n.adminInvoiceEditBillingPeriodLabel,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B))),
              const SizedBox(height: 6),
              TextField(
                controller: _periodController,
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: l10n.adminInvoiceEditBillingPeriodHint,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF0386FF), width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.dueDate,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B))),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setState(() {
                      _dueDate = picked;
                      // Clamp access cutoff if it would be before the new due date
                      if (_accessCutoffDate.isBefore(_dueDate)) {
                        _accessCutoffDate =
                            _dueDate.add(const Duration(days: 1));
                      }
                    });
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat.yMMMd().format(_dueDate),
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Access cutoff date',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B))),
              const SizedBox(height: 4),
              Text(
                'Students lose access if invoice unpaid by this date.',
                style: GoogleFonts.inter(
                    fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _accessCutoffDate.isBefore(_dueDate)
                        ? _dueDate
                        : _accessCutoffDate,
                    firstDate: _dueDate,
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setState(() => _accessCutoffDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock_rounded,
                          size: 16, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat.yMMMd().format(_accessCutoffDate),
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: GoogleFonts.inter(
                        color: const Color(0xFFDC2626),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(l10n.commonCancel,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0386FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(l10n.commonSave,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700)),
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

  Widget _field(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixText: '${widget.invoice.currency} ',
            prefixStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF0386FF), width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
