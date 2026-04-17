import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/parent/models/invoice.dart';
import 'package:alluwalacademyadmin/features/parent/services/invoice_data_service.dart';
import 'package:alluwalacademyadmin/features/settings/services/mock_company_service.dart'
    show CompanyInfo, AdminInfo;
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Professional, document-style invoice widget optimised for both mobile and web.
class BeautifulInvoiceWidget extends StatefulWidget {
  final Invoice invoice;

  const BeautifulInvoiceWidget({
    super.key,
    required this.invoice,
  });

  @override
  State<BeautifulInvoiceWidget> createState() => _BeautifulInvoiceWidgetState();
}

class _BeautifulInvoiceWidgetState extends State<BeautifulInvoiceWidget> {
  String? _parentName;
  String? _studentName;
  bool _isLoadingNames = true;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    try {
      final pair = await Future.wait([
        InvoiceDataService.getParentName(widget.invoice.parentId),
        InvoiceDataService.getStudentName(widget.invoice.studentId),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () => <String?>[null, null],
      );
      if (!mounted) return;
      setState(() {
        _parentName = pair[0];
        _studentName = pair[1];
        _isLoadingNames = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingNames = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final companyInfo = InvoiceDataService.getCompanyInfo();
    final adminInfo = InvoiceDataService.getAdminInfo();
    final money = NumberFormat.simpleCurrency(name: invoice.currency);
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 560;
      final padH = narrow ? 14.0 : 24.0;

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: 12),
        child: _InvoiceDocument(
          invoice: invoice,
          companyInfo: companyInfo,
          adminInfo: adminInfo,
          money: money,
          l10n: l10n,
          narrow: narrow,
          parentName: _isLoadingNames ? null : _parentName,
          studentName: _isLoadingNames ? null : _studentName,
          isLoadingNames: _isLoadingNames,
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────
// Internal document widget
// ─────────────────────────────────────────────────────────

class _InvoiceDocument extends StatelessWidget {
  const _InvoiceDocument({
    required this.invoice,
    required this.companyInfo,
    required this.adminInfo,
    required this.money,
    required this.l10n,
    required this.narrow,
    required this.parentName,
    required this.studentName,
    required this.isLoadingNames,
  });

  final Invoice invoice;
  final CompanyInfo companyInfo;
  final AdminInfo adminInfo;
  final NumberFormat money;
  final AppLocalizations l10n;
  final bool narrow;
  final String? parentName;
  final String? studentName;
  final bool isLoadingNames;

  static const _accent = Color(0xFF1A56DB);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);
  static const _divider = Color(0xFFE5E7EB);
  static const _bg = Color(0xFFF9FAFB);

  Color get _statusColor {
    switch (invoice.status) {
      case InvoiceStatus.paid:
        return const Color(0xFF059669);
      case InvoiceStatus.overdue:
        return const Color(0xFFDC2626);
      case InvoiceStatus.cancelled:
        return const Color(0xFF6B7280);
      case InvoiceStatus.pending:
        return const Color(0xFFD97706);
    }
  }

  String _statusLabel(AppLocalizations l10n) {
    if (invoice.isOverdue) return 'OVERDUE';
    switch (invoice.status) {
      case InvoiceStatus.paid:
        return 'PAID';
      case InvoiceStatus.overdue:
        return 'OVERDUE';
      case InvoiceStatus.cancelled:
        return 'CANCELLED';
      case InvoiceStatus.pending:
        return 'PENDING';
    }
  }

  @override
  Widget build(BuildContext context) {
    final invNo = invoice.invoiceNumber.isNotEmpty
        ? invoice.invoiceNumber
        : invoice.id;
    final dateFormat = DateFormat.yMMMMd();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top bar: accent strip ──
          Container(
            height: 5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(
                narrow ? 20 : 32, narrow ? 24 : 32,
                narrow ? 20 : 32, narrow ? 20 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header: logo + title + status ──
                _buildHeader(invNo, dateFormat),

                const SizedBox(height: 28),
                _Divider(color: _divider),
                const SizedBox(height: 24),

                // ── From / To ──
                narrow
                    ? _buildFromToNarrow(dateFormat)
                    : _buildFromToWide(dateFormat),

                const SizedBox(height: 24),
                _Divider(color: _divider),
                const SizedBox(height: 22),

                // ── Invoice meta row ──
                _buildMetaRow(invNo, dateFormat),

                const SizedBox(height: 28),

                // ── Line items ──
                _buildItemsSection(context),

                const SizedBox(height: 24),

                // ── Summary ──
                _buildSummary(context),

                const SizedBox(height: 24),
                _Divider(color: _divider),
                const SizedBox(height: 20),

                // ── Footer ──
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────

  Widget _buildHeader(String invNo, DateFormat dateFormat) {
    final statusLabel = _statusLabel(l10n);
    final color = invoice.isOverdue ? const Color(0xFFDC2626) : _statusColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A56DB).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                'assets/Alluwal_Education_Hub_Logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.school_rounded,
                  color: _accent,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                companyInfo.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                companyInfo.email,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'INVOICE',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _accent,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            // Status badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── From / To (wide) ────────────────────────────────────

  Widget _buildFromToWide(DateFormat dateFormat) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildFromBlock()),
        const SizedBox(width: 24),
        Expanded(child: _buildToBlock(dateFormat)),
      ],
    );
  }

  Widget _buildFromToNarrow(DateFormat dateFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFromBlock(),
        const SizedBox(height: 20),
        _buildToBlock(dateFormat),
      ],
    );
  }

  Widget _buildFromBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'FROM'),
        const SizedBox(height: 10),
        Text(
          companyInfo.name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          companyInfo.fullAddress,
          style: const TextStyle(
            fontSize: 13,
            color: _textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        _ContactRow(icon: Icons.phone_outlined, text: companyInfo.phone),
        const SizedBox(height: 3),
        _ContactRow(
            icon: Icons.mail_outline_rounded, text: companyInfo.email),
      ],
    );
  }

  Widget _buildToBlock(DateFormat dateFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'BILLED TO'),
        const SizedBox(height: 10),
        if (isLoadingNames) ...[
          _LoadingLine(width: 120),
          const SizedBox(height: 6),
          _LoadingLine(width: 80),
        ] else ...[
          Text(
            parentName ?? l10n.invoiceDisplayParentFallback,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          if (studentName != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 14, color: _textSecondary),
                const SizedBox(width: 5),
                Text(
                  studentName!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
        if (invoice.displayBillingPeriod != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 14, color: _accent),
              const SizedBox(width: 5),
              Text(
                invoice.displayBillingPeriod!,
                style: const TextStyle(
                  fontSize: 13,
                  color: _accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Meta row ────────────────────────────────────────────

  Widget _buildMetaRow(String invNo, DateFormat dateFormat) {
    final tiles = [
      _MetaTileData(
        label: 'Invoice #',
        value: invNo,
      ),
      _MetaTileData(
        label: l10n.invoiceDisplayIssueDateLabel,
        value: DateFormat('MMM d, y').format(invoice.issuedDate),
      ),
      _MetaTileData(
        label: l10n.dueDate,
        value: DateFormat('MMM d, y').format(invoice.dueDate),
        valueColor:
            invoice.isOverdue ? const Color(0xFFDC2626) : _textPrimary,
      ),
    ];

    if (narrow) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _divider),
        ),
        child: Column(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) ...[
                const SizedBox(height: 10),
                const Divider(height: 1, color: _divider),
                const SizedBox(height: 10),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tiles[i].label,
                    style: const TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                  Text(
                    tiles[i].value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tiles[i].valueColor ?? _textPrimary),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _divider),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) ...[
              Container(
                  width: 1, height: 36, color: _divider,
                  margin: const EdgeInsets.symmetric(horizontal: 16)),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tiles[i].label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tiles[i].value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tiles[i].valueColor ?? _textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Line items ──────────────────────────────────────────

  Widget _buildItemsSection(BuildContext context) {
    if (invoice.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _divider),
        ),
        child: Center(
          child: Text(
            l10n.noItemsOnThisInvoice,
            style: const TextStyle(fontSize: 14, color: _textSecondary),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Table(
        columnWidths: narrow
            ? const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
              }
            : const {
                0: FlexColumnWidth(4),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
              },
        border: TableBorder.all(color: _divider, width: 1),
        children: [
          // Header row
          TableRow(
            decoration: const BoxDecoration(color: _accent),
            children: narrow
                ? [
                    _TableCell(
                        l10n.description,
                        header: true),
                    _TableCell(l10n.total,
                        header: true, align: TextAlign.right),
                  ]
                : [
                    _TableCell(l10n.description, header: true),
                    _TableCell(l10n.qty,
                        header: true, align: TextAlign.center),
                    _TableCell(l10n.price,
                        header: true, align: TextAlign.right),
                    _TableCell(l10n.total,
                        header: true, align: TextAlign.right),
                  ],
          ),
          // Item rows
          for (var i = 0; i < invoice.items.length; i++)
            TableRow(
              decoration: BoxDecoration(
                color: i.isOdd ? _bg : Colors.white,
              ),
              children: narrow
                  ? [
                      _TableCell(invoice.items[i].description),
                      _TableCell(
                        money.format(invoice.items[i].total),
                        bold: true,
                        align: TextAlign.right,
                      ),
                    ]
                  : [
                      _TableCell(invoice.items[i].description),
                      _TableCell(
                        '${invoice.items[i].quantity}',
                        align: TextAlign.center,
                      ),
                      _TableCell(
                        money.format(invoice.items[i].unitPrice),
                        align: TextAlign.right,
                      ),
                      _TableCell(
                        money.format(invoice.items[i].total),
                        bold: true,
                        align: TextAlign.right,
                      ),
                    ],
            ),
        ],
      ),
    );
  }

  // ── Summary ─────────────────────────────────────────────

  Widget _buildSummary(BuildContext context) {
    final isFullyPaid = invoice.isFullyPaid;
    final amountDueColor = isFullyPaid
        ? const Color(0xFF059669)
        : invoice.isOverdue
            ? const Color(0xFFDC2626)
            : _accent;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _divider),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _SummaryLine(
              label: l10n.invoiceDisplaySubtotal,
              value: money.format(invoice.totalAmount),
            ),
            if (invoice.paidAmount > 0) ...[
              const SizedBox(height: 10),
              _SummaryLine(
                label: l10n.invoiceDisplayPaidToward,
                value: '− ${money.format(invoice.paidAmount)}',
                valueColor: const Color(0xFF059669),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: amountDueColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: amountDueColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.invoiceDisplayAmountDue,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: amountDueColor,
                    ),
                  ),
                  Text(
                    money.format(invoice.remainingBalance),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: amountDueColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Footer ──────────────────────────────────────────────

  Widget _buildFooter() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo watermark
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                'assets/Alluwal_Education_Hub_Logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.school_rounded,
                  color: _accent,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            companyInfo.name,
            style: const TextStyle(
              fontSize: 11,
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Signature line only — no name
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              l10n.signature,
              style: const TextStyle(
                  fontSize: 11,
                  color: _textSecondary,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Container(
              width: 140,
              height: 1,
              color: const Color(0xFFD1D5DB),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Small helper widgets
// ─────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: color);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1A56DB),
        letterSpacing: 1.2,
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }
}

class _LoadingLine extends StatelessWidget {
  const _LoadingLine({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(7),
      ),
    );
  }
}

class _MetaTileData {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetaTileData({
    required this.label,
    required this.value,
    this.valueColor,
  });
}

class _TableCell extends StatelessWidget {
  const _TableCell(
    this.text, {
    this.header = false,
    this.bold = false,
    this.align = TextAlign.left,
  });

  final String text;
  final bool header;
  final bool bold;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: header ? 12 : 13,
          fontWeight: header
              ? FontWeight.w800
              : (bold ? FontWeight.w700 : FontWeight.w500),
          color: header ? Colors.white : const Color(0xFF111827),
          letterSpacing: header ? 0.4 : 0,
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}
