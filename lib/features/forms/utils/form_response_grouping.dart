import 'package:cloud_firestore/cloud_firestore.dart';

enum FormDefinitionSource { legacy, template }

class FormDefinitionRecord {
  final String id;
  final Map<String, dynamic> data;
  final FormDefinitionSource source;

  const FormDefinitionRecord({
    required this.id,
    required this.data,
    required this.source,
  });
}

class FormResponseRecord {
  final String id;
  final Map<String, dynamic> data;

  const FormResponseRecord({
    required this.id,
    required this.data,
  });

  String get formId => (data['formId'] ?? '').toString().trim();
  String get templateId => (data['templateId'] ?? '').toString().trim();
  String get formName =>
      (data['formName'] ?? data['form_title'] ?? data['title'] ?? '')
          .toString()
          .trim();
}

class FormResponseGroup {
  final String key;
  final String title;
  final int entries;
  final String representativeFormId;
  final List<String> responseFormIds;
  final List<String> definitionIds;
  final Map<String, dynamic>? representativeData;

  const FormResponseGroup({
    required this.key,
    required this.title,
    required this.entries,
    required this.representativeFormId,
    required this.responseFormIds,
    required this.definitionIds,
    required this.representativeData,
  });
}

class FormResponseGrouping {
  const FormResponseGrouping._();

  static List<FormResponseGroup> buildGroups({
    required List<FormDefinitionRecord> definitions,
    required List<FormResponseRecord> responses,
  }) {
    final definitionsById = <String, FormDefinitionRecord>{
      for (final definition in definitions) definition.id: definition,
    };

    final responseCountByFormId = <String, int>{};
    for (final response in responses) {
      final formId = response.formId;
      if (formId.isEmpty) continue;
      responseCountByFormId.update(formId, (value) => value + 1,
          ifAbsent: () => 1);
    }

    final builders = <String, _GroupBuilder>{};
    for (final response in responses) {
      final matchedDefinitions = <FormDefinitionRecord>[];
      if (response.formId.isNotEmpty &&
          definitionsById.containsKey(response.formId)) {
        matchedDefinitions.add(definitionsById[response.formId]!);
      }
      if (response.templateId.isNotEmpty &&
          definitionsById.containsKey(response.templateId) &&
          response.templateId != response.formId) {
        matchedDefinitions.add(definitionsById[response.templateId]!);
      }

      final resolvedTitle = _resolveResponseTitle(response, matchedDefinitions);
      final normalizedTitle = _normalizeTitle(resolvedTitle);
      final groupKey = normalizedTitle.isNotEmpty
          ? 'title:$normalizedTitle'
          : 'form:${response.formId.isNotEmpty ? response.formId : response.id}';

      final builder =
          builders.putIfAbsent(groupKey, () => _GroupBuilder(groupKey));
      builder.addResponse(response);
      for (final definition in matchedDefinitions) {
        builder.addDefinition(definition);
      }
    }

    final groups = builders.values
        .map((builder) => builder.build(responseCountByFormId))
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return groups;
  }

  static String resolveTitleFromData(Map<String, dynamic>? data) {
    final title = (data?['title'] ?? data?['name'] ?? '').toString().trim();
    return title.isEmpty ? 'Untitled Form' : title;
  }

  static bool isArchived(Map<String, dynamic>? data) {
    if (data == null) return false;
    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status == 'archived' || status == 'inactive') {
      return true;
    }

    final isActive = data['isActive'];
    if (isActive is bool) {
      return !isActive;
    }

    return false;
  }

  static String resolveStatus(Map<String, dynamic>? data) {
    if (data == null) return 'active';
    final status = (data['status'] ?? '').toString().trim();
    if (status.isNotEmpty) return status;

    final isActive = data['isActive'];
    if (isActive is bool) {
      return isActive ? 'active' : 'inactive';
    }

    return 'active';
  }

  static DateTime? resolveCreatedAt(Map<String, dynamic>? data) {
    if (data == null) return null;
    return _toDateTime(data['createdAt']) ?? _toDateTime(data['updatedAt']);
  }

  static String normalizeTitle(String value) => _normalizeTitle(value);

  static String _resolveResponseTitle(
    FormResponseRecord response,
    List<FormDefinitionRecord> matchedDefinitions,
  ) {
    if (response.formName.isNotEmpty) return response.formName;
    for (final definition in matchedDefinitions) {
      final title = resolveTitleFromData(definition.data);
      if (title != 'Untitled Form') return title;
    }
    return response.formId.isNotEmpty ? response.formId : 'Untitled Form';
  }

  static String _normalizeTitle(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class _GroupBuilder {
  final String key;
  final List<FormResponseRecord> responses = [];
  final Map<String, FormDefinitionRecord> definitions = {};
  final Set<String> responseFormIds = {};

  _GroupBuilder(this.key);

  void addResponse(FormResponseRecord response) {
    responses.add(response);
    if (response.formId.isNotEmpty) {
      responseFormIds.add(response.formId);
    }
  }

  void addDefinition(FormDefinitionRecord definition) {
    definitions[definition.id] = definition;
  }

  FormResponseGroup build(Map<String, int> responseCountByFormId) {
    final representative = _pickRepresentative(responseCountByFormId);
    final representativeData = representative?.data;
    final title = _resolveGroupTitle(representativeData);

    return FormResponseGroup(
      key: key,
      title: title,
      entries: responses.length,
      representativeFormId: representative?.id ??
          (responseFormIds.isNotEmpty ? responseFormIds.first : key),
      responseFormIds: responseFormIds.toList()..sort(),
      definitionIds: definitions.keys.toList()..sort(),
      representativeData: representativeData,
    );
  }

  FormDefinitionRecord? _pickRepresentative(
      Map<String, int> responseCountByFormId) {
    final candidates = definitions.values.toList();
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final aCount = responseCountByFormId[a.id] ?? 0;
      final bCount = responseCountByFormId[b.id] ?? 0;
      if (aCount != bCount) return bCount.compareTo(aCount);

      if (a.source != b.source) {
        if (a.source == FormDefinitionSource.template) return -1;
        if (b.source == FormDefinitionSource.template) return 1;
      }

      final aTime = FormResponseGrouping.resolveCreatedAt(a.data);
      final bTime = FormResponseGrouping.resolveCreatedAt(b.data);
      if (aTime != null && bTime != null) {
        return bTime.compareTo(aTime);
      }
      if (aTime != null) return -1;
      if (bTime != null) return 1;
      return a.id.compareTo(b.id);
    });

    return candidates.first;
  }

  String _resolveGroupTitle(Map<String, dynamic>? representativeData) {
    if (representativeData != null) {
      return FormResponseGrouping.resolveTitleFromData(representativeData);
    }

    for (final response in responses) {
      if (response.formName.isNotEmpty) return response.formName;
    }

    if (responseFormIds.isNotEmpty) return responseFormIds.first;
    return 'Untitled Form';
  }
}
