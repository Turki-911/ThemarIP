class StatementModel {
  final String id;
  final String userId;
  final String fileName;
  final int fileSize;
  final int status; // 0 = Pending, 1 = Processed, 2 = Failed
  final DateTime uploadedAt;
  final int transactionCount;
  final String? detectedBank;
  final int processingDurationMs;
  final String? validationWarnings;
  final String? logs;
  final String? accountNumber;
  final String? source;

  StatementModel({
    required this.id,
    required this.userId,
    required this.fileName,
    required this.fileSize,
    required this.status,
    required this.uploadedAt,
    required this.transactionCount,
    this.detectedBank,
    this.processingDurationMs = 0,
    this.validationWarnings,
    this.logs,
    this.accountNumber,
    this.source,
  });

  factory StatementModel.fromJson(Map<String, dynamic> json) {
    return StatementModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      fileName: json['fileName'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      status: json['status'] is int ? json['status'] : (json['status'] == 'Processed' ? 1 : 0),
      uploadedAt: DateTime.tryParse(json['uploadedAt'] ?? '') ?? DateTime.now(),
      transactionCount: json['transactionCount'] ?? 0,
      detectedBank: json['detectedBank'],
      processingDurationMs: json['processingDurationMs'] ?? 0,
      validationWarnings: json['validationWarnings'],
      logs: json['logs'],
      accountNumber: json['accountNumber'],
      source: json['source'] ?? 'Upload',
    );
  }

  String get statusName {
    switch (status) {
      case 1:
        return 'Completed';
      case 2:
        return 'Failed';
      default:
        return 'Processing';
    }
  }
}
