import 'package:flutter/material.dart';

import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import '../utils/form_review_status.dart';

class FormReviewStatusBadge extends StatelessWidget {
  final Object? status;
  final bool compact;

  const FormReviewStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  static Color colorFor(Object? status) {
    switch (FormReviewStatus.normalize(status)) {
      case FormReviewStatus.inReview:
        return const Color(0xFFF59E0B);
      case FormReviewStatus.accepted:
        return const Color(0xFF059669);
      case FormReviewStatus.rejected:
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  static String labelFor(BuildContext context, Object? status) {
    final l10n = AppLocalizations.of(context)!;
    switch (FormReviewStatus.normalize(status)) {
      case FormReviewStatus.seen:
        return l10n.formReviewStatusSeen;
      case FormReviewStatus.inReview:
        return l10n.formReviewStatusInReview;
      case FormReviewStatus.accepted:
        return l10n.formReviewStatusAccepted;
      case FormReviewStatus.rejected:
        return l10n.formReviewStatusRejected;
      default:
        return l10n.formReviewStatusNotReviewed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = FormReviewStatus.normalize(status);
    final color = colorFor(normalizedStatus);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 7,
            height: compact ? 6 : 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              labelFor(context, normalizedStatus),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
