import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/parent/models/finance_subscription.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Registry of recurring / subscription expenses (Zoom, hosting, domains,
/// software, marketing tools). Lives as a tab inside the finance hub so
/// leadership can see committed recurring spend at a glance.
class AdminSubscriptionsScreen extends StatelessWidget {
  const AdminSubscriptionsScreen({super.key});

  static const _collection = 'finance_subscriptions';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, null),
        icon: const Icon(Icons.add),
        label: Text(l10n.financeSubscriptionAdd),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(_collection)
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n.financeSubscriptionLoadError));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final subs = snapshot.data!.docs
              .map(FinanceSubscription.fromDoc)
              .toList();
          final activeMonthly = subs
              .where((s) => s.status == SubscriptionStatus.active)
              .fold<double>(0, (total, s) => total + s.monthlyEquivalent);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryBar(monthlyTotal: activeMonthly, count: subs.length),
              const SizedBox(height: 16),
              if (subs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      l10n.financeSubscriptionEmpty,
                      style: GoogleFonts.inter(color: cs.onSurfaceVariant),
                    ),
                  ),
                )
              else
                ...subs.map(
                  (s) => _SubscriptionCard(
                    subscription: s,
                    onEdit: () => _openEditor(context, s),
                    onDelete: () => _confirmDelete(context, s),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditor(
      BuildContext context, FinanceSubscription? existing) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => _SubscriptionEditorDialog(existing: existing),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, FinanceSubscription sub) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.financeSubscriptionDeleteTitle),
        content: Text(l10n.financeSubscriptionDeleteMessage(sub.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(sub.id)
          .delete();
    }
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.monthlyTotal, required this.count});

  final double monthlyTotal;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.autorenew_rounded, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.financeSubscriptionMonthlyTotal,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${money.format(monthlyTotal)} / mo',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Text(
            l10n.financeSubscriptionActiveCount(count),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.subscription,
    required this.onEdit,
    required this.onDelete,
  });

  final FinanceSubscription subscription;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFmt = DateFormat('MMM d, yyyy');
    final s = subscription;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          s.name.isEmpty ? l10n.financeSubscriptionUnnamed : s.name,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${s.vendor}  ·  ${money.format(s.amount)} / ${_frequencyLabel(l10n, s.frequency)}',
              style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            Text(
              '${money.format(s.monthlyEquivalent)} / mo'
              '${s.nextPaymentDate != null ? '  ·  ${l10n.financeSubscriptionNextDue}: ${dateFmt.format(s.nextPaymentDate!)}' : ''}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: s.isOverdue ? cs.error : cs.onSurfaceVariant,
                fontWeight: s.isOverdue ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusChip(status: s.status),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
              tooltip: l10n.commonEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
              tooltip: l10n.commonDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (MaterialColor color, String label) = switch (status) {
      SubscriptionStatus.active => (Colors.green, l10n.financeSubscriptionStatusActive),
      SubscriptionStatus.paused => (Colors.orange, l10n.financeSubscriptionStatusPaused),
      SubscriptionStatus.cancelled => (Colors.grey, l10n.financeSubscriptionStatusCancelled),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.shade800,
        ),
      ),
    );
  }
}

String _frequencyLabel(AppLocalizations l10n, SubscriptionFrequency f) =>
    switch (f) {
      SubscriptionFrequency.weekly => l10n.financeSubscriptionFreqWeekly,
      SubscriptionFrequency.monthly => l10n.financeSubscriptionFreqMonthly,
      SubscriptionFrequency.quarterly => l10n.financeSubscriptionFreqQuarterly,
      SubscriptionFrequency.yearly => l10n.financeSubscriptionFreqYearly,
    };

class _SubscriptionEditorDialog extends StatefulWidget {
  const _SubscriptionEditorDialog({required this.existing});

  final FinanceSubscription? existing;

  @override
  State<_SubscriptionEditorDialog> createState() =>
      _SubscriptionEditorDialogState();
}

class _SubscriptionEditorDialogState extends State<_SubscriptionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _vendor;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  late SubscriptionFrequency _frequency;
  late SubscriptionStatus _status;
  late String _category;
  DateTime? _nextDate;
  bool _saving = false;

  // Reuses the manual-expense category keys so subscription spend groups with
  // the rest of the finance overview.
  static const _categories = <String>[
    'subscription',
    'website',
    'software',
    'marketing_cost',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _vendor = TextEditingController(text: e?.vendor ?? '');
    _amount = TextEditingController(
        text: e != null && e.amount > 0 ? e.amount.toStringAsFixed(2) : '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _frequency = e?.frequency ?? SubscriptionFrequency.monthly;
    _status = e?.status ?? SubscriptionStatus.active;
    _category = _categories.contains(e?.category) ? e!.category : 'subscription';
    _nextDate = e?.nextPaymentDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _vendor.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final sub = FinanceSubscription(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      vendor: _vendor.text.trim(),
      category: _category,
      amount: double.tryParse(_amount.text.trim()) ?? 0,
      frequency: _frequency,
      nextPaymentDate: _nextDate,
      status: _status,
      notes: _notes.text.trim(),
    );
    final col = FirebaseFirestore.instance.collection('finance_subscriptions');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      if (widget.existing == null) {
        await col.add({
          ...sub.toMap(),
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
          if (uid != null) 'created_by': uid,
        });
      } else {
        await col.doc(sub.id).update({
          ...sub.toMap(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.financeSubscriptionSaveError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.existing == null
          ? l10n.financeSubscriptionAdd
          : l10n.financeSubscriptionEdit),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                      labelText: l10n.financeSubscriptionName),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.financeSubscriptionNameRequired
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vendor,
                  decoration: InputDecoration(
                      labelText: l10n.financeSubscriptionVendor),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(labelText: l10n.financeSubscriptionAmount),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    return (n == null || n <= 0)
                        ? l10n.financeSubscriptionAmountInvalid
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SubscriptionFrequency>(
                  initialValue: _frequency,
                  decoration: InputDecoration(
                      labelText: l10n.financeSubscriptionFrequency),
                  items: SubscriptionFrequency.values
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(_frequencyLabel(l10n, f)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(
                      () => _frequency = v ?? SubscriptionFrequency.monthly),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: InputDecoration(
                      labelText: l10n.financeSubscriptionCategory),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(_categoryLabel(l10n, c)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v ?? 'subscription'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SubscriptionStatus>(
                  initialValue: _status,
                  decoration: InputDecoration(
                      labelText: l10n.financeSubscriptionStatus),
                  items: SubscriptionStatus.values
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(_statusLabel(l10n, s)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _status = v ?? SubscriptionStatus.active),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.financeSubscriptionNextDue),
                  subtitle: Text(_nextDate == null
                      ? l10n.financeSubscriptionNotSet
                      : DateFormat('MMM d, yyyy').format(_nextDate!)),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _nextDate ?? now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 5),
                    );
                    if (picked != null) setState(() => _nextDate = picked);
                  },
                ),
                TextFormField(
                  controller: _notes,
                  decoration:
                      InputDecoration(labelText: l10n.financeSubscriptionNotes),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.commonSave),
        ),
      ],
    );
  }
}

String _categoryLabel(AppLocalizations l10n, String key) => switch (key) {
      'subscription' => l10n.financeSubscriptionCategorySubscription,
      'website' => l10n.financeSubscriptionCategoryWebsite,
      'software' => l10n.financeSubscriptionCategorySoftware,
      'marketing_cost' => l10n.financeExpenseCategoryMarketingCost,
      _ => l10n.adminInvoicePaymentMethodOther,
    };

String _statusLabel(AppLocalizations l10n, SubscriptionStatus s) => switch (s) {
      SubscriptionStatus.active => l10n.financeSubscriptionStatusActive,
      SubscriptionStatus.paused => l10n.financeSubscriptionStatusPaused,
      SubscriptionStatus.cancelled => l10n.financeSubscriptionStatusCancelled,
    };
