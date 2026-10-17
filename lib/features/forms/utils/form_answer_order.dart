/// Puts a submission's answers back in question order.
///
/// Answers are stored as a map keyed by question id and Firestore returns map
/// keys in no particular order, so viewers sort by the template instead: each
/// question's `order`, or failing that its position in the stored fields.
/// Answers whose question is not on the template keep their stored order and
/// go last.
class FormAnswerOrder {
  const FormAnswerOrder._();

  /// The stored `order` when it is a real number (0 included), else null.
  static num? storedOrder(dynamic value) {
    if (value is num && value.isFinite) return value;
    if (value is String && value.trim().isNotEmpty) {
      final parsed = num.tryParse(value.trim());
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return null;
  }

  /// Question id -> rank (0 = first question) for template `fields` stored as
  /// either a list of field maps or a map keyed by field id.
  static Map<String, int> fieldOrder(dynamic fields) {
    final entries = <_RankedField>[];
    if (fields is List) {
      for (var i = 0; i < fields.length; i++) {
        final field = fields[i];
        if (field is! Map) continue;
        final rawId = field['id']?.toString().trim() ?? '';
        final id = rawId.isEmpty ? 'field_$i' : rawId;
        entries.add(_RankedField(id, i, storedOrder(field['order']) ?? i));
      }
    } else if (fields is Map) {
      var i = 0;
      fields.forEach((key, field) {
        final order = field is Map ? storedOrder(field['order']) : null;
        entries.add(_RankedField(key.toString(), i, order ?? i));
        i++;
      });
    }
    entries.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.position.compareTo(b.position);
    });
    final ranks = <String, int>{};
    for (var rank = 0; rank < entries.length; rank++) {
      ranks.putIfAbsent(entries[rank].id, () => rank);
    }
    return ranks;
  }

  /// [responses] entries sorted by [order]; unknown ids last, in stored order.
  static List<MapEntry<String, V>> orderEntries<V>(
    Map<String, V> responses,
    Map<String, int> order,
  ) {
    final indexed = responses.entries.toList();
    final positions = <String, int>{
      for (var i = 0; i < indexed.length; i++) indexed[i].key: i,
    };
    indexed.sort((a, b) {
      final aRank = order[a.key];
      final bRank = order[b.key];
      if (aRank != null && bRank != null && aRank != bRank) {
        return aRank.compareTo(bRank);
      }
      if (aRank != null && bRank == null) return -1;
      if (aRank == null && bRank != null) return 1;
      return positions[a.key]!.compareTo(positions[b.key]!);
    });
    return indexed;
  }
}

class _RankedField {
  final String id;
  final int position;
  final num order;

  const _RankedField(this.id, this.position, this.order);
}
