import '../../l10n/app_localizations.dart';

/// Why a penalty or deduction was given. The codes are the fixed list in
/// docs/finance/SPEC.md ("Penalty reasons (structured)") and must match
/// apps/web/src/lib/finance/penalties.ts and functions/utils/penalty_reasons.js.
class PenaltyReasons {
  PenaltyReasons._();

  static const String lateClockIn = 'late_clock_in';
  static const String missedClass = 'missed_class';
  static const String lateClassReport = 'late_class_report';
  static const String leftClassEarly = 'left_class_early';
  static const String noCameraOrSetup = 'no_camera_or_setup';
  static const String conduct = 'conduct';
  static const String other = 'other';

  static const List<String> codes = [
    lateClockIn,
    missedClass,
    lateClassReport,
    leftClassEarly,
    noCameraOrSetup,
    conduct,
    other,
  ];

  /// English labels written into the plain-text `reason` field so readers that
  /// predate the structured reason keep working.
  static const Map<String, String> englishLabels = {
    lateClockIn: 'Late clock-in',
    missedClass: 'Missed a class without notice',
    lateClassReport: 'Late class report',
    leftClassEarly: 'Left class early',
    noCameraOrSetup: 'Camera/setup not as required',
    conduct: 'Conduct',
    other: 'Other',
  };

  /// Audit issue types the system raises, and the penalty code each one
  /// carries when it turns into a penalty.
  static const Map<String, String> byIssueType = {
    'missed_classes': missedClass,
    'late_clock_ins': lateClockIn,
    'missing_forms': lateClassReport,
  };

  static bool isValid(String? code) => code != null && codes.contains(code);

  /// A stored code, or [other] when it is missing or unknown.
  static String normalize(String? code) => isValid(code) ? code! : other;

  static String? forIssueType(String? issueType) => byIssueType[issueType];

  static String label(AppLocalizations l10n, String? code) {
    switch (normalize(code)) {
      case lateClockIn:
        return l10n.penaltyReasonLateClockIn;
      case missedClass:
        return l10n.penaltyReasonMissedClass;
      case lateClassReport:
        return l10n.penaltyReasonLateClassReport;
      case leftClassEarly:
        return l10n.penaltyReasonLeftClassEarly;
      case noCameraOrSetup:
        return l10n.penaltyReasonNoCameraOrSetup;
      case conduct:
        return l10n.penaltyReasonConduct;
      default:
        return l10n.penaltyReasonOther;
    }
  }

  /// "Label" or "Label: note", in the viewer's language.
  static String display(AppLocalizations l10n, String? code, String? note) {
    final text = label(l10n, code);
    final n = (note ?? '').trim();
    return n.isEmpty ? text : '$text: $n';
  }

  /// The plain-text reason older readers show: English label plus the note.
  static String composeReasonText(String? code, String? note) {
    final text = englishLabels[normalize(code)]!;
    final n = (note ?? '').trim();
    return n.isEmpty ? text : '$text — $n';
  }

  /// Why a reason/note pair cannot be saved, or null when it can.
  static PenaltyReasonError? validate(String? code, String? note) {
    if (!isValid(code)) return PenaltyReasonError.reasonMissing;
    if (code == other && (note ?? '').trim().isEmpty) {
      return PenaltyReasonError.noteMissing;
    }
    return null;
  }

  static String errorText(AppLocalizations l10n, PenaltyReasonError error) {
    switch (error) {
      case PenaltyReasonError.reasonMissing:
        return l10n.penaltyReasonRequiredError;
      case PenaltyReasonError.noteMissing:
        return l10n.penaltyNoteRequiredError;
    }
  }
}

enum PenaltyReasonError { reasonMissing, noteMissing }

/// A penalty's reason as stored: a code plus a free-text note.
class PenaltyReasonValue {
  final String code;
  final String note;

  const PenaltyReasonValue(this.code, this.note);

  /// Reads an entry that may predate structured reasons: no valid code means
  /// [PenaltyReasons.other], with the old free text as the note.
  factory PenaltyReasonValue.fromStored({
    String? code,
    String? note,
    String? legacyReason,
  }) {
    if (PenaltyReasons.isValid(code)) {
      return PenaltyReasonValue(code!, (note ?? '').trim());
    }
    final text = (note ?? legacyReason ?? '').trim();
    return PenaltyReasonValue(PenaltyReasons.other, text == '—' ? '' : text);
  }

  String get reasonText => PenaltyReasons.composeReasonText(code, note);
}
