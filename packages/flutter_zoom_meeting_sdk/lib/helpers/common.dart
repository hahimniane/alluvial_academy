/// This interface is used to convert the params to a map
abstract class MappableParams {
  Map<String, dynamic> toMap();
}

/// This function will loop the enum and generate a uppercase + snake case format
/// {
///   'SUCCESS': StatusMeetingError.success,
///   'INCORRECT_MEETING_NUMBER': StatusMeetingError.incorrectMeetingNumber,
///   ...
/// }
Map<String, T> generateStatusMap<T>(
  List<T> values,
  String Function(T) nameGetter,
) {
  return {for (var e in values) _toSnakeCase(nameGetter(e)).toUpperCase(): e};
}

/// This function will convert the input string to a snake case format
String _toSnakeCase(String input) {
  return input
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)}_${match.group(2)}',
      )
      .toUpperCase();
}
