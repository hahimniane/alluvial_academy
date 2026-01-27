import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/landing_page_content.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class FeaturesSectionEditor extends StatelessWidget {
  final List<FeatureContent> features;
  final Function(List<FeatureContent>) onChanged;

  const FeaturesSectionEditor({
    super.key,
    required this.features,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.featuresSectionEditor,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.featuresEditorComingSoon,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff6B7280),
            ),
          ),
        ],
      ),
    );
  }
} 