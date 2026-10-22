import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_month_summary.dart';

/// Reads one month of finance totals from the `getFinanceMonthSummary`
/// callable. Screens take this class so tests can swap it out.
class FinanceSummaryService {
  FinanceSummaryService({FirebaseFunctions? functions})
      : _functionsOverride = functions;

  final FirebaseFunctions? _functionsOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  Future<FinanceMonthSummary> getMonthSummary(String month) async {
    final result = await _functions
        .httpsCallable('getFinanceMonthSummary')
        .call<Map<dynamic, dynamic>>({'month': month});
    return FinanceMonthSummary.fromMap(result.data);
  }
}
