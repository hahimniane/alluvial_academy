import 'package:intl_phone_field/phone_number.dart' as intl;
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// [intl_phone_field] caps input with each country's [Country.maxLength], but that
/// metadata is often wrong. For **per-country** length and pattern checks we use
/// [phone_numbers_parser] (libphonenumber metadata), while still using
/// [intl_phone_field] for the country picker UI.
abstract final class PhoneNationalInputValidation {
  static String digitsOnly(String raw) =>
      raw.replaceAll(RegExp(r'\D'), '');

  static IsoCode? _tryParseIso(String? code) {
    if (code == null || code.trim().isEmpty) return null;
    final u = code.trim().toUpperCase();
    try {
      return IsoCode.fromJson(u);
    } catch (_) {
      return null;
    }
  }

  /// National (subscriber) digits for [iso2] alpha-2 (e.g. `US`, `LR`).
  static bool isValidNationalForIso(String iso2, String nationalRaw) {
    final iso = _tryParseIso(iso2);
    if (iso == null) return false;
    final nsn = digitsOnly(nationalRaw);
    if (nsn.isEmpty) return false;
    return PhoneNumber(isoCode: iso, nsn: nsn).isValid();
  }

  /// Max national digits accepted by libphonenumber metadata for [iso2].
  ///
  /// Returns `null` when ISO is unknown or metadata does not expose a stable
  /// bound through length validation.
  static int? maxNationalLengthForIso(String iso2) {
    final iso = _tryParseIso(iso2);
    if (iso == null) return null;

    // Country national subscriber numbers are typically well below this.
    // We keep a generous cap while deriving the true max from metadata.
    int? max;
    for (var len = 1; len <= 20; len++) {
      final sample = '1' * len;
      if (PhoneNumber(isoCode: iso, nsn: sample).isValidLength()) {
        max = len;
      }
    }
    return max;
  }

  /// Full international string (e.g. `+14155552671` or pasted E.164).
  static bool isValidInternationalString(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return false;
    try {
      return PhoneNumber.parse(t).isValid();
    } catch (_) {
      return false;
    }
  }

  /// Empty national number is allowed (optional phone).
  static String? validateOptionalNational(
    intl.PhoneNumber? phone,
    String invalidForCountryMessage,
  ) {
    if (phone == null) return null;
    final d = digitsOnly(phone.number);
    if (d.isEmpty) return null;
    if (!isValidNationalForIso(phone.countryISOCode, d)) {
      return invalidForCountryMessage;
    }
    return null;
  }

  /// National number must be present and valid for the selected country.
  static String? validateRequiredNational(
    intl.PhoneNumber? phone,
    String requiredMessage,
    String invalidForCountryMessage,
  ) {
    if (phone == null) return requiredMessage;
    final d = digitsOnly(phone.number);
    if (d.isEmpty) return requiredMessage;
    if (!isValidNationalForIso(phone.countryISOCode, d)) {
      return invalidForCountryMessage;
    }
    return null;
  }
}
