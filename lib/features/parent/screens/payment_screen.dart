import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/parent/models/invoice.dart';
import 'package:alluwalacademyadmin/features/parent/models/payment.dart';
import 'package:alluwalacademyadmin/features/parent/services/invoice_service.dart';
import 'package:alluwalacademyadmin/features/parent/services/payment_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class PaymentScreen extends StatefulWidget {
  final String invoiceId;

  const PaymentScreen({super.key, required this.invoiceId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  String? _paymentId;
  Payment? _payment;
  String? _error;

  // After payment attempt, poll Firestore every 2 s for up to 30 s until
  // the payment reaches a terminal state (completed / failed).
  Timer? _pollTimer;
  int _pollCount = 0;
  static const _maxPolls = 15; // 15 × 2 s = 30 s max

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollCount = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      _pollCount++;
      await _refreshPaymentStatus(silent: true);

      final done = _payment?.status == PaymentStatus.completed ||
          _payment?.status == PaymentStatus.failed;
      if (done || _pollCount >= _maxPolls) {
        _pollTimer?.cancel();
      }
    });
  }

  Future<void> _payWithStripe() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('createPaymentIntent');
      final result =
          await callable.call({'invoiceId': widget.invoiceId});
      final data =
          (result.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to create payment');
      }

      final clientSecret = (data['paymentIntent'] ?? '').toString();
      final ephemeralKey = (data['ephemeralKey'] ?? '').toString();
      final customerId = (data['customer'] ?? '').toString();
      final paymentId = (data['paymentId'] ?? '').toString();

      if (clientSecret.isEmpty || ephemeralKey.isEmpty || customerId.isEmpty) {
        throw Exception('Invalid payment response from server');
      }

      setState(() => _paymentId = paymentId);

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          customerEphemeralKeySecret: ephemeralKey,
          customerId: customerId,
          merchantDisplayName: 'Alluvial Academy',
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // Optimistic update while webhook propagates
      if (!mounted) return;
      setState(() {
        _payment = Payment(
          id: paymentId,
          invoiceId: widget.invoiceId,
          parentId: '',
          amount: 0,
          status: PaymentStatus.completed,
          paymentMethod: 'stripe',
          completedAt: DateTime.now(),
        );
      });

      // Start polling — the StreamBuilder on the invoice will also update
      // automatically once the webhook writes to Firestore.
      _startPolling();
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        AppLogger.error(
            'PaymentScreen: Stripe error: ${e.error.localizedMessage}');
        if (mounted) {
          setState(() => _error = e.error.localizedMessage ?? 'Payment failed');
        }
      }
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error(
          'PaymentScreen: createPaymentIntent failed: ${e.code} ${e.message}');
      if (mounted) setState(() => _error = e.message ?? e.code);
    } catch (e) {
      AppLogger.error('PaymentScreen: payment error: $e');
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _refreshPaymentStatus({bool silent = false}) async {
    final paymentId = _paymentId;
    if (paymentId == null || paymentId.isEmpty) return;
    try {
      final payment = await PaymentService.getPaymentStatus(paymentId);
      if (mounted) setState(() => _payment = payment);
    } catch (e) {
      if (!silent && mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: Text(
          l10n.payInvoice,
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
      ),
      // StreamBuilder keeps the invoice card live — updates the moment
      // the Stripe webhook writes paid_amount / status to Firestore.
      body: StreamBuilder<Invoice?>(
        stream: InvoiceService.watchInvoice(widget.invoiceId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _centreMessage(
                'Failed to load invoice: ${snapshot.error}');
          }
          final invoice = snapshot.data;
          if (invoice == null) {
            return _centreMessage('Invoice not found');
          }

          final money = NumberFormat.simpleCurrency(name: invoice.currency);
          final isPaid = invoice.isFullyPaid ||
              (_payment?.status == PaymentStatus.completed);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Invoice summary ──────────────────────────
                _InvoiceSummaryCard(invoice: invoice, money: money),

                const SizedBox(height: 14),

                // ── Error ────────────────────────────────────
                if (_error != null) ...[
                  _ErrorCard(message: _error!),
                  const SizedBox(height: 14),
                ],

                // ── Payment status card ───────────────────────
                if (_payment != null) ...[
                  _PaymentStatusCard(
                      payment: _payment!, currency: invoice.currency),
                  const SizedBox(height: 14),
                ],

                // ── Success banner (once invoice marked paid) ──
                if (isPaid && _payment == null) ...[
                  _SuccessBanner(),
                  const SizedBox(height: 14),
                ],

                // ── Pay button ───────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isPaid ||
                            invoice.status == InvoiceStatus.cancelled ||
                            _isProcessing
                        ? null
                        : _payWithStripe,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            isPaid
                                ? Icons.check_circle_rounded
                                : Icons.credit_card_rounded,
                            size: 20,
                          ),
                    label: Text(
                      isPaid
                          ? l10n.invoiceAlreadyPaid
                          : l10n.continueToSecureCheckout,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPaid
                          ? const Color(0xFF059669)
                          : const Color(0xFF0386FF),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

                // ── Manual refresh (only before terminal state) ──
                if (_paymentId != null &&
                    _payment?.status != PaymentStatus.completed &&
                    _payment?.status != PaymentStatus.failed) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _refreshPaymentStatus(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        l10n.checkPaymentStatus,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side:
                            const BorderSide(color: Color(0xFFE5E7EB)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _centreMessage(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              color: const Color(0xFF6B7280), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────

class _InvoiceSummaryCard extends StatelessWidget {
  const _InvoiceSummaryCard({required this.invoice, required this.money});
  final Invoice invoice;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final isPaid = invoice.isFullyPaid;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPaid
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  invoice.invoiceNumber.isNotEmpty
                      ? invoice.invoiceNumber
                      : invoice.id,
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              _StatusBadge(invoice: invoice),
            ],
          ),
          const SizedBox(height: 16),
          _row('Total', money.format(invoice.totalAmount)),
          const SizedBox(height: 8),
          _row(
            'Paid',
            money.format(invoice.paidAmount),
            valueColor: invoice.paidAmount > 0
                ? const Color(0xFF059669)
                : null,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
          _row(
            'Remaining',
            money.format(invoice.remainingBalance),
            strong: true,
            valueColor: invoice.remainingBalance == 0
                ? const Color(0xFF059669)
                : const Color(0xFF111827),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {bool strong = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            color: valueColor ?? const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    if (invoice.isFullyPaid) {
      color = const Color(0xFF059669);
      label = 'PAID';
    } else if (invoice.isOverdue) {
      color = const Color(0xFFDC2626);
      label = 'OVERDUE';
    } else {
      color = const Color(0xFFD97706);
      label = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.5),
      ),
    );
  }
}

class _PaymentStatusCard extends StatelessWidget {
  const _PaymentStatusCard(
      {required this.payment, required this.currency});
  final Payment payment;
  final String currency;

  Color get _dotColor {
    switch (payment.status) {
      case PaymentStatus.completed:
        return const Color(0xFF059669);
      case PaymentStatus.failed:
        return const Color(0xFFDC2626);
      case PaymentStatus.processing:
        return const Color(0xFF2563EB);
      case PaymentStatus.pending:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.simpleCurrency(name: currency);
    final isCompleted = payment.status == PaymentStatus.completed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFFF0FDF4)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: _dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                'Payment ${payment.status.name.toUpperCase()}',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _dotColor),
              ),
            ],
          ),
          if (payment.amount > 0) ...[
            const SizedBox(height: 10),
            _kv('Amount', money.format(payment.amount), strong: true),
          ],
          if (payment.createdAt != null) ...[
            const SizedBox(height: 6),
            _kv('Created',
                DateFormat.yMMMd().add_jm().format(payment.createdAt!)),
          ],
          if (payment.completedAt != null) ...[
            const SizedBox(height: 6),
            _kv('Completed',
                DateFormat.yMMMd().add_jm().format(payment.completedAt!)),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool strong = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k,
            style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF6B7280),
                fontWeight: FontWeight.w600)),
        Text(v,
            style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF111827),
                fontWeight:
                    strong ? FontWeight.w900 : FontWeight.w700)),
      ],
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF059669), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Payment received — invoice is now fully paid.',
              style: GoogleFonts.inter(
                  color: const Color(0xFF14532D),
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: GoogleFonts.inter(
                    color: const Color(0xFF7F1D1D),
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
