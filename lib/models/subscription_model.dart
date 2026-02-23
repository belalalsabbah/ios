enum SubscriptionStatus { active, expired, suspended }

class Subscription {
  final String name;
  final DateTime expiry;
  final SubscriptionStatus status;

  Subscription({
    required this.name,
    required this.expiry,
    required this.status,
  });
}
