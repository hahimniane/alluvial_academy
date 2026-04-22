import 'package:flutter/material.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/theme/public_site_cms_tokens.dart';

/// Hairline card with subtle lift on pointer hover (web/desktop).
class HoverListCard extends StatefulWidget {
  const HoverListCard({super.key, required this.child});

  final Widget child;

  @override
  State<HoverListCard> createState() => _HoverListCardState();
}

class _HoverListCardState extends State<HoverListCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: PublicSiteCmsTheme.hoverDuration,
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: PublicSiteCmsTheme.surface,
          borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
          border: Border.all(
            color: _hover
                ? PublicSiteCmsTheme.accentNavy.withValues(alpha: 0.25)
                : PublicSiteCmsTheme.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hover ? 0.1 : 0.05),
              blurRadius: _hover ? 12 : 6,
              offset: Offset(0, _hover ? 3 : 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
          child: widget.child,
        ),
      ),
    );
  }
}
