import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/tontine/config/tontine_ui.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_contribution.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_cycle.dart';
import 'package:alluwalacademyadmin/features/tontine/services/receipt_upload_service.dart';
import 'package:alluwalacademyadmin/features/tontine/services/tontine_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class SubmitPaymentScreen extends StatefulWidget {
  final Circle circle;
  final CircleCycle cycle;
  final CircleContribution? existingContribution;

  const SubmitPaymentScreen({
    super.key,
    required this.circle,
    required this.cycle,
    this.existingContribution,
  });

  @override
  State<SubmitPaymentScreen> createState() => _SubmitPaymentScreenState();
}

class _SubmitPaymentScreenState extends State<SubmitPaymentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  bool _isSubmitting = false;
  XFile? _selectedReceipt;
  late DateTime _paymentDate;

  double get _expectedAmount => widget.circle.contributionAmount;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.existingContribution?.submittedAmount?.toStringAsFixed(2) ??
          widget.circle.contributionAmount.toStringAsFixed(2),
    );
    _paymentDate = widget.existingContribution?.paymentDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final parsedAmount = double.tryParse(_amountController.text.trim());
    final amountMatches = parsedAmount == _expectedAmount;
    final hasReceipt = _selectedReceipt != null ||
        widget.existingContribution?.receiptImageUrl != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          l10n.tontineSubmitPayment,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SummaryCard(
              title: widget.circle.title,
              amount: TontineUi.formatCurrency(
                widget.circle.currency,
                widget.circle.contributionAmount,
              ),
              dueDate: widget.cycle.dueDate,
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: l10n.tontinePaymentDetails,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.tontineAmount,
                      helperText: amountMatches
                          ? l10n.tontineAmountMatchesExpected
                          : l10n.tontineAmountDoesNotMatchExpected,
                    ),
                    validator: (value) {
                      final amount = double.tryParse((value ?? '').trim());
                      if (amount == null || amount <= 0) {
                        return l10n.tontineEnterValidAmount;
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_rounded,
                        color: Color(0xFF0E72ED)),
                    title: Text(l10n.tontinePaymentDate),
                    subtitle:
                        Text(DateFormat('MMM d, yyyy').format(_paymentDate)),
                    trailing: TextButton(
                      onPressed: _pickDate,
                      child: Text(l10n.commonEdit),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: l10n.tontineReceipt,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _pickReceipt(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(l10n.tontineUseCamera),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pickReceipt(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(l10n.tontineChooseFromGallery),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_selectedReceipt != null)
                    Text(
                      '${l10n.tontineSelectedReceipt}: ${_selectedReceipt!.name}',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else if (widget.existingContribution?.receiptImageUrl != null)
                    _ReceiptPreview(
                        url: widget.existingContribution!.receiptImageUrl!)
                  else
                    Text(
                      l10n.tontineReceiptRequired,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isSubmitting || !hasReceipt ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                _isSubmitting ? l10n.commonLoading : l10n.tontineSubmitPayment,
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked == null) return;
    setState(() {
      _paymentDate = picked;
    });
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final receipt = await ReceiptUploadService.pickReceipt(source: source);
    if (receipt == null) return;
    setState(() {
      _selectedReceipt = receipt;
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedReceipt == null &&
        widget.existingContribution?.receiptImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tontineReceiptRequired)),
      );
      return;
    }

    final amount = double.parse(_amountController.text.trim());

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUser = await TontineService.getCurrentUserLookup();
      var receiptUrl = widget.existingContribution?.receiptImageUrl ?? '';
      if (_selectedReceipt != null) {
        receiptUrl = await ReceiptUploadService.uploadReceipt(
          _selectedReceipt!,
          circleId: widget.circle.id,
          cycleId: widget.cycle.id,
          userId: currentUser.userId,
        );
      }

      await TontineService.submitContribution(
        circleId: widget.circle.id,
        cycleId: widget.cycle.id,
        expectedAmount: widget.circle.contributionAmount,
        submittedAmount: amount,
        receiptImageUrl: receiptUrl,
        paymentDate: _paymentDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tontinePaymentSubmitted)),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tontineSubmissionFailed(error.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final DateTime? dueDate;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.dueDate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${l10n.tontineExpectedAmount}: $amount',
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (dueDate != null) ...[
            const SizedBox(height: 8),
            Text(
              '${l10n.tontineDueDate}: ${DateFormat('MMM d, yyyy').format(dueDate!)}',
              style: const TextStyle(color: Color(0xFFCBD5E1)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ReceiptPreview extends StatelessWidget {
  final String url;

  const _ReceiptPreview({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: kIsWeb
            ? Image.network(url, fit: BoxFit.cover)
            : Image.network(url, fit: BoxFit.cover),
      ),
    );
  }
}
