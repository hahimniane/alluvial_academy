import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../enums/shift_enums.dart';

DateTime _weekdayReferenceDate(WeekDay day) {
  // 2020-01-06 is a Monday. Use it as a stable reference week.
  return DateTime.utc(2020, 1, 6).add(Duration(days: day.value - 1));
}

extension WeekDayLocalization on WeekDay {
  String localizedShortName(AppLocalizations l10n) {
    return DateFormat.E(l10n.localeName).format(_weekdayReferenceDate(this));
  }

  String localizedFullName(AppLocalizations l10n) {
    return DateFormat.EEEE(l10n.localeName).format(_weekdayReferenceDate(this));
  }
}
