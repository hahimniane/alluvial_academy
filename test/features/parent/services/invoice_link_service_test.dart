import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/parent/services/invoice_link_service.dart';

void main() {
  group('InvoiceLinkService', () {
    test('captures invoiceId from query parameters', () {
      InvoiceLinkService.initFromUri(
        Uri.parse('https://example.com/?invoiceId=inv_123'),
      );

      expect(InvoiceLinkService.consumePendingInvoiceId(), 'inv_123');
      expect(InvoiceLinkService.consumePendingInvoiceId(), isNull);
    });

    test('captures invoice id from invoice path', () {
      InvoiceLinkService.initFromUri(
        Uri.parse('https://example.com/invoices/inv_456'),
      );

      expect(InvoiceLinkService.consumePendingInvoiceId(), 'inv_456');
    });

    test('builds reusable invoice links with invoiceId query', () {
      final link = InvoiceLinkService.buildInvoiceLink('inv_789');

      expect(link, contains('invoiceId=inv_789'));
    });
  });
}
