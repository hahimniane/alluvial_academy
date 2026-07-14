import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/features/parent/screens/admin_cutoff_management_screen.dart';
import 'package:alluwalacademyadmin/features/parent/screens/admin_create_invoice_screen.dart';
import 'package:alluwalacademyadmin/features/parent/screens/admin_finance_overview_screen.dart';
import 'package:alluwalacademyadmin/features/parent/screens/admin_invoices_screen.dart';
import 'package:alluwalacademyadmin/features/parent/screens/admin_subscriptions_screen.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Unified finance hub: overview + invoice creation + all invoices.
class AdminInvoiceHubScreen extends StatefulWidget {
  /// Pass 3 to open directly on the "All Invoices" tab.
  final int initialTab;

  const AdminInvoiceHubScreen({super.key, this.initialTab = 0});

  @override
  State<AdminInvoiceHubScreen> createState() => _AdminInvoiceHubScreenState();
}

class _AdminInvoiceHubScreenState extends State<AdminInvoiceHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Container(
          color: cs.surface,
          child: TabBar(
            controller: _tabController,
            labelStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
            indicatorColor: cs.primary,
            indicatorWeight: 2.5,
            tabs: [
              Tab(
                icon: const Icon(Icons.assessment, size: 20),
                text: l10n.financeOverviewTab,
              ),
              Tab(
                icon: const Icon(Icons.lock_clock_rounded, size: 20),
                text: l10n.financeCutoffsTab,
              ),
              Tab(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                text: l10n.sidebarCreateInvoice,
              ),
              Tab(
                icon: const Icon(Icons.folder_special_outlined, size: 20),
                text: l10n.sidebarAllInvoices,
              ),
              Tab(
                icon: const Icon(Icons.autorenew_rounded, size: 20),
                text: l10n.financeSubscriptionsTab,
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              AdminFinanceOverviewScreen(
                onOpenCreateInvoice: () => _tabController.animateTo(2),
                onOpenAllInvoices: () => _tabController.animateTo(3),
              ),
              const AdminCutoffManagementScreen(),
              const AdminCreateInvoiceScreen(),
              const AdminInvoicesScreen(),
              const AdminSubscriptionsScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
