import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:alluwalacademyadmin/core/services/user_role_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/features/parent/models/invoice.dart';
import 'package:alluwalacademyadmin/features/parent/models/payment.dart';

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

  /// Real-time payments for an invoice. Constrains by `parent_id` for non-admins so
  /// Firestore rules (`payments`: read if `parent_id == request.auth.uid || isAdmin()`)
  /// accept the query. Admins query by `invoice_id` only.
  static Stream<QuerySnapshot<Object?>> watchPaymentsForInvoiceSnapshots(Invoice invoice) async* {
    final uid = UserRoleService.getCurrentUserId() ?? FirebaseAuth.instance.currentUser?.uid;
    final isAdmin = await UserRoleService.isAdmin();

    if (isAdmin) {
      yield* _payments.where('invoice_id', isEqualTo: invoice.id).snapshots();
      return;
    }
    if (uid == null) {
      return;
    }
    yield* _payments
        .where('invoice_id', isEqualTo: invoice.id)
        .where('parent_id', isEqualTo: uid)
        .snapshots();
  }
}

