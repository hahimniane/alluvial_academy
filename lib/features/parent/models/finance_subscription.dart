import 'package:cloud_firestore/cloud_firestore.dart';

/// How often a recurring subscription bills.
enum SubscriptionFrequency { weekly, monthly, quarterly, yearly }

/// Lifecycle state of a subscription.
enum SubscriptionStatus { active, paused, cancelled }

extension SubscriptionFrequencyX on SubscriptionFrequency {
  String get key => switch (this) {
        SubscriptionFrequency.weekly => 'weekly',
        SubscriptionFrequency.monthly => 'monthly',
        SubscriptionFrequency.quarterly => 'quarterly',
        SubscriptionFrequency.yearly => 'yearly',
      };

  /// Multiplier that converts one billing amount into a monthly-equivalent cost,
  /// so subscriptions on different cadences can be compared and summed.
  double get monthlyFactor => switch (this) {
        SubscriptionFrequency.weekly => 52 / 12,
        SubscriptionFrequency.monthly => 1,
        SubscriptionFrequency.quarterly => 1 / 3,
        SubscriptionFrequency.yearly => 1 / 12,
      };

  static SubscriptionFrequency fromKey(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'weekly':
        return SubscriptionFrequency.weekly;
      case 'quarterly':
        return SubscriptionFrequency.quarterly;
      case 'yearly':
        return SubscriptionFrequency.yearly;
      case 'monthly':
      default:
        return SubscriptionFrequency.monthly;
    }
  }
}

extension SubscriptionStatusX on SubscriptionStatus {
  String get key => switch (this) {
        SubscriptionStatus.active => 'active',
        SubscriptionStatus.paused => 'paused',
        SubscriptionStatus.cancelled => 'cancelled',
      };

  static SubscriptionStatus fromKey(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'paused':
        return SubscriptionStatus.paused;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      case 'active':
      default:
        return SubscriptionStatus.active;
    }
  }
}

/// A recurring, subscription-style expense (Zoom, hosting, domains, software,
/// marketing tools, etc.). Stored in the `finance_subscriptions` collection.
class FinanceSubscription {
  final String id;
  final String name;
  final String vendor;

  /// Reuses the same expense category keys as manual expenses so subscription
  /// spend rolls up under the same groups on the overview.
  final String category;
  final double amount;
  final SubscriptionFrequency frequency;
  final DateTime? nextPaymentDate;
  final SubscriptionStatus status;
  final String notes;

  const FinanceSubscription({
    required this.id,
    required this.name,
    required this.vendor,
    required this.category,
    required this.amount,
    required this.frequency,
    required this.nextPaymentDate,
    required this.status,
    required this.notes,
  });

  /// Cost normalized to a single month, regardless of billing cadence.
  double get monthlyEquivalent => amount * frequency.monthlyFactor;

  /// Whether the next payment is in the past (needs attention).
  bool get isOverdue {
    final due = nextPaymentDate;
    if (due == null || status != SubscriptionStatus.active) return false;
    final today = DateTime.now();
    return due.isBefore(DateTime(today.year, today.month, today.day));
  }

  factory FinanceSubscription.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final rawNext = data['next_payment_date'];
    return FinanceSubscription(
      id: doc.id,
      name: (data['name'] ?? '').toString().trim(),
      vendor: (data['vendor'] ?? '').toString().trim(),
      category: (data['category'] ?? 'subscription').toString().trim(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      frequency: SubscriptionFrequencyX.fromKey(data['billing_frequency']?.toString()),
      nextPaymentDate: rawNext is Timestamp ? rawNext.toDate() : null,
      status: SubscriptionStatusX.fromKey(data['status']?.toString()),
      notes: (data['notes'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'vendor': vendor,
        'category': category,
        'amount': amount,
        'currency': 'USD',
        'billing_frequency': frequency.key,
        'monthly_equivalent': monthlyEquivalent,
        if (nextPaymentDate != null)
          'next_payment_date': Timestamp.fromDate(nextPaymentDate!),
        'status': status.key,
        'notes': notes,
      };
}
