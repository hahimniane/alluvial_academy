import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/audit/models/teacher_audit_full.dart';

SubjectPayment pay(String name, double hours, double gross) => SubjectPayment(
      subjectName: name,
      hoursTaught: hours,
      hourlyRate: hours > 0 ? gross / hours : 0,
      grossAmount: gross,
      penalties: 0,
      bonuses: 0,
      netAmount: gross,
    );

void main() {
  test('a blank subject is saved under Other, never as an empty key', () {
    final summary = PaymentSummary(
      paymentsBySubject: {'': pay('', 1, 4), 'Other': pay('Other', 2, 8), 'Quran': pay('Quran', 3, 12)},
      totalGrossPayment: 24,
      totalPenalties: 0,
      totalBonuses: 0,
      totalNetPayment: 24,
      adminAdjustment: 0,
      adjustmentReason: '',
      adminId: '',
    );
    final stored = summary.toMap()['paymentsBySubject'] as Map<String, dynamic>;
    expect(stored.keys.toSet(), {'Other', 'Quran'});
    final other = stored['Other'] as Map<String, dynamic>;
    expect(other['hoursTaught'], 3);
    expect(other['grossAmount'], 12);
    expect(other['netAmount'], 12);
  });
}
