class SubscriptionModel {
  final String id;
  final String userId;
  final int tier; // 0 = Free, 1 = Pro, 2 = Enterprise
  final int status; // 0 = Active, 1 = Expired, 2 = Cancelled
  final DateTime startDate;
  final DateTime endDate;
  final double price;

  SubscriptionModel({
    required this.id,
    required this.userId,
    required this.tier,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.price,
  });

  String get tierName {
    switch (tier) {
      case 1:
        return 'Pro Plan';
      case 2:
        return 'Enterprise';
      default:
        return 'Free Plan';
    }
  }

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      tier: json['tier'] is int ? json['tier'] : (json['tier'] == 'Pro' ? 1 : json['tier'] == 'Enterprise' ? 2 : 0),
      status: json['status'] is int ? json['status'] : (json['status'] == 'Active' ? 0 : 1),
      startDate: DateTime.tryParse(json['startDate'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate'] ?? '') ?? DateTime.now().add(const Duration(days: 30)),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
