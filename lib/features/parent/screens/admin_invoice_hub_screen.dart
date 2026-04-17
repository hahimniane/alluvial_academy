import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/features/parent/screens/admin_create_invoice_screen.dart';
import 'package:alluwalacademyadmin/features/parent/screens/admin_invoices_screen.dart';

/// Unified invoice hub: Create + All Invoices in a single tabbed view.
class AdminInvoiceHubScreen extends StatefulWidget {
  /// Pass 1 to open directly on the "All Invoices" tab.
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
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
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
            tabs: const [
              Tab(
                icon: Icon(Icons.add_circle_outline_rounded, size: 20),
                text: 'Create Invoice',
              ),
              Tab(
                icon: Icon(Icons.folder_special_outlined, size: 20),
                text: 'All Invoices',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              AdminCreateInvoiceScreen(),
              AdminInvoicesScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
