import 'package:flutter/material.dart';

import '../../../core/constants/penalty_reasons.dart';
import '../../../l10n/app_localizations.dart';
import 'penalty_reason_fields.dart';

/// What the "add payment line" dialog collected. For a bonus [reasonText] is
/// the typed reason; for a penalty it is built from [penaltyReason] and
/// [penaltyNote].
class PaymentLineInput {
  final String type;
  final double amount;
  final String reasonText;
  final String? penaltyReason;
  final String? penaltyNote;

  const PaymentLineInput({
    required this.type,
    required this.amount,
    required this.reasonText,
    this.penaltyReason,
    this.penaltyNote,
  });
}

Future<PaymentLineInput?> showPaymentLineDialog(BuildContext context) {
  return showDialog<PaymentLineInput>(
    context: context,
    builder: (_) => const _PaymentLineDialog(),
  );
}

class _PaymentLineDialog extends StatefulWidget {
  const _PaymentLineDialog();

  @override
  State<_PaymentLineDialog> createState() => _PaymentLineDialogState();
}

class _PaymentLineDialogState extends State<_PaymentLineDialog> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _type = 'penalty';
  String? _code;
  PenaltyReasonError? _reasonError;
  bool _amountInvalid = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    final isPenalty = _type == 'penalty';
    final reasonError = isPenalty ? PenaltyReasons.validate(_code, _noteCtrl.text) : null;
    if (amount <= 0 || reasonError != null) {
      setState(() {
        _amountInvalid = amount <= 0;
        _reasonError = reasonError;
      });
      return;
    }
    if (isPenalty) {
      final note = _noteCtrl.text.trim();
      Navigator.pop(
        context,
        PaymentLineInput(
          type: _type,
          amount: amount,
          reasonText: PenaltyReasons.composeReasonText(_code, note),
          penaltyReason: _code,
          penaltyNote: note,
        ),
      );
      return;
    }
    final typed = _reasonCtrl.text.trim();
    Navigator.pop(
      context,
      PaymentLineInput(
        type: _type,
        amount: amount,
        reasonText: typed.isEmpty ? '—' : typed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.auditAddPaymentLine),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration:
                  InputDecoration(labelText: l10n.auditPaymentLineTypeLabel),
              items: [
                DropdownMenuItem(
                    value: 'penalty', child: Text(l10n.auditPaymentLinePenalty)),
                DropdownMenuItem(
                    value: 'bonus', child: Text(l10n.auditPaymentLineBonus)),
              ],
              onChanged: (v) => setState(() {
                _type = v ?? 'penalty';
                _reasonError = null;
              }),
            ),
            TextField(
              key: const ValueKey('payment_line_amount'),
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.auditAmountLabel,
                errorText: _amountInvalid ? l10n.pleaseEnterAValidNumber : null,
              ),
            ),
            if (_type == 'penalty')
              PenaltyReasonFields(
                code: _code,
                noteController: _noteCtrl,
                error: _reasonError,
                onCodeChanged: (v) => setState(() {
                  _code = v;
                  _reasonError = null;
                }),
              )
            else
              TextField(
                controller: _reasonCtrl,
                decoration: InputDecoration(labelText: l10n.auditReasonLabel),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          key: const ValueKey('payment_line_ok'),
          onPressed: _submit,
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}
