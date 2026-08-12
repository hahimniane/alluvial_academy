enum SearchNameMode {
  contains,
  exact,
}

class AppSearch {
  static bool matches({
    required String query,
    Iterable<String> names = const [],
    Iterable<String> emails = const [],
    Iterable<String> phones = const [],
    Iterable<String> ids = const [],
    Iterable<String> additionalValues = const [],
    SearchNameMode nameMode = SearchNameMode.contains,
  }) {
    final normalizedQuery = normalizeText(query);
    if (normalizedQuery.isEmpty) return true;

    final nameMatch = names.any((name) {
      final normalizedName = normalizeText(name);
      if (nameMode == SearchNameMode.exact) {
        return normalizedName == normalizedQuery;
      }
      return normalizedName.contains(normalizedQuery);
    });
    if (nameMatch) return true;

    if (emails.any(
      (email) => normalizeText(email).contains(normalizedQuery),
    )) {
      return true;
    }

    final normalizedIdentifierQuery = normalizeIdentifier(query);
    if (ids.any((id) {
      final normalizedId = normalizeText(id);
      return normalizedId.contains(normalizedQuery) ||
          (normalizedIdentifierQuery.isNotEmpty &&
              normalizeIdentifier(id).contains(normalizedIdentifierQuery));
    })) {
      return true;
    }

    final queryDigits = digitsOnly(query);
    if (looksLikePhone(query) && queryDigits.length >= 7) {
      final queryVariants = _phoneVariants(queryDigits);
      final phoneMatch = phones.any((phone) {
        final phoneDigits = digitsOnly(phone);
        if (phoneDigits.length < 7) return false;
        final phoneVariants = _phoneVariants(phoneDigits);
        return queryVariants.any(
          (queryVariant) => phoneVariants.any(
            (phoneVariant) =>
                phoneVariant == queryVariant ||
                phoneVariant.endsWith(queryVariant) ||
                queryVariant.endsWith(phoneVariant),
          ),
        );
      });
      if (phoneMatch) return true;
    }

    return additionalValues.any(
      (value) => normalizeText(value).contains(normalizedQuery),
    );
  }

  static bool matchesMap({
    required String query,
    required Map<String, dynamic> data,
    String? documentId,
    Iterable<String> additionalValues = const [],
    SearchNameMode nameMode = SearchNameMode.contains,
  }) {
    final firstName = _firstValue(
      data,
      const ['first_name', 'firstName', 'userFirstName'],
    );
    final lastName = _firstValue(
      data,
      const ['last_name', 'lastName', 'userLastName'],
    );
    final fullName = '$firstName $lastName'.trim();

    return matches(
      query: query,
      names: [
        ..._values(
          data,
          const [
            'name',
            'displayName',
            'display_name',
            'fullName',
            'full_name',
            'userName',
          ],
        ),
        fullName,
        '$lastName $firstName'.trim(),
      ],
      emails: _values(
        data,
        const ['email', 'e-mail', 'userEmail', 'user_email'],
      ),
      phones: _values(
        data,
        const [
          'phone',
          'phone_number',
          'phoneNumber',
          'mobile_phone',
          'mobilePhone',
          'userPhone',
          'user_phone',
        ],
      ),
      ids: [
        if (documentId != null) documentId,
        ..._values(
          data,
          const [
            'id',
            'uid',
            'documentId',
            'document_id',
            'authUid',
            'auth_uid',
            'userId',
            'user_id',
            'teacherId',
            'teacher_id',
            'studentId',
            'student_id',
            'studentCode',
            'student_code',
            'kioskCode',
            'kiosk_code',
            'kiosqueCode',
          ],
        ),
      ],
      additionalValues: additionalValues,
      nameMode: nameMode,
    );
  }

  static String normalizeText(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String digitsOnly(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  static String normalizeIdentifier(String value) =>
      normalizeText(value).replaceAll(RegExp(r'[^a-z0-9]'), '');

  static bool looksLikePhone(String value) =>
      RegExp(r'^[\d\s()+.\-]+$').hasMatch(value.trim());

  static Iterable<String> _values(
    Map<String, dynamic> data,
    Iterable<String> keys,
  ) sync* {
    for (final key in keys) {
      final value = data[key];
      if (value != null) yield value.toString();
    }
  }

  static String _firstValue(
    Map<String, dynamic> data,
    Iterable<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static Set<String> _phoneVariants(String digits) => {
        digits,
        if (digits.startsWith('0') && digits.length > 7) digits.substring(1),
      };
}
