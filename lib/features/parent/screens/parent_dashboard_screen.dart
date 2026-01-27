import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/models/invoice.dart';
import 'package:alluwalacademyadmin/core/models/payment.dart';
import 'package:alluwalacademyadmin/core/services/invoice_service.dart';
import 'package:alluwalacademyadmin/core/services/parent_service.dart';
import 'package:alluwalacademyadmin/core/services/payment_service.dart';
import 'package:alluwalacademyadmin/core/services/user_role_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/features/parent/screens/invoice_detail_screen.dart';
import 'package:alluwalacademyadmin/features/parent/screens/parent_invoices_screen.dart';
import 'package:alluwalacademyadmin/features/parent/screens/payment_history_screen.dart';
import 'package:alluwalacademyadmin/features/parent/screens/payment_screen.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/children_list_widget.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/financial_summary_card.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/invoice_card.dart';
import 'package:alluwalacademyadmin/features/parent/screens/student_detail_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ParentDashboardScreen extends StatefulWidget {
  final String? parentId;

  const ParentDashboardScreen({super.key, this.parentId});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  String? _parentId;
  Future<List<Map<String, dynamic>>>? _childrenFuture;
  Future<Map<String, double>>? _summaryFuture;
  String? _parentFirstName;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final parentId = widget.parentId ??
        UserRoleService.getCurrentUserId() ??
        FirebaseAuth.instance.currentUser?.uid;

    Map<String, dynamic>? userData;
    try {
      userData = await UserRoleService.getCurrentUserData();
    } catch (e) {
      AppLogger.error('ParentDashboard: Failed to load user data: $e');
    }

    if (!mounted) return;
    setState(() {
      _parentId = parentId;
      _parentFirstName = (userData?['first_name'] ?? '').toString().trim();
      _childrenFuture = parentId == null ? null : ParentService.getParentChildren(parentId);
      _summaryFuture = parentId == null ? null : ParentService.getFinancialSummary(parentId);
    });
  }

  Future<void> _refresh() async {
    final parentId = _parentId;
    if (parentId == null) return;
    setState(() {
      _childrenFuture = ParentService.getParentChildren(parentId);
      _summaryFuture = ParentService.getFinancialSummary(parentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final parentId = _parentId;
    if (parentId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Text(
            AppLocalizations.of(context)!.unableToLoadParentAccountPlease,
            style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _parentFirstName == null || _parentFirstName!.isEmpty
                    ? 'Parent Dashboard'
                    : 'Welcome, $_parentFirstName',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<Map<String, double>>(
                future: _summaryFuture,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  final outstanding = data?['outstanding'] ?? 0;
                  final overdue = data?['overdue'] ?? 0;
                  final paid = data?['paid'] ?? 0;
                  return FinancialSummaryCard(
                    outstanding: outstanding,
                    overdue: overdue,
                    paid: paid,
                    onPayNow: outstanding > 0
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ParentInvoicesScreen(
                                  parentId: parentId,
                                  initialStatus: InvoiceStatus.pending,
                                ),
                              ),
                            );
                          }
                        : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _quickAction(
                      icon: Icons.receipt_long_rounded,
                      title: AppLocalizations.of(context)!.invoices,
                      subtitle: AppLocalizations.of(context)!.viewAndPay,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ParentInvoicesScreen(parentId: parentId),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _quickAction(
                      icon: Icons.payments_rounded,
                      title: AppLocalizations.of(context)!.payments,
                      subtitle: AppLocalizations.of(context)!.history,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PaymentHistoryScreen(parentId: parentId),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _childrenFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    return _errorCard('Failed to load children: ${snapshot.error}');
                  }
                  final children = snapshot.data ?? const <Map<String, dynamic>>[];
                  return ChildrenListWidget(
                    children: children,
                    onChildTap: (child) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudentDetailScreen(
                            studentId: child['id'] as String,
                            studentName: child['name'] as String,
                            parentId: parentId,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              _sectionHeader(
                title: AppLocalizations.of(context)!.recentInvoices,
                actionLabel: 'See all',
                onAction: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ParentInvoicesScreen(parentId: parentId),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<Invoice>>(
                stream: InvoiceService.getParentInvoices(parentId, limit: 5),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    return _errorCard('Failed to load invoices: ${snapshot.error}');
                  }
                  final invoices = snapshot.data ?? const <Invoice>[];
                  if (invoices.isEmpty) {
                    return _emptyCard(
                      icon: Icons.receipt_long_rounded,
                      title: AppLocalizations.of(context)!.noInvoicesYet,
                      subtitle: AppLocalizations.of(context)!.whenInvoicesAreCreatedTheyWill,
                    );
                  }
                  return Column(
                    children: invoices
                        .map(
                          (inv) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InvoiceCard(
                              invoice: inv,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => InvoiceDetailScreen(invoiceId: inv.id),
                                  ),
                                );
                              },
                              onPayNow: inv.isFullyPaid || inv.status == InvoiceStatus.cancelled
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => PaymentScreen(invoiceId: inv.id),
                                        ),
                                      );
                                    },
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              _sectionHeader(
                title: AppLocalizations.of(context)!.recentPayments,
                actionLabel: 'See all',
                onAction: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PaymentHistoryScreen(parentId: parentId),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<Payment>>(
                stream: PaymentService.getPaymentHistory(parentId, limit: 5),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    return _errorCard('Failed to load payments: ${snapshot.error}');
                  }
                  final payments = snapshot.data ?? const <Payment>[];
                  if (payments.isEmpty) {
                    return _emptyCard(
                      icon: Icons.payments_rounded,
                      title: AppLocalizations.of(context)!.noPaymentsYet,
                      subtitle: AppLocalizations.of(context)!.paymentHistoryWillAppearOnceYou,
                    );
                  }
                  return _paymentsList(payments);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF1D4ED8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(
            actionLabel,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0386FF),
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentsList(List<Payment> payments) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: payments.map((p) {
          final amount = NumberFormat.simpleCurrency().format(p.amount);
          final created = p.createdAt == null ? '' : DateFormat.yMMMd().format(p.createdAt!);
          return ListTile(
            leading: _paymentStatusDot(p.status),
            title: Text(
              amount,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
            subtitle: Text(
              '${p.status.name.toUpperCase()}${created.isEmpty ? '' : ' • $created'}',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
            onTap: () async {
              final invoiceId = p.invoiceId.trim();
              if (invoiceId.isEmpty) return;
              final doc = await FirebaseFirestore.instance.collection('invoices').doc(invoiceId).get();
              if (!mounted) return;
              if (!doc.exists) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.invoiceNotFoundForThisPayment, style: GoogleFonts.inter())),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: invoiceId)),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _paymentStatusDot(PaymentStatus status) {
    Color color;
    switch (status) {
      case PaymentStatus.completed:
        color = const Color(0xFF16A34A);
        break;
      case PaymentStatus.failed:
        color = const Color(0xFFDC2626);
        break;
      case PaymentStatus.processing:
        color = const Color(0xFF2563EB);
        break;
      case PaymentStatus.pending:
        color = const Color(0xFFF59E0B);
        break;
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _emptyCard({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Icon(icon, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF7F1D1D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
