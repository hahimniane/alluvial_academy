import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/core/models/payment.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class PaymentService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static CollectionReference get _payments => _firestore.collection('payments');

  static Stream<List<Payment>> getPaymentHistory(
    String parentId, {
    int limit = 50,
  }) {
    final query = _payments
        .where('parent_id', isEqualTo: parentId)
        .orderBy('created_at', descending: true)
        .limit(limit);

    return query.snapshots().map((snapshot) {
      final payments = <Payment>[];
      for (final doc in snapshot.docs) {
        try {
          payments.add(Payment.fromFirestore(doc));
        } catch (e) {
          AppLogger.error('PaymentService: Failed to parse payment ${doc.id}: $e');
        }
      }
      return payments;
    }).handleError((error, stackTrace) {
      AppLogger.error('PaymentService: getPaymentHistory stream error: $error');
      AppLogger.error('PaymentService: stack: $stackTrace');
    });
  }

  static Future<Payment> getPaymentStatus(String paymentId) async {
    final doc = await _payments.doc(paymentId).get();
    if (!doc.exists) {
      throw Exception('Payment not found');
    }
    return Payment.fromFirestore(doc);
  }
}

