import '../../../l10n/app_localizations.dart';

const quizCompetitionDivisionIds = <String>[
  'early_learners',
  'juniors',
  'youth',
  'adults',
];

String quizCompetitionDivisionLabel(
  AppLocalizations l10n,
  String divisionId,
) {
  switch (divisionId) {
    case 'early_learners':
      return l10n.quizCompetitionDivisionEarlyLearners;
    case 'juniors':
      return l10n.quizCompetitionDivisionJuniors;
    case 'youth':
      return l10n.quizCompetitionDivisionYouth;
    case 'adults':
      return l10n.quizCompetitionDivisionAdults;
    default:
      return l10n.quizCompetitionDivisionUnassigned;
  }
}
