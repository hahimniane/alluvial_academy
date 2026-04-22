import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

import '../../../../core/services/public_site_cms_service.dart';
import 'admin_action_cards.dart';

/// Admin home: quick access to public pricing + team CMS.
class PublicWebsiteToolsCard extends StatelessWidget {
  final void Function(int screenIndex)? onNavigate;

  const PublicWebsiteToolsCard({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AdminActionCardShell(
      title: l.publicSiteCmsDashboardCardTitle,
      icon: Icons.groups_outlined,
      accentColor: const Color(0xff059669),
      onViewAll: () => onNavigate?.call(28),
      viewAllLabel: l.publicSiteCmsOpenEditor,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.publicSiteCmsDashboardCardBody,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xff6B7280),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<int>(
            future: PublicSiteCmsService.countTeamMembers(),
            builder: (context, snap) {
              final n = snap.data;
              if (n == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return Text(
                '${l.publicSiteCmsTabTeam}: $n',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
