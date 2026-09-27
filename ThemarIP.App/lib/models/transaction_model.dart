class TransactionModel {
  final String id;
  final String statementUploadId;
  final String userId;
  final DateTime transactionDate;
  final double amount;
  final String currency;
  final String category;
  final String description;
  final String? mccCode;

  TransactionModel({
    required this.id,
    required this.statementUploadId,
    required this.userId,
    required this.transactionDate,
    required this.amount,
    required this.currency,
    required this.category,
    required this.description,
    this.mccCode,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? '',
      statementUploadId: json['statementUploadId'] ?? '',
      userId: json['userId'] ?? '',
      transactionDate: DateTime.tryParse(json['transactionDate'] ?? '') ?? DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'OMR',
      category: json['category'] ?? 'General',
      description: json['description'] ?? '',
      mccCode: json['mccCode'],
    );
  }
}

class CategorySummaryModel {
  final String category;
  final double totalAmount;
  final int transactionCount;

  CategorySummaryModel({
    required this.category,
    required this.totalAmount,
    required this.transactionCount,
  });

  factory CategorySummaryModel.fromJson(Map<String, dynamic> json) {
    return CategorySummaryModel(
      category: json['category'] ?? 'General',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      transactionCount: json['transactionCount'] ?? 0,
    );
  }
}

class TransactionSummaryModel {
  final int totalTransactions;
  final double totalAmount;
  final String currency;
  final List<CategorySummaryModel> topCategories;

  TransactionSummaryModel({
    required this.totalTransactions,
    required this.totalAmount,
    required this.currency,
    required this.topCategories,
  });

  factory TransactionSummaryModel.fromJson(Map<String, dynamic> json) {
    var rawCategories = json['topCategories'] as List? ?? [];
    return TransactionSummaryModel(
      totalTransactions: json['totalTransactions'] ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'OMR',
      topCategories: rawCategories.map((c) => CategorySummaryModel.fromJson(c)).toList(),
    );
  }
}
