String _normalizeFormIdentifier(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

bool isDailyClassReportForm({
  required String formTitle,
  String? templateId,
}) {
  final normalizedTitle = _normalizeFormIdentifier(formTitle);
  final normalizedTemplateId = _normalizeFormIdentifier(templateId ?? '');

  if (normalizedTemplateId == 'daily_class_report') {
    return true;
  }

  return normalizedTitle.contains('daily class report') ||
      normalizedTitle.contains('rapport de classe');
}
