import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/settings_service.dart';

class PaySettingsDialog extends StatefulWidget {
  const PaySettingsDialog({super.key});

  @override
  State<PaySettingsDialog> createState() => _PaySettingsDialogState();
}

class _PaySettingsDialogState extends State<PaySettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rate = await SettingsService.getGlobalTeacherHourlyRate();
    if (!mounted) return;
    setState(() {
      _controller.text = rate.toStringAsFixed(2);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final value = double.parse(_controller.text.trim());
      await SettingsService.setGlobalTeacherHourlyRate(value);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hourly rate updated to \$${value.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to save: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.attach_money, color: Colors.green),
          const SizedBox(width: 8),
          Text('Pay Settings', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Global Teacher Hourly Rate (USD)',
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xff6B7280)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixText: '\$',
                border: OutlineInputBorder(),
                hintText: '4.00',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter a rate';
                final d = double.tryParse(v.trim());
                if (d == null) return 'Enter a valid number';
                if (d <= 0) return 'Rate must be greater than 0';
                if (d > 1000) return 'Rate seems too high';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: GoogleFonts.inter()),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff0386FF), foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
              : Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

