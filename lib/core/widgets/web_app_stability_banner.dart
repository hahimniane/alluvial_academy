import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../services/web_app_stability_service.dart';

/// Floating banner that appears in the top-right when any major screen has
/// reported being stuck for too long. Offers a "Recover" button that bounces
/// the Firestore WebChannel and a "Reload" button that performs a full page
/// reload after attempting recovery first.
///
/// Sized to be unobtrusive on mobile widths and dismissable so power users
/// who know what they are doing can close it without reloading.
class WebAppStabilityBanner extends StatefulWidget {
  const WebAppStabilityBanner({super.key, required this.child});

  final Widget child;

  @override
  State<WebAppStabilityBanner> createState() => _WebAppStabilityBannerState();
}

class _WebAppStabilityBannerState extends State<WebAppStabilityBanner> {
  bool _userDismissed = false;
  bool _lastStuck = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WebAppStabilityState>(
      valueListenable: WebAppStabilityService.instance.state,
      builder: (context, state, _) {
        // Reset dismissal once the stuck condition clears, so the banner can
        // legitimately reappear later if a fresh stall happens.
        if (_lastStuck && !state.anyScreenStuck && _userDismissed) {
          _userDismissed = false;
        }
        _lastStuck = state.anyScreenStuck;

        final visible = state.anyScreenStuck && !_userDismissed;
        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            widget.child,
            if (visible)
              Positioned(
                top: 12,
                right: 12,
                child: _StuckCard(
                  state: state,
                  onRecover: () =>
                      WebAppStabilityService.instance.forceRecover(),
                  onReload: () => WebAppStabilityService.instance.hardReload(),
                  onDismiss: () => setState(() => _userDismissed = true),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StuckCard extends StatelessWidget {
  const _StuckCard({
    required this.state,
    required this.onRecover,
    required this.onReload,
    required this.onDismiss,
  });

  final WebAppStabilityState state;
  final VoidCallback onRecover;
  final VoidCallback onReload;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final reason = state.primaryStuckReason;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cloud_off_outlined,
                      size: 20, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.webStuckBannerTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Semantics(
                    label: l10n.webStuckBannerDismiss,
                    button: true,
                    child: InkWell(
                      onTap: onDismiss,
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 28, right: 4),
                child: Text(
                  reason ?? l10n.webStuckBannerMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 24, right: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (state.isRecovering)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton.icon(
                        onPressed: onRecover,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(l10n.webStuckBannerRecover),
                      ),
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      onPressed: state.isRecovering ? null : onReload,
                      icon: const Icon(Icons.replay, size: 18),
                      label: Text(l10n.webStuckBannerReload),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
