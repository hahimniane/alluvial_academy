import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import 'package:alluwalacademyadmin/core/utils/export_helpers.dart';
import 'package:alluwalacademyadmin/features/parent/models/invoice.dart';
import 'package:alluwalacademyadmin/features/parent/models/payment.dart';
import 'package:alluwalacademyadmin/features/parent/utils/invoice_printing.dart';
import 'package:alluwalacademyadmin/features/parent/screens/invoice_detail_screen.dart';
import 'package:alluwalacademyadmin/features/parent/services/invoice_link_service.dart';
import 'package:alluwalacademyadmin/features/parent/services/invoice_pdf_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

enum _PaymentViewFilter {
  all,
  successful,
  pending,
  overdue,
  failed,
}

enum _InvoiceSortOption {
  newest,
  oldest,
  dueSoon,
  parent,
  balanceHigh,
}

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
  _PaymentViewFilter _paymentFilter = _PaymentViewFilter.all;
  _InvoiceSortOption _sortOption = _InvoiceSortOption.newest;
  DateTimeRange? _dateRangeFilter;
  final Map<String, String> _nameCache = {};

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

  String _cachedParentName(String parentId) {
    final cached = _nameCache[parentId];
    if (cached != null && cached.isNotEmpty) return cached;
    _resolveName(parentId).then((_) {
      if (mounted) setState(() {});
    });
    return parentId;
  }

  String _cachedName(String userId) {
    final cached = _nameCache[userId];
    if (cached != null && cached.isNotEmpty) return cached;
    _resolveName(userId).then((_) {
      if (mounted) setState(() {});
    });
    return userId;
  }

  Stream<List<Invoice>> _invoiceStream() {
    Query query = _firestore.collection('invoices');
    if (_statusFilter != null) {
      query = query.where('status', isEqualTo: _statusFilter!.name);
    }
    query = query.orderBy('created_at', descending: true).limit(200);

    return query.snapshots().map((snap) {
      return snap.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
    });
  }

  String _invoicePaymentLink(Invoice invoice) {
    final stored =
        (invoice.reusablePaymentLink ?? invoice.paymentLink ?? '').trim();
    if (stored.isNotEmpty) return stored;
    return InvoiceLinkService.buildInvoiceLink(invoice.id);
  }

  Future<void> _copyPaymentLink(Invoice invoice) async {
    final l10n = AppLocalizations.of(context)!;
    final link = _invoicePaymentLink(invoice);
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.adminInvoicePaymentLinkCopied)),
    );
  }

  Future<void> _exportInvoicesAndPayments(List<Invoice> invoices) async {
    final l10n = AppLocalizations.of(context)!;
    final invoiceSheet = l10n.adminInvoiceExportInvoicesSheet;
    final transactionsSheet = l10n.adminInvoiceExportTransactionsSheet;

    // Resolve every parent & student name up front — raw document IDs are
    // useless in an audit/finance report, so the export shows names instead.
    final idsToResolve = <String>{};
    for (final invoice in invoices) {
      if (invoice.parentId.isNotEmpty) idsToResolve.add(invoice.parentId);
      if (invoice.studentId.isNotEmpty) idsToResolve.add(invoice.studentId);
    }
    await Future.wait(idsToResolve.map(_resolveName));

    final invoiceById = {for (final invoice in invoices) invoice.id: invoice};

    // Load every payment tied to the listed invoices.
    final payments = <Payment>[];
    for (final batch in _chunks(invoiceById.keys.toList(), 10)) {
      final snap = await _firestore
          .collection('payments')
          .where('invoice_id', whereIn: batch)
          .get();
      payments.addAll(snap.docs.map(Payment.fromFirestore));
    }
    await Future.wait(
      payments
          .map((payment) => payment.parentId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .map(_resolveName),
    );

    final invoiceRows = invoices.map((invoice) {
      return <dynamic>[
        invoice.invoiceNumber,
        _displayName(invoice.parentId),
        _displayName(invoice.studentId),
        invoice.displayBillingPeriod ?? '',
        _invoiceStatusLabel(l10n, invoice),
        invoice.totalAmount,
        invoice.paidAmount,
        invoice.remainingBalance,
        invoice.currency,
        _formatExportDate(invoice.issuedDate),
        _formatExportDate(invoice.dueDate),
        invoice.recurringEnabled ? l10n.commonYes : l10n.commonNo,
        _invoicePaymentLink(invoice),
      ];
    }).toList();

    final paymentRows = payments.map((payment) {
      final invoice = invoiceById[payment.invoiceId];
      final parentId = payment.parentId.isNotEmpty
          ? payment.parentId
          : (invoice?.parentId ?? '');
      return <dynamic>[
        invoice?.invoiceNumber ?? payment.invoiceId,
        parentId.isEmpty ? '' : _displayName(parentId),
        payment.amount,
        _titleCase(payment.status.name),
        _titleCase(payment.paymentMethod),
        _formatExportDateTime(payment.createdAt),
        _formatExportDateTime(payment.completedAt),
      ];
    }).toList();

    ExportHelpers.exportExcelMultiSheet(
      {
        invoiceSheet: [
          l10n.adminInvoiceExportInvoiceNumber,
          l10n.adminInvoiceExportParentName,
          l10n.adminInvoiceExportStudentName,
          l10n.adminInvoiceExportBillingPeriod,
          l10n.adminInvoiceExportInvoiceStatus,
          l10n.adminInvoiceExportTotalAmount,
          l10n.adminInvoiceExportPaidAmount,
          l10n.adminInvoiceExportOutstandingBalance,
          l10n.adminInvoiceExportCurrency,
          l10n.adminInvoiceExportIssuedDate,
          l10n.adminInvoiceExportDueDate,
          l10n.adminInvoiceExportRecurringEnabled,
          l10n.adminInvoiceExportPaymentLink,
        ],
        transactionsSheet: [
          l10n.adminInvoiceExportInvoiceNumber,
          l10n.adminInvoiceExportParentName,
          l10n.adminInvoiceExportAmount,
          l10n.adminInvoiceExportPaymentStatus,
          l10n.adminInvoiceExportPaymentMethod,
          l10n.adminInvoiceExportCreatedAt,
          l10n.adminInvoiceExportCompletedAt,
        ],
      },
      {
        invoiceSheet: invoiceRows,
        transactionsSheet: paymentRows,
      },
      'invoice_payment_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
    );
  }

  List<List<T>> _chunks<T>(List<T> values, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < values.length; i += size) {
      chunks.add(values.skip(i).take(size).toList());
    }
    return chunks;
  }

  /// Name from the resolve cache, or the raw id if it hasn't resolved.
  String _displayName(String userId) {
    final cached = _nameCache[userId];
    if (cached != null && cached.isNotEmpty) return cached;
    return userId;
  }

  String _invoiceStatusLabel(AppLocalizations l10n, Invoice invoice) {
    if (invoice.isOverdue) return l10n.overdue;
    switch (invoice.status) {
      case InvoiceStatus.paid:
        return l10n.parentInvoicesPaid;
      case InvoiceStatus.cancelled:
        return l10n.shiftStatusCancelled;
      case InvoiceStatus.overdue:
        return l10n.overdue;
      case InvoiceStatus.pending:
        return l10n.shiftStatusPending;
    }
  }

  String _titleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  String _formatExportDate(DateTime? value) {
    if (value == null) return '';
    return DateFormat('yyyy-MM-dd').format(value);
  }

  String _formatExportDateTime(DateTime? value) {
    if (value == null) return '';
    return DateFormat('yyyy-MM-dd HH:mm').format(value);
  }

  List<Invoice> _applyClientFilters(List<Invoice> invoices) {
    var filtered = List<Invoice>.from(invoices);

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((invoice) {
        final parentName = _cachedParentName(invoice.parentId).toLowerCase();
        final studentName = _cachedName(invoice.studentId).toLowerCase();
        return invoice.parentId.toLowerCase().contains(query) ||
            invoice.studentId.toLowerCase().contains(query) ||
            invoice.invoiceNumber.toLowerCase().contains(query) ||
            invoice.id.toLowerCase().contains(query) ||
            (invoice.period ?? '').toLowerCase().contains(query) ||
            (invoice.displayBillingPeriod ?? '')
                .toLowerCase()
                .contains(query) ||
            parentName.contains(query) ||
            studentName.contains(query);
      }).toList();
    }

    final range = _dateRangeFilter;
    if (range != null) {
      final start =
          DateTime(range.start.year, range.start.month, range.start.day);
      final end =
          DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
      filtered = filtered
          .where((invoice) =>
              !invoice.dueDate.isBefore(start) && !invoice.dueDate.isAfter(end))
          .toList();
    }

    filtered = filtered.where((invoice) {
      switch (_paymentFilter) {
        case _PaymentViewFilter.all:
          return true;
        case _PaymentViewFilter.successful:
          return invoice.isFullyPaid || invoice.status == InvoiceStatus.paid;
        case _PaymentViewFilter.pending:
          return !invoice.isOverdue &&
              invoice.remainingBalance > 0 &&
              invoice.status != InvoiceStatus.cancelled;
        case _PaymentViewFilter.overdue:
          return invoice.isOverdue || invoice.status == InvoiceStatus.overdue;
        case _PaymentViewFilter.failed:
          return invoice.status == InvoiceStatus.cancelled;
      }
    }).toList();

    filtered.sort((a, b) {
      switch (_sortOption) {
        case _InvoiceSortOption.newest:
          return (b.createdAt ?? b.issuedDate)
              .compareTo(a.createdAt ?? a.issuedDate);
        case _InvoiceSortOption.oldest:
          return (a.createdAt ?? a.issuedDate)
              .compareTo(b.createdAt ?? b.issuedDate);
        case _InvoiceSortOption.dueSoon:
          return a.dueDate.compareTo(b.dueDate);
        case _InvoiceSortOption.parent:
          return _cachedParentName(a.parentId)
              .toLowerCase()
              .compareTo(_cachedParentName(b.parentId).toLowerCase());
        case _InvoiceSortOption.balanceHigh:
          return b.remainingBalance.compareTo(a.remainingBalance);
      }
    });

    return filtered;
  }

  String _paymentFilterLabel(
    AppLocalizations l10n,
    _PaymentViewFilter filter,
  ) {
    switch (filter) {
      case _PaymentViewFilter.all:
        return l10n.adminInvoiceFilterAll;
      case _PaymentViewFilter.successful:
        return l10n.adminInvoicePaymentFilterSuccessful;
      case _PaymentViewFilter.pending:
        return l10n.adminInvoicePaymentFilterPending;
      case _PaymentViewFilter.overdue:
        return l10n.adminInvoicePaymentFilterOverdue;
      case _PaymentViewFilter.failed:
        return l10n.adminInvoicePaymentFilterFailed;
    }
  }

  String _sortLabel(AppLocalizations l10n, _InvoiceSortOption option) {
    switch (option) {
      case _InvoiceSortOption.newest:
        return l10n.adminInvoiceSortNewest;
      case _InvoiceSortOption.oldest:
        return l10n.adminInvoiceSortOldest;
      case _InvoiceSortOption.dueSoon:
        return l10n.adminInvoiceSortDueSoon;
      case _InvoiceSortOption.parent:
        return l10n.adminInvoiceSortParent;
      case _InvoiceSortOption.balanceHigh:
        return l10n.adminInvoiceSortBalance;
    }
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
                    _buildReportingFilters(l10n),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Invoice>>(
                  stream: _invoiceStream(),
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

                    final invoices = _applyClientFilters(snapshot.data ?? []);

                    if (invoices.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long,
                                size: 48, color: const Color(0xFFCBD5E1)),
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
                      itemCount: invoices.length + 1,
                      separatorBuilder: (_, index) =>
                          SizedBox(height: index == 0 ? 14 : 10),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildInvoiceReportHeader(l10n, invoices);
                        }
                        final invoice = invoices[index - 1];
                        return _buildInvoiceCard(context, invoice, l10n);
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

  Widget _buildInvoiceReportHeader(
    AppLocalizations l10n,
    List<Invoice> invoices,
  ) {
    final money = NumberFormat.simpleCurrency(name: 'USD');
    final totalIssued = invoices.fold<double>(
      0,
      (total, invoice) => total + invoice.totalAmount,
    );
    final totalReceived = invoices.fold<double>(
      0,
      (total, invoice) => total + invoice.paidAmount,
    );
    final outstanding = invoices.fold<double>(
      0,
      (total, invoice) => total + invoice.remainingBalance,
    );
    final overdueCount = invoices.where((invoice) => invoice.isOverdue).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.adminInvoiceReportingTitle,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _exportInvoicesAndPayments(invoices),
                icon: const Icon(Icons.table_chart_rounded, size: 17),
                label: Text(l10n.adminInvoiceExportExcel),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricPill(l10n.invoices, invoices.length.toString()),
              _metricPill(
                  l10n.adminInvoiceMetricIssued, money.format(totalIssued)),
              _metricPill(
                  l10n.adminInvoiceMetricReceived, money.format(totalReceived)),
              _metricPill(l10n.adminInvoiceMetricOutstanding,
                  money.format(outstanding)),
              _metricPill(l10n.adminInvoicePaymentFilterOverdue,
                  overdueCount.toString(),
                  color: const Color(0xFFF97316)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricPill(String label, String value, {Color? color}) {
    final accent = color ?? const Color(0xFF38BDF8);
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

  Widget _buildReportingFilters(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filterTextField(
          controller: _searchController,
          hint: l10n.adminInvoiceSearchHintUnified,
          icon: Icons.manage_search_rounded,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _statusMenuButton(l10n),
            _paymentMenuButton(l10n),
            _dateRangeButton(l10n),
            _sortMenuButton(l10n),
            if (_dateRangeFilter != null ||
                _searchController.text.trim().isNotEmpty ||
                _statusFilter != null ||
                _paymentFilter != _PaymentViewFilter.all)
              _clearFiltersButton(l10n),
          ],
        ),
      ],
    );
  }

  Widget _filterTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
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
        controller: controller,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.inter(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _dateRangeButton(AppLocalizations l10n) {
    final range = _dateRangeFilter;
    final label = range == null
        ? l10n.adminInvoiceDueDateFilter
        : '${DateFormat.MMMd().format(range.start)} - ${DateFormat.MMMd().format(range.end)}';
    return _toolbarButton(
      icon: Icons.date_range_rounded,
      label: label,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          initialDateRange: range,
          firstDate: DateTime(now.year - 3),
          lastDate: DateTime(now.year + 3),
        );
        if (picked != null) {
          setState(() => _dateRangeFilter = picked);
        }
      },
    );
  }

  Widget _sortMenuButton(AppLocalizations l10n) {
    return PopupMenuButton<_InvoiceSortOption>(
      initialValue: _sortOption,
      onSelected: (value) => setState(() => _sortOption = value),
      itemBuilder: (_) => _InvoiceSortOption.values
          .map(
            (option) => PopupMenuItem(
              value: option,
              child: Text(_sortLabel(l10n, option), style: GoogleFonts.inter()),
            ),
          )
          .toList(),
      child: _toolbarButton(
        icon: Icons.sort_rounded,
        label: _sortLabel(l10n, _sortOption),
        onTap: null,
      ),
    );
  }

  Widget _statusMenuButton(AppLocalizations l10n) {
    final label = _statusFilter == null
        ? 'Status: ${l10n.adminInvoiceFilterAll}'
        : 'Status: ${_invoiceStatusFilterLabel(l10n, _statusFilter!)}';
    return PopupMenuButton<InvoiceStatus?>(
      initialValue: _statusFilter,
      onSelected: (value) => setState(() => _statusFilter = value),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: null,
          child: Text(l10n.adminInvoiceFilterAll, style: GoogleFonts.inter()),
        ),
        ...InvoiceStatus.values.map(
          (status) => PopupMenuItem(
            value: status,
            child: Text(
              _invoiceStatusFilterLabel(l10n, status),
              style: GoogleFonts.inter(),
            ),
          ),
        ),
      ],
      child: _toolbarButton(
        icon: Icons.tune_rounded,
        label: label,
        onTap: null,
      ),
    );
  }

  Widget _paymentMenuButton(AppLocalizations l10n) {
    return PopupMenuButton<_PaymentViewFilter>(
      initialValue: _paymentFilter,
      onSelected: (value) => setState(() => _paymentFilter = value),
      itemBuilder: (_) => _PaymentViewFilter.values
          .map(
            (filter) => PopupMenuItem(
              value: filter,
              child: Text(_paymentFilterLabel(l10n, filter),
                  style: GoogleFonts.inter()),
            ),
          )
          .toList(),
      child: _toolbarButton(
        icon: Icons.payments_rounded,
        label: 'Payment: ${_paymentFilterLabel(l10n, _paymentFilter)}',
        onTap: null,
      ),
    );
  }

  String _invoiceStatusFilterLabel(
      AppLocalizations l10n, InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.pending:
        return l10n.shiftStatusPending;
      case InvoiceStatus.paid:
        return l10n.parentInvoicesPaid;
      case InvoiceStatus.overdue:
        return l10n.overdue;
      case InvoiceStatus.cancelled:
        return l10n.shiftStatusCancelled;
    }
  }

  Widget _clearFiltersButton(AppLocalizations l10n) {
    return _toolbarButton(
      icon: Icons.close_rounded,
      label: l10n.adminInvoiceClearFiltersShort,
      onTap: () {
        setState(() {
          _searchController.clear();
          _statusFilter = null;
          _paymentFilter = _PaymentViewFilter.all;
          _dateRangeFilter = null;
          _sortOption = _InvoiceSortOption.newest;
        });
      },
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
          ],
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
                    const SizedBox(width: 8),
                    _actionButton(
                      icon: Icons.link_rounded,
                      label: l10n.adminInvoiceCopyLink,
                      onTap: () => _copyPaymentLink(invoice),
                    ),
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
