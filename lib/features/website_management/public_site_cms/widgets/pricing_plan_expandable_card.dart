import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/core/constants/pricing_plan_ids.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/theme/public_site_cms_tokens.dart';

class PricingPlanExpandableCard extends StatelessWidget {
  const PricingPlanExpandableCard({
    super.key,
    required this.contextForTheme,
    required this.planId,
    required this.title,
    required this.subtitle,
    required this.bulletsCtrl,
    required this.v2IslamicBase,
    required this.v2IslamicDiscount,
    required this.v2IslamicThreshold,
    required this.v2TutoringBase,
    required this.v2TutoringDiscount,
    required this.v2TutoringThreshold,
    required this.v2GroupHourly,
    required this.onSaveThisTrack,
    required this.saving,
  });

  final BuildContext contextForTheme;
  final String planId;
  final String title;
  final String subtitle;
  final TextEditingController? bulletsCtrl;
  final TextEditingController? v2IslamicBase;
  final TextEditingController? v2IslamicDiscount;
  final TextEditingController? v2IslamicThreshold;
  final TextEditingController? v2TutoringBase;
  final TextEditingController? v2TutoringDiscount;
  final TextEditingController? v2TutoringThreshold;
  final TextEditingController? v2GroupHourly;
  final VoidCallback? onSaveThisTrack;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isIslamicTrack = planId == PricingPlanIds.islamic;
    final isTutoringTrack = planId == PricingPlanIds.tutoring;
    final isGroupTrack = planId == PricingPlanIds.group;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: PublicSiteCmsTheme.surface,
        borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: PublicSiteCmsTheme.border),
            borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(contextForTheme).copyWith(
              dividerColor: Colors.transparent,
              expansionTileTheme: const ExpansionTileThemeData(
                backgroundColor: Colors.transparent,
                collapsedBackgroundColor: Colors.transparent,
              ),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              childrenPadding: EdgeInsets.zero,
              iconColor: PublicSiteCmsTheme.textSecondary,
              collapsedIconColor: PublicSiteCmsTheme.textSecondary,
              title: Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: PublicSiteCmsTheme.textPrimary,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: PublicSiteCmsTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isIslamicTrack) ...[
                        TextField(
                          decoration: publicSiteCmsInputDecoration(
                            l.publicSiteCmsTrackBaseHourly,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          controller: v2IslamicBase,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: publicSiteCmsInputDecoration(
                            l.publicSiteCmsTrackDiscountHourly,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          controller: v2IslamicDiscount,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: publicSiteCmsInputDecoration(
                            l.publicSiteCmsTrackDiscountThreshold,
                            helper: l.publicSiteCmsTrackDiscountThresholdHint,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          controller: v2IslamicThreshold,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (isTutoringTrack) ...[
                        TextField(
                          decoration: publicSiteCmsInputDecoration(
                            l.publicSiteCmsTrackBaseHourly,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          controller: v2TutoringBase,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: publicSiteCmsInputDecoration(
                            l.publicSiteCmsTrackDiscountHourly,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          controller: v2TutoringDiscount,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: publicSiteCmsInputDecoration(
                            l.publicSiteCmsTrackDiscountThreshold,
                            helper: l.publicSiteCmsTrackDiscountThresholdHint,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          controller: v2TutoringThreshold,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (isGroupTrack) ...[
                        TextField(
                          decoration: publicSiteCmsInputDecoration(
                            l.publicSiteCmsHourly,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          controller: v2GroupHourly,
                        ),
                        const SizedBox(height: 12),
                      ],
                      Divider(height: 24, color: PublicSiteCmsTheme.borderStrong),
                      const SizedBox(height: 4),
                      Text(
                        l.publicSiteCmsBulletsHint,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: PublicSiteCmsTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: bulletsCtrl,
                        maxLines: 5,
                        style: GoogleFonts.inter(fontSize: 14, height: 1.4),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: PublicSiteCmsTheme.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
                            borderSide: const BorderSide(color: PublicSiteCmsTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
                            borderSide: const BorderSide(color: PublicSiteCmsTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
                            borderSide: const BorderSide(
                              color: PublicSiteCmsTheme.accentNavy,
                              width: 1.5,
                            ),
                          ),
                          hintText: l.publicSiteCmsBulletsPlaceholder,
                          hintStyle: GoogleFonts.inter(
                            color: PublicSiteCmsTheme.textTertiary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilledButton.tonal(
                          onPressed: saving || onSaveThisTrack == null ? null : onSaveThisTrack,
                          child: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(l.publicSiteCmsSaveThisTrack),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration publicSiteCmsInputDecoration(String label, {String? helper}) {
  return InputDecoration(
    labelText: label,
    helperText: helper,
    labelStyle: GoogleFonts.inter(fontSize: 14, color: PublicSiteCmsTheme.textSecondary),
    helperStyle: GoogleFonts.inter(
      fontSize: 12,
      color: PublicSiteCmsTheme.textTertiary,
      height: 1.2,
    ),
    filled: true,
    fillColor: PublicSiteCmsTheme.bg,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
      borderSide: const BorderSide(color: PublicSiteCmsTheme.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
      borderSide: const BorderSide(color: PublicSiteCmsTheme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
      borderSide: const BorderSide(color: PublicSiteCmsTheme.accentNavy, width: 1.5),
    ),
  );
}
