import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// The parent dashboard, payment-error and sign-up strings resolve in
/// French and Arabic and are not left as their English source.
void main() {
  Future<AppLocalizations> load(String code) =>
      AppLocalizations.delegate.load(Locale(code));

  test('parent-facing keys are translated in French and Arabic', () async {
    final en = await load('en');
    for (final code in ['fr', 'ar']) {
      final other = await load(code);
      final pairs = <String, List<String>>{
        'parentAnalyticsTitle': [
          en.parentAnalyticsTitle,
          other.parentAnalyticsTitle
        ],
        'parentProgressTitle': [
          en.parentProgressTitle,
          other.parentProgressTitle
        ],
        'parentProgressNeedsSupport': [
          en.parentProgressNeedsSupport,
          other.parentProgressNeedsSupport
        ],
        'paymentErrorGeneric': [
          en.paymentErrorGeneric,
          other.paymentErrorGeneric
        ],
        'paymentErrorAlreadyPaid': [
          en.paymentErrorAlreadyPaid,
          other.paymentErrorAlreadyPaid
        ],
        'loginSignUpForClass': [
          en.loginSignUpForClass,
          other.loginSignUpForClass
        ],
        'userParentEmail': [en.userParentEmail, other.userParentEmail],
      };
      pairs.forEach((key, v) {
        expect(v[1], isNotEmpty, reason: '$code $key');
        expect(v[1], isNot(equals(v[0])),
            reason: '$key is still English in $code');
      });
    }

    final fr = await load('fr');
    expect(fr.parentAnalyticsMinLate('2.5'), '2.5 min en retard');
    expect(fr.parentAnalyticsAttendancePercent('80'), '80 % d\'assiduité');
  });
}
