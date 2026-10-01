class BmpfHeader {
  final String accountNumber;
  final String statementCycle;
  final String? accountHolder;
  final String bankCode;
  final String bankName;

  BmpfHeader({
    required this.accountNumber,
    required this.statementCycle,
    this.accountHolder,
    this.bankCode = 'BANK_MUSCAT',
    this.bankName = 'Bank Muscat',
  });

  factory BmpfHeader.fromJson(Map<String, dynamic> json) {
    return BmpfHeader(
      accountNumber: json['accountNumber']?.toString() ?? '--',
      statementCycle: json['statementCycle']?.toString() ?? '--',
      accountHolder: json['accountHolder']?.toString(),
      bankCode: json['bankCode']?.toString() ?? 'BANK_MUSCAT',
      bankName: json['bankName']?.toString() ?? 'Bank Muscat',
    );
  }
}

class BmpfTransaction {
  final String narration;
  final double amount;
  final String direction; // DEBIT or CREDIT
  final String currency;
  final double? balance;
  final String? postDate;
  final String? valueDate;
  final bool isBalanceValid;
  final bool isDuplicate;
  final String category;
  final String? subcategory;
  final String? matchedMerchant;
  final int confidence;
  final String? validationMessage;
  final String? extractionStatus;

  BmpfTransaction({
    required this.narration,
    required this.amount,
    required this.direction,
    this.currency = 'OMR',
    this.balance,
    this.postDate,
    this.valueDate,
    this.isBalanceValid = true,
    this.isDuplicate = false,
    this.category = 'General',
    this.subcategory,
    this.matchedMerchant,
    this.confidence = 100,
    this.validationMessage,
    this.extractionStatus,
  });

  factory BmpfTransaction.fromJson(Map<String, dynamic> json) {
    final debit = (json['debit'] as num?)?.toDouble();
    final credit = (json['credit'] as num?)?.toDouble();
    final isCredit = credit != null && credit > 0;
    final amt = (json['amount'] as num?)?.toDouble() ?? (isCredit ? credit : (debit ?? 0.0));
    final dir = (json['direction']?.toString() ?? (isCredit ? 'CREDIT' : 'DEBIT')).toUpperCase();

    return BmpfTransaction(
      narration: json['narration']?.toString() ?? json['description']?.toString() ?? 'Transaction',
      amount: amt,
      direction: dir,
      currency: json['currency']?.toString() ?? 'OMR',
      balance: (json['balance'] as num?)?.toDouble() ?? (json['balanceAfter'] as num?)?.toDouble(),
      postDate: json['postDate']?.toString() ?? json['transactionDate']?.toString(),
      valueDate: json['valueDate']?.toString(),
      isBalanceValid: json['isBalanceValid'] == true || json['isBalanceValid'] == null,
      isDuplicate: json['isDuplicate'] == true,
      category: json['category']?.toString() ?? 'General',
      subcategory: json['subcategory']?.toString(),
      matchedMerchant: json['matchedMerchant']?.toString(),
      confidence: (json['confidence'] as num?)?.toInt() ?? 100,
      validationMessage: json['validationMessage']?.toString(),
      extractionStatus: json['extractionStatus']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'narration': narration,
      'amount': amount,
      'direction': direction,
      'currency': currency,
      'balance': balance,
      'balanceAfter': balance,
      'postDate': postDate,
      'valueDate': valueDate,
      'transactionDate': postDate,
      'isBalanceValid': isBalanceValid,
      'isDuplicate': isDuplicate,
      'category': category,
      'subcategory': subcategory,
      'matchedMerchant': matchedMerchant,
      'confidence': confidence,
      'validationMessage': validationMessage,
      'extractionStatus': extractionStatus,
    };
  }
}

class BmpfParseResult {
  final BmpfHeader header;
  final List<BmpfTransaction> transactions;
  final int extractionConfidence;
  final String reconciliationStatus;
  final String bankCode;
  final String bankName;
  final Map<String, dynamic> rawJson;

  BmpfParseResult({
    required this.header,
    required this.transactions,
    required this.extractionConfidence,
    required this.reconciliationStatus,
    this.bankCode = 'BANK_MUSCAT',
    this.bankName = 'Bank Muscat',
    required this.rawJson,
  });

  factory BmpfParseResult.fromJson(Map<String, dynamic> json) {
    final headerObj = json['header'] is Map ? json['header'] as Map<String, dynamic> : <String, dynamic>{};
    final txList = (json['transactions'] as List? ?? [])
        .map((e) => BmpfTransaction.fromJson(e as Map<String, dynamic>))
        .toList();

    final bCode = json['bankCode']?.toString() ?? headerObj['bankCode']?.toString() ?? 'BANK_MUSCAT';
    final bName = json['bankName']?.toString() ?? headerObj['bankName']?.toString() ?? 'Bank Muscat';

    return BmpfParseResult(
      header: BmpfHeader.fromJson(headerObj),
      transactions: txList,
      extractionConfidence: (json['extractionConfidence'] as num?)?.toInt() ?? 100,
      reconciliationStatus: json['reconciliationStatus']?.toString() ?? 'PASS',
      bankCode: bCode,
      bankName: bName,
      rawJson: json,
    );
  }
}

class BmpfCategoryChild {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  final int displayOrder;

  BmpfCategoryChild({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.displayOrder = 1,
  });

  factory BmpfCategoryChild.fromJson(Map<String, dynamic> json) {
    return BmpfCategoryChild(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Subcategory',
      icon: json['icon']?.toString(),
      color: json['color']?.toString(),
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 1,
    );
  }
}

class BmpfCategoryNode {
  final String id;
  final String name;
  final String icon;
  final String color;
  final int displayOrder;
  final bool isEnabled;
  final List<BmpfCategoryChild> children;
  double totalAmount;
  int txnCount;
  List<BmpfTransaction> transactions;

  BmpfCategoryNode({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.displayOrder,
    required this.isEnabled,
    required this.children,
    this.totalAmount = 0.0,
    this.txnCount = 0,
    List<BmpfTransaction>? transactions,
  }) : transactions = transactions ?? [];

  factory BmpfCategoryNode.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'] as List? ?? json['subcategories'] as List? ?? [];
    return BmpfCategoryNode(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Category',
      icon: json['icon']?.toString() ?? 'tag',
      color: json['color']?.toString() ?? '#7C3AED',
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 1,
      isEnabled: json['isEnabled'] != false,
      children: rawChildren.map((e) => BmpfCategoryChild.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
