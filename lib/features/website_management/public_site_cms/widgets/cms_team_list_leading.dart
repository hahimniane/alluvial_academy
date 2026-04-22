import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/core/models/public_site_cms_models.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Team list avatar with [Image.network] error handling (web-friendly).
class CmsTeamListLeading extends StatelessWidget {
  const CmsTeamListLeading({super.key, required this.member});

  final PublicSiteTeamMember member;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const size = 44.0;
    final initial =
        member.name.trim().isNotEmpty ? member.name.trim()[0].toUpperCase() : '?';
    final url = member.imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            webHtmlElementStrategy:
                kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
            errorBuilder: (_, __, ___) => _fallback(context, initial, size, l),
          ),
        ),
      );
    }
    final asset = member.photoAsset?.trim();
    if (asset != null && asset.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(context, initial, size, l),
          ),
        ),
      );
    }
    return CircleAvatar(radius: size / 2, child: Text(initial));
  }

  Widget _fallback(
    BuildContext context,
    String initial,
    double size,
    AppLocalizations l,
  ) {
    return Tooltip(
      message: l.publicSiteCmsTeamImageLoadFailed,
      child: Container(
        width: size,
        height: size,
        color: const Color(0xffE2E8F0),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}
