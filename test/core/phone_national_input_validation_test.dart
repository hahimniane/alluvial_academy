import 'package:alluwalacademyadmin/core/utils/phone_national_input_validation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_field/phone_number.dart';

void main() {
  group('PhoneNationalInputValidation', () {
    test('isValidNationalForIso accepts valid US number', () {
      expect(
        PhoneNationalInputValidation.isValidNationalForIso(
            'US', '2015550123'),
        isTrue,
      );
    });

    test('isValidNationalForIso rejects too-short US national', () {
      expect(
        PhoneNationalInputValidation.isValidNationalForIso('US', '201555'),
        isFalse,
      );
    });

    test('isValidNationalForIso rejects unknown ISO', () {
      expect(
        PhoneNationalInputValidation.isValidNationalForIso('ZZ', '123456789'),
        isFalse,
      );
    });

    test('optional validator accepts empty national number', () {
      expect(
        PhoneNationalInputValidation.validateOptionalNational(
          PhoneNumber(countryISOCode: 'LR', countryCode: '+231', number: ''),
          'err',
        ),
        isNull,
      );
    });

    test('isValidInternationalString accepts E.164-style full number', () {
      expect(
        PhoneNationalInputValidation.isValidInternationalString('+12015550123'),
        isTrue,
      );
    });

    test('isValidInternationalString rejects invalid subscriber', () {
      expect(
        PhoneNationalInputValidation.isValidInternationalString('+1201555'),
        isFalse,
      );
    });
  });
}
