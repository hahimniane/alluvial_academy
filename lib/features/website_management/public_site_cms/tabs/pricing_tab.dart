import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:alluwalacademyadmin/core/constants/pricing_plan_ids.dart';
import 'package:alluwalacademyadmin/core/services/public_site_cms_service.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/theme/public_site_cms_tokens.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/widgets/pricing_plan_expandable_card.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class PublicSitePricingTab extends StatelessWidget {
  const PublicSitePricingTab({
    super.key,
    required this.loading,
    required this.errorText,
    required this.saving,
    required this.bulletsCtrls,
    required this.v2IslamicBase,
    required this.v2IslamicDiscount,
    required this.v2IslamicThreshold,
    required this.v2TutoringBase,
    required this.v2TutoringDiscount,
    required this.v2TutoringThreshold,
    required this.v2GroupHourly,
    required this.onRetryLoad,
    required this.onSaveAll,
    required this.onSaveThisTrack,
  });

  final bool loading;
  final String? errorText;
  final bool saving;
  final Map<String, TextEditingController> bulletsCtrls;
  final Map<String, TextEditingController> v2IslamicBase;
  final Map<String, TextEditingController> v2IslamicDiscount;
  final Map<String, TextEditingController> v2IslamicThreshold;
  final Map<String, TextEditingController> v2TutoringBase;
  final Map<String, TextEditingController> v2TutoringDiscount;
  final Map<String, TextEditingController> v2TutoringThreshold;
  final Map<String, TextEditingController> v2GroupHourly;
  final VoidCallback onRetryLoad;
  final VoidCallback onSaveAll;
  final void Function(String planId) onSaveThisTrack;

  String _planTitle(AppLocalizations l, String id) {
    switch (id) {
      case PricingPlanIds.islamic:
        return l.pricingTrackIslamicTitle;
      case PricingPlanIds.tutoring:
        return l.pricingTrackTutoringTitle;
      case PricingPlanIds.group:
        return l.pricingTrackGroupTitle;
      default:
        return id;
    }
  }

  String _planSubtitle(AppLocalizations l, String id) {
    switch (id) {
      case PricingPlanIds.islamic:
        return l.pricingTrackIslamicDesc;
      case PricingPlanIds.tutoring:
        return l.pricingTrackTutoringDesc;
      case PricingPlanIds.group:
        return l.pricingTrackGroupDesc;
      default:
        return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Shimmer.fromColors(
                baseColor: PublicSiteCmsTheme.border,
                highlightColor: PublicSiteCmsTheme.bg,
                child: Material(
                  color: PublicSiteCmsTheme.surface,
                  borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusLg),
                  child: const SizedBox(height: 120, width: double.infinity),
                ),
              ),
            ),
        ],
      );
    }
    if (errorText != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorText!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: PublicSiteCmsTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: PublicSiteCmsTheme.accentNavy,
                ),
                onPressed: onRetryLoad,
                child: Text(l.commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            children: [
              for (final id in PublicSiteCmsService.primaryPricingTrackIds())
                PricingPlanExpandableCard(
                  contextForTheme: context,
                  planId: id,
                  title: _planTitle(l, id),
                  subtitle: _planSubtitle(l, id),
                  bulletsCtrl: bulletsCtrls[id],
                  v2IslamicBase: v2IslamicBase[id],
                  v2IslamicDiscount: v2IslamicDiscount[id],
                  v2IslamicThreshold: v2IslamicThreshold[id],
                  v2TutoringBase: v2TutoringBase[id],
                  v2TutoringDiscount: v2TutoringDiscount[id],
                  v2TutoringThreshold: v2TutoringThreshold[id],
                  v2GroupHourly: v2GroupHourly[id],
                  onSaveThisTrack: () => onSaveThisTrack(id),
                  saving: saving,
                ),
            ],
          ),
        ),
        Material(
          color: PublicSiteCmsTheme.surface,
          elevation: 6,
          shadowColor: Colors.black26,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Divider(height: 1, thickness: 1, color: PublicSiteCmsTheme.borderStrong),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: PublicSiteCmsTheme.accentNavy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
                      ),
                    ),
                    onPressed: saving ? null : onSaveAll,
                    icon: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 20),
                    label: Text(
                      l.publicSiteCmsSavePricing,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
