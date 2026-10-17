/// Who a form is for, read from however the form stores it.
///
/// "Who can see this" writes `allowedRoles` as a list of role keys, but older
/// documents carry the audience as a map, a comma-separated string, under
/// `audience` / `targetRoles`, or as a legacy `permissions.role`. Every reader
/// goes through here so a form aimed at parents is seen as aimed at parents
/// whichever shape it was saved in.
class FormAudience {
  const FormAudience._();

  static const List<String> _audienceKeys = [
    'allowedRoles',
    'audience',
    'targetRoles',
    'roles',
  ];

  /// The roles named by [data], as stored (trimmed), or null when the form
  /// carries no audience at all.
  static List<String>? parse(Map<String, dynamic> data) {
    for (final key in _audienceKeys) {
      final roles = _roleList(data[key]);
      if (roles != null && roles.isNotEmpty) return roles;
    }
    final permissions = data['permissions'];
    if (permissions is Map) {
      final type = permissions['type']?.toString().trim().toLowerCase();
      if (type != 'public') {
        final roles =
            _roleList(permissions['roles']) ?? _roleList(permissions['role']);
        if (roles != null && roles.isNotEmpty) return roles;
      }
    }
    for (final key in _audienceKeys) {
      final roles = _roleList(data[key]);
      if (roles != null) return roles;
    }
    return null;
  }

  static List<String>? _roleList(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return value
          .split(RegExp(r'[,;|]'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
    }
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is Map) {
      // {parent: true, teacher: false} names roles by key; {0: 'parent'} by value.
      final flags = value.values.every((v) => v is bool);
      if (flags) {
        return value.entries
            .where((e) => e.value == true)
            .map((e) => e.key.toString().trim())
            .where((key) => key.isNotEmpty)
            .toList();
      }
      return value.values
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return null;
  }

  /// A role key in its canonical singular, lower-case form.
  static String normalizeRole(String role) {
    final normalized = role.trim().toLowerCase();
    switch (normalized) {
      case 'tutor':
      case 'tutors':
      case 'teachers':
      case 'instructor':
      case 'instructors':
        return 'teacher';
      case 'admins':
      case 'administrator':
      case 'administrators':
      case 'super_admin':
        return 'admin';
      case 'coaches':
        return 'coach';
      case 'students':
        return 'student';
      case 'parents':
      case 'guardian':
      case 'guardians':
      case 'parent/guardian':
      case 'parents/guardians':
        return 'parent';
      default:
        return normalized;
    }
  }

  static bool includes(List<String>? roles, String role) {
    if (roles == null || roles.isEmpty) return false;
    final wanted = normalizeRole(role);
    return roles.any((r) => normalizeRole(r) == wanted);
  }
}
