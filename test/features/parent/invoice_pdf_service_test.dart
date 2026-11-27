// Invoice / receipt PDF (phone app). Same rules as the emailed copy and the
// parent web download:
// - paid in full → "Receipt" + PAID; otherwise "Invoice" with Due, Partially
//   paid, Overdue or Cancelled;
// - long item lists flow onto more pages;
// - no "Received by" / signature block.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/parent/models/invoice.dart';
import 'package:alluwalacademyadmin/features/parent/services/invoice_pdf_service.dart';

Invoice _invoice(Map<String, dynamic> over) => Invoice.fromMap({
      'invoice_number': 'INV-1',
      'parent_id': 'p',
      'student_id': 's',
      'status': 'pending',
      'total_amount': 200,
      'paid_amount': 0,
      'currency': 'USD',
      'issued_date': DateTime(2026, 11, 1),
      'due_date': DateTime(2026, 11, 26),
      'items': [
        {'description': 'Tuition', 'quantity': 1, 'unit_price': 200, 'total': 200}
      ],
      ...over,
    }, id: 'doc1');

void main() {
  final now = DateTime(2026, 11, 19, 12);

  test('status follows the balance, the due date and cancellation', () {
    expect(InvoicePdfSummary.of(_invoice({}), now: now).status, InvoicePdfStatus.due);
    expect(InvoicePdfSummary.of(_invoice({'paid_amount': 50}), now: now).status,
        InvoicePdfStatus.partial);
    expect(
        InvoicePdfSummary.of(_invoice({'paid_amount': 50, 'due_date': DateTime(2026, 11, 10)}),
                now: now)
            .status,
        InvoicePdfStatus.overdue);
    expect(InvoicePdfSummary.of(_invoice({'status': 'cancelled'}), now: now).status,
        InvoicePdfStatus.cancelled);
    final paid = InvoicePdfSummary.of(_invoice({'paid_amount': 200}), now: now);
    expect(paid.status, InvoicePdfStatus.paid);
    expect(paid.isReceipt, isTrue);
    expect(paid.remaining, 0);
  });

  test('every state renders, long lists use more pages', () async {
    final out = Platform.environment['RECEIPT_PREVIEW_DIR'];
    final samples = {
      'paid': _invoice({
        'status': 'paid', 'total_amount': 1, 'paid_amount': 1,
        'last_payment_at': DateTime.utc(2026, 11, 19, 3, 33),
        'items': [
          {'description': 'Payment test', 'quantity': 1, 'unit_price': 1, 'total': 1}
        ],
      }),
      'overdue_partial': _invoice({'paid_amount': 100, 'total_amount': 350, 'due_date': DateTime(2026, 11, 10)}),
      'cancelled': _invoice({'status': 'cancelled', 'items': []}),
      'long': _invoice({
        'total_amount': 720,
        'items': List.generate(40, (i) => {
              'description': 'Class on November ${i % 30 + 1} - Quran with Ustadh ${i.isOdd ? 'Ibrahim' : 'Moussa'}',
              'quantity': 1, 'unit_price': 18, 'total': 18,
            }),
      }),
    };
    for (final entry in samples.entries) {
      final bytes = await InvoicePdfService.buildDocument(entry.value,
              parentName: 'Aïcha Diallo', studentName: 'Ibrahima Diakité', now: now)
          .save();
      final text = String.fromCharCodes(bytes);
      expect(text.startsWith('%PDF'), isTrue);
      final pages = RegExp(r'/Type\s*/Page\b').allMatches(text).length;
      expect(pages, entry.key == 'long' ? greaterThan(1) : 1, reason: entry.key);
      if (out != null) File('$out/flutter_${entry.key}.pdf').writeAsBytesSync(bytes);
    }
  });

  test('note text matches the other two copies', () {
    expect(InvoicePdfService.noteText(InvoicePdfStatus.paid),
        'Thank you for your payment. Keep this receipt for your records.');
    expect(InvoicePdfService.noteText(InvoicePdfStatus.due),
        'Pay online from your parent account at alluwaleducationhub.org, or with the Pay link in your invoice email.');
  });
}
