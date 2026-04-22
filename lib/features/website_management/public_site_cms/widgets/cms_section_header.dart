import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/theme/public_site_cms_tokens.dart';

String publicSiteCmsSectionTitle(AppLocalizations l, int index) {
  switch (index) {
    case 0:
      return l.publicSiteCmsTabPricing;
    case 1:
      return l.publicSiteCmsTabTeam;
    case 2:
      return l.publicSiteCmsTabSocial;
    case 3:
      return l.publicSiteCmsTabLanding;
    default:
      return l.publicSiteCmsTitle;
  }
}

String publicSiteCmsSectionSubtitle(AppLocalizations l, int index) {
  switch (index) {
    case 0:
      return l.publicSiteCmsPricingHelp;
    case 1:
      return l.publicSiteCmsTeamImportBundledHint;
    case 2:
      return l.publicSiteCmsSocialIntro;
    case 3:
      return l.publicSiteCmsLandingIntro;
    default:
      return '';
  }
}

class CmsSectionHeader extends StatelessWidget {
  const CmsSectionHeader({super.key, required this.index, this.showProductLine = true});

  final int index;
  final bool showProductLine;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: AnimatedSwitcher(
        duration: PublicSiteCmsTheme.sectionSwitch,
        child: Column(
          key: ValueKey<int>(index),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showProductLine) ...[
              Text(
                l.publicSiteCmsTitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: PublicSiteCmsTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              publicSiteCmsSectionTitle(l, index),
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.15,
                color: PublicSiteCmsTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              publicSiteCmsSectionSubtitle(l, index),
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: PublicSiteCmsTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
