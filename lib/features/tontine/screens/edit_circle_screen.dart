import 'package:flutter/material.dart';

import 'package:alluwalacademyadmin/features/tontine/models/circle.dart';
import 'package:alluwalacademyadmin/features/tontine/services/tontine_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

const _frequencyOptions = ['weekly', 'biweekly', 'monthly', 'quarterly'];

class EditCircleScreen extends StatefulWidget {
  final Circle circle;

  const EditCircleScreen({super.key, required this.circle});

  @override
  State<EditCircleScreen> createState() => _EditCircleScreenState();
}

class _EditCircleScreenState extends State<EditCircleScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _gracePeriodController;
  late TextEditingController _paymentInstructionsController;

  late CircleMissedPaymentAction _missedPaymentAction;
  late DateTime _startDate;
  late String _frequency;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.circle.title);
    _amountController = TextEditingController(
        text: widget.circle.contributionAmount.toString());
    _gracePeriodController = TextEditingController(
        text: widget.circle.rules.gracePeriodDays.toString());
    _paymentInstructionsController =
        TextEditingController(text: widget.circle.paymentInstructions);

    _missedPaymentAction = widget.circle.rules.missedPaymentAction;
    _startDate = widget.circle.startDate ?? DateTime.now();
    _frequency = _frequencyOptions.contains(widget.circle.frequency)
        ? widget.circle.frequency
        : 'monthly';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _gracePeriodController.dispose();
    _paymentInstructionsController.dispose();
    super.dispose();
  }

  String _frequencyLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'weekly':
        return l10n.tontineFrequencyWeekly;
      case 'biweekly':
        return l10n.tontineFrequencyBiweekly;
      case 'monthly':
        return l10n.tontineFrequencyMonthly;
      case 'quarterly':
        return l10n.tontineFrequencyQuarterly;
      default:
        return value;
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await TontineService.updateCircle(
        widget.circle.id,
        title: _titleController.text,
        contributionAmount: double.parse(_amountController.text),
        currency: widget.circle.currency,
        frequency: _frequency,
        startDate: _startDate,
        rules: CircleRules(
          gracePeriodDays: int.parse(_gracePeriodController.text),
          missedPaymentAction: _missedPaymentAction,
        ),
        paymentInstructions: _paymentInstructionsController.text,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          l10n.commonEdit,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                l10n.commonSave,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: _fieldDecoration(l10n.tontineCircleName),
              validator: (v) => v == null || v.trim().isEmpty
                  ? l10n.tontineCircleNameRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _fieldDecoration(l10n.tontineContributionAmount),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return l10n.tontineEnterValidAmount;
                }
                final val = double.tryParse(v);
                if (val == null || val <= 0) {
                  return l10n.tontineEnterValidAmount;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Frequency selector
            DropdownButtonFormField<String>(
              value: _frequency,
              decoration: _fieldDecoration(l10n.tontineFrequency),
              items: _frequencyOptions
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(_frequencyLabel(l10n, f)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _frequency = v);
              },
            ),
            const SizedBox(height: 16),

            // Start date picker
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading:
                    const Icon(Icons.event_rounded, color: Color(0xFF0F766E)),
                title: Text(l10n.tontineStartDate),
                subtitle: Text(
                  MaterialLocalizations.of(context)
                      .formatMediumDate(_startDate),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                trailing: TextButton(
                  onPressed: _pickStartDate,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                  ),
                  child: Text(l10n.commonEdit),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _gracePeriodController,
              keyboardType: TextInputType.number,
              decoration: _fieldDecoration(l10n.tontineGracePeriodDays),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return l10n.tontineInvalidGracePeriod;
                }
                final val = int.tryParse(v);
                if (val == null || val < 0) {
                  return l10n.tontineInvalidGracePeriod;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CircleMissedPaymentAction>(
              value: _missedPaymentAction,
              decoration: _fieldDecoration(l10n.tontineMissedPaymentAction),
              items: [
                DropdownMenuItem(
                  value: CircleMissedPaymentAction.moveToBack,
                  child: Text(l10n.tontineMissedMoveToBack),
                ),
                DropdownMenuItem(
                  value: CircleMissedPaymentAction.suspend,
                  child: Text(l10n.tontineMissedSuspend),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _missedPaymentAction = v);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _paymentInstructionsController,
              maxLines: 4,
              decoration: _fieldDecoration(l10n.tontinePaymentInstructions),
              validator: (v) => v == null || v.trim().isEmpty
                  ? l10n.tontinePaymentInstructionsRequired
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
