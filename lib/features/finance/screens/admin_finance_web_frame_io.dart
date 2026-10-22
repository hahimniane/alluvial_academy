import 'package:flutter/material.dart';

/// Native builds never reach this widget — the dashboard shows the read-only
/// [AdminFinanceSummaryScreen] off the web. It exists only to satisfy the
/// conditional import.
class AdminFinanceWebFrame extends StatelessWidget {
  const AdminFinanceWebFrame({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
