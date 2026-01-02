import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/core/models/invoice.dart';
import 'package:alluwalacademyadmin/core/services/invoice_pdf_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class InvoiceService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static CollectionReference get _invoices => _firestore.collection('invoices');

  static Stream<List<Invoice>> getParentInvoices(
    String parentId, {
    InvoiceStatus? status,
    int limit = 50,
  }) {
    Query query = _invoices.where('parent_id', isEqualTo: parentId);
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    query = query.orderBy('due_date', descending: true).limit(limit);

    return query.snapshots().map((snapshot) {
      final invoices = <Invoice>[];
      for (final doc in snapshot.docs) {
        try {
          invoices.add(Invoice.fromFirestore(doc));
        } catch (e) {
          AppLogger.error('InvoiceService: Failed to parse invoice ${doc.id}: $e');
        }
      }
      return invoices;
    }).handleError((error, stackTrace) {
      AppLogger.error('InvoiceService: getParentInvoices stream error: $error');
      AppLogger.error('InvoiceService: stack: $stackTrace');
    });
  }

  static Future<Invoice> getInvoice(String invoiceId) async {
    final doc = await _invoices.doc(invoiceId).get();
    if (!doc.exists) {
      throw Exception('Invoice not found');
    }
    return Invoice.fromFirestore(doc);
  }

  /// Generate and return PDF bytes for an invoice
  /// This replaces the old method that expected a stored PDF URL
  static Future<Uint8List> generateInvoicePDF(String invoiceId) async {
    final invoice = await getInvoice(invoiceId);
    return await InvoicePdfService.generateInvoicePDF(invoice);
  }

  /// Legacy method for backward compatibility
  /// Now generates PDF on-the-fly instead of expecting a stored URL
  @Deprecated('Use generateInvoicePDF instead. This method is kept for backward compatibility.')
  static Future<String> downloadInvoicePDF(String invoiceId) async {
    // This method is deprecated but kept for any code that might still call it
    // The actual PDF generation is now handled in InvoiceDetailScreen
    throw UnimplementedError(
      'downloadInvoicePDF is deprecated. Use InvoicePdfService.generateInvoicePDF() instead.',
    );
  }
}

