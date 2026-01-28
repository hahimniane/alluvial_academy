import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:alluwalacademyadmin/core/models/invoice.dart';
import 'package:alluwalacademyadmin/core/models/payment.dart';
import 'package:alluwalacademyadmin/core/services/invoice_service.dart';
import 'package:alluwalacademyadmin/core/services/payment_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class PaymentScreen extends StatefulWidget {
  final String invoiceId;

  const PaymentScreen({super.key, required this.invoiceId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isCreatingSession = false;
  bool _isCheckingStatus = false;
  String? _checkoutUrl;
  String? _paymentId;
  Payment? _payment;
  String? _error;

  Future<void> _createPaymentSession() async {
    setState(() {
      _isCreatingSession = true;
      _error = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createPaymentSession');
      final result = await callable.call({'invoiceId': widget.invoiceId});
      final data = (result.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

      final success = data['success'] == true;
      if (!success) {
        throw Exception(data['error'] ?? 'Failed to create payment session');
      }

      final checkoutUrl = (data['checkoutUrl'] ?? data['checkout_url'])?.toString();
      final paymentId = (data['paymentId'] ?? data['payment_id'])?.toString();
      if (checkoutUrl == null || checkoutUrl.isEmpty || paymentId == null || paymentId.isEmpty) {
        throw Exception('Invalid payment session response');
      }

      setState(() {
        _checkoutUrl = checkoutUrl;
        _paymentId = paymentId;
      });

      final uri = Uri.parse(checkoutUrl);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw Exception('Could not open checkout URL');
      }
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('PaymentScreen: createPaymentSession failed: ${e.code} ${e.message}');
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      AppLogger.error('PaymentScreen: create session error: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isCreatingSession = false);
    }
  }

  Future<void> _checkPaymentStatus() async {
    final paymentId = _paymentId;
    if (paymentId == null || paymentId.isEmpty) return;

    setState(() {
      _isCheckingStatus = true;
      _error = null;
    });

    try {
      final payment = await PaymentService.getPaymentStatus(paymentId);
      if (!mounted) return;
      setState(() => _payment = payment);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
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
        title: Text(AppLocalizations.of(context)!.payInvoice, style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<Invoice>(
        future: InvoiceService.getInvoice(widget.invoiceId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _message('Failed to load invoice: ${snapshot.error}');
          }
          final invoice = snapshot.data;
          if (invoice == null) {
            return _message('Invoice not found');
          }

          final money = NumberFormat.simpleCurrency(name: invoice.currency);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : invoice.id,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      _kv('Total', money.format(invoice.totalAmount)),
                      const SizedBox(height: 6),
                      _kv('Paid', money.format(invoice.paidAmount)),
                      const SizedBox(height: 6),
                      _kv('Remaining', money.format(invoice.remainingBalance), strong: true),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_error != null) _errorCard(_error!),
                if (_payment != null) ...[
                  const SizedBox(height: 12),
                  _statusCard(_payment!, currency: invoice.currency),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: invoice.isFullyPaid || invoice.status == InvoiceStatus.cancelled || _isCreatingSession
                        ? null
                        : _createPaymentSession,
                    icon: _isCreatingSession
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.lock_rounded, size: 18),
                    label: Text(
                      invoice.isFullyPaid ? 'Already Paid' : 'Continue to Payoneer',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0386FF),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (_checkoutUrl != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final url = _checkoutUrl;
                        if (url == null) return;
                        final uri = Uri.parse(url);
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(AppLocalizations.of(context)!.openCheckoutLinkAgain, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF111827),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _paymentId == null || _isCheckingStatus ? null : _checkPaymentStatus,
                    icon: _isCheckingStatus
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      AppLocalizations.of(context)!.checkPaymentStatus,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF111827),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context)!.tipIfYouJustCompletedPayment,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v, {bool strong = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280), fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          v,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF111827),
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _message(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: const Color(0xFF6B7280), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _errorCard(String message) {
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
            child: Text(
              message,
              style: GoogleFonts.inter(color: const Color(0xFF7F1D1D), fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(Payment payment, {required String currency}) {
    final money = NumberFormat.simpleCurrency(name: currency);
    final createdAt = payment.createdAt == null ? null : DateFormat.yMMMd().add_jm().format(payment.createdAt!);
    final completedAt =
        payment.completedAt == null ? null : DateFormat.yMMMd().add_jm().format(payment.completedAt!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusDot(payment.status),
              const SizedBox(width: 8),
              Text(
                'Payment ${payment.status.name.toUpperCase()}',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _kv('Amount', money.format(payment.amount), strong: true),
          if (createdAt != null) ...[
            const SizedBox(height: 6),
            _kv('Created', createdAt),
          ],
          if (completedAt != null) ...[
            const SizedBox(height: 6),
            _kv('Completed', completedAt),
          ],
        ],
      ),
    );
  }

  Widget _statusDot(PaymentStatus status) {
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
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

