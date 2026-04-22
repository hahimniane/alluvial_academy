import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/theme/public_site_cms_tokens.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Dashed image upload area with URL field, optional [Image.network] preview, and pick action.
class ImageUploadZone extends StatelessWidget {
  const ImageUploadZone({
    super.key,
    required this.title,
    required this.urlController,
    required this.busy,
    required this.onPick,
    this.hintText,
    this.actionLabel,
  });

  final String title;
  final TextEditingController urlController;
  final bool busy;
  final VoidCallback onPick;
  final String? hintText;
  /// If null, [AppLocalizations.publicSiteCmsLandingUpload] is used.
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Material(
      color: PublicSiteCmsTheme.surface,
      borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusLg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: PublicSiteCmsTheme.border),
          borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusLg),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: PublicSiteCmsTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlController,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText: hintText ?? 'https://…',
                  filled: true,
                  fillColor: PublicSiteCmsTheme.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
                    borderSide: const BorderSide(color: PublicSiteCmsTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
                    borderSide: const BorderSide(color: PublicSiteCmsTheme.accentNavy, width: 1.5),
                  ),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: urlController,
                builder: (context, _) {
                  final u = urlController.text.trim();
                  final hasUrl = u.isNotEmpty;
                  return Container(
                    constraints: const BoxConstraints(minHeight: 120, maxHeight: 200),
                    decoration: BoxDecoration(
                      color: PublicSiteCmsTheme.bg,
                      borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
                      border: Border.all(
                        color: PublicSiteCmsTheme.border,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: hasUrl
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd - 1),
                            child: Image.network(
                              u,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              webHtmlElementStrategy:
                                  kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
                              errorBuilder: (_, __, ___) => _emptyDropHint(l),
                            ),
                          )
                        : _emptyDropHint(l),
                  );
                },
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: busy ? null : onPick,
                style: FilledButton.styleFrom(
                  backgroundColor: PublicSiteCmsTheme.accentNavy,
                ),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_file, size: 20),
                label: Text(
                  actionLabel ?? l.publicSiteCmsLandingUpload,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyDropHint(AppLocalizations l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          l.publicSiteCmsImageUploadEmptyHint,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: PublicSiteCmsTheme.textTertiary,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
