import '../../../core/utils/app_search.dart';

Map<String, dynamic> buildParentSearchRecord({
  required String documentId,
  required Map<String, dynamic> data,
  required int studentCount,
}) {
  final firstName = _firstValue(
    data,
    const ['first_name', 'firstName', 'userFirstName'],
  );
  final lastName = _firstValue(
    data,
    const ['last_name', 'lastName', 'userLastName'],
  );
  final storedName = _firstValue(
    data,
    const [
      'name',
      'displayName',
      'display_name',
      'fullName',
      'full_name',
      'userName',
    ],
  );
  final email = _firstValue(
    data,
    const ['email', 'e-mail', 'userEmail', 'user_email'],
  );
  final phone = _firstValue(
    data,
    const [
      'phone_number',
      'phoneNumber',
      'mobile_phone',
      'mobilePhone',
      'phone',
      'userPhone',
      'user_phone',
    ],
  );
  final countryCode = _firstValue(
    data,
    const ['country_code', 'countryCode'],
  );

  return {
    ...data,
    'id': documentId,
    'name': storedName.isNotEmpty ? storedName : '$firstName $lastName'.trim(),
    'email': email,
    'phone_number': _withCountryCode(countryCode, phone),
    'studentCount': studentCount,
  };
}

bool matchesParentSearch(
  Map<String, dynamic> parent,
  String query,
) {
  return AppSearch.matchesMap(
    query: query,
    data: parent,
    documentId: parent['id']?.toString(),
  );
}

String _firstValue(
  Map<String, dynamic> data,
  Iterable<String> keys,
) {
  for (final key in keys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _withCountryCode(String countryCode, String phone) {
  if (countryCode.isEmpty || phone.isEmpty) return phone;

  final countryDigits = AppSearch.digitsOnly(countryCode);
  final phoneDigits = AppSearch.digitsOnly(phone);
  if (countryDigits.isEmpty || phoneDigits.startsWith(countryDigits)) {
    return phone;
  }

  return '$countryCode$phone';
}
