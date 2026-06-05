import 'package:flutter/foundation.dart';

class InvoiceLinkService {
  static String? _pendingInvoiceId;

  static void initFromUri(Uri uri) {
    final invoiceId = _invoiceIdFromUri(uri);
    if (invoiceId != null) {
      _pendingInvoiceId = invoiceId;
    }
  }

  static String? consumePendingInvoiceId() {
    final invoiceId = _pendingInvoiceId;
    _pendingInvoiceId = null;
    return invoiceId;
  }

  static String buildInvoiceLink(String invoiceId) {
    final trimmed = invoiceId.trim();
    if (trimmed.isEmpty) return '';

    final base =
        kIsWeb ? Uri.base : Uri.parse('https://alluwaleducationhub.org/');
    return Uri(
      scheme: base.scheme.isEmpty ? 'https' : base.scheme,
      host: base.host.isEmpty ? 'alluwaleducationhub.org' : base.host,
      port: base.hasPort ? base.port : null,
      path: base.path == '/' ? '' : base.path,
      queryParameters: {'invoiceId': trimmed},
    ).toString();
  }

  static String? _invoiceIdFromUri(Uri uri) {
    final queryInvoiceId =
        uri.queryParameters['invoiceId'] ?? uri.queryParameters['invoice_id'];
    final trimmedQuery = queryInvoiceId?.trim();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      return trimmedQuery;
    }

    final segments = uri.pathSegments;
    final invoiceIndex = segments.indexWhere(
      (segment) =>
          segment.toLowerCase() == 'invoice' ||
          segment.toLowerCase() == 'invoices',
    );
    if (invoiceIndex >= 0 && invoiceIndex + 1 < segments.length) {
      final pathInvoiceId = segments[invoiceIndex + 1].trim();
      if (pathInvoiceId.isNotEmpty) return pathInvoiceId;
    }
    return null;
  }
}
