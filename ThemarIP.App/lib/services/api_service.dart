import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import '../models/statement_model.dart';
import '../models/transaction_model.dart';
import '../models/subscription_model.dart';
import '../utils/web_file_picker.dart';
import 'auth_service.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    // Add Auth & Dynamic BaseUrl Interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.baseUrl = ApiConfig.baseUrl;
          final token = await AuthService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            await AuthService.clearSession();
          }
          return handler.next(error);
        },
      ),
    );
  }

  // 1. Auth Services
  Future<UserModel> login(String email, String password) async {
    final response = await _dio.post(
      ApiConfig.login,
      data: {'email': email, 'password': password},
    );
    final user = UserModel.fromJson(response.data);
    await AuthService.saveSession(user);
    return user;
  }

  Future<UserModel> register(String email, String password, String fullName) async {
    final response = await _dio.post(
      ApiConfig.register,
      data: {
        'email': email,
        'password': password,
        'fullName': fullName,
      },
    );
    final user = UserModel.fromJson(response.data);
    await AuthService.saveSession(user);
    return user;
  }

  // 2. Statements Services
  Future<StatementModel> uploadStatement(String fileName, int fileSize) async {
    final response = await _dio.post(
      ApiConfig.statementsUpload,
      data: {
        'fileName': fileName,
        'fileSize': fileSize,
      },
    );
    return StatementModel.fromJson(response.data);
  }

  Future<StatementModel> uploadStatementAttachment(PickedAttachment pickedFile) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        pickedFile.bytes,
        filename: pickedFile.name,
      ),
    });

    final response = await _dio.post(
      ApiConfig.statementsUpload,
      data: formData,
    );
    return StatementModel.fromJson(response.data);
  }

  Future<List<StatementModel>> getStatements() async {
    final response = await _dio.get(ApiConfig.statements);
    final rawList = response.data as List? ?? [];
    return rawList.map((item) => StatementModel.fromJson(item)).toList();
  }

  // 3. Transactions Services
  Future<List<TransactionModel>> getTransactions() async {
    final response = await _dio.get(ApiConfig.transactions);
    final rawList = response.data as List? ?? [];
    return rawList.map((item) => TransactionModel.fromJson(item)).toList();
  }

  Future<TransactionSummaryModel> getTransactionSummary() async {
    final response = await _dio.get(ApiConfig.transactionsSummary);
    return TransactionSummaryModel.fromJson(response.data);
  }

  Future<List<CategorySummaryModel>> getTransactionCategories() async {
    final response = await _dio.get(ApiConfig.transactionsCategories);
    final rawList = response.data as List? ?? [];
    return rawList.map((item) => CategorySummaryModel.fromJson(item)).toList();
  }

  // 4. Subscription Services
  Future<SubscriptionModel?> getCurrentSubscription() async {
    try {
      final response = await _dio.get(ApiConfig.currentSubscription);
      return SubscriptionModel.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  // Set user's bank account number
  Future<UserModel> setAccountNumber(String accountNumber) async {
    final response = await _dio.post(
      ApiConfig.setAccountNumber,
      data: {'accountNumber': accountNumber},
    );
    final user = UserModel.fromJson(response.data);
    await AuthService.saveSession(user);
    return user;
  }

  // Fetch transactions from NBO Gateway API
  Future<StatementModel> fetchNboStatement(String accountNumber, String fromDate, String toDate) async {
    final response = await _dio.post(
      ApiConfig.fetchNboStatement,
      data: {
        'accountNumber': accountNumber,
        'fromDate': fromDate,
        'toDate': toDate,
      },
    );
    return StatementModel.fromJson(response.data);
  }

  // ============================================================
  // 5. BMPF ENGINE SERVICES
  // ============================================================
  Future<Map<String, dynamic>> parsePdfStatement(
    List<int> bytes,
    String fileName, {
    String bankCode = 'BANK_MUSCAT',
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      'bankCode': bankCode,
    });
    final response = await _dio.post(
      '${ApiConfig.statementsParse}?bankCode=$bankCode',
      data: formData,
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {};
  }

  Future<bool> confirmPdfImport(Map<String, dynamic> parseResult, {String? userId}) async {
    final payload = Map<String, dynamic>.from(parseResult);
    if (userId != null && userId.isNotEmpty) {
      payload['userId'] = userId;
    }
    final response = await _dio.post(
      ApiConfig.statementsConfirm,
      data: payload,
    );
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> parseNotification({
    required String sourceType,
    required String rawMessage,
    String? emailSender,
    String? emailSubject,
    bool isHtml = false,
    String? userId,
  }) async {
    final response = await _dio.post(
      ApiConfig.parseNotification,
      data: {
        'sourceType': sourceType,
        'rawMessage': rawMessage,
        'emailSender': emailSender,
        'emailSubject': emailSubject,
        'isHtml': isHtml,
        'userId': userId,
      },
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {};
  }

  Future<bool> confirmNotification(Map<String, dynamic> transactionData, {String? userId}) async {
    final response = await _dio.post(
      ApiConfig.confirmNotification,
      data: {
        'transaction': transactionData,
        'userId': userId,
      },
    );
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> pullMailboxEmails({
    required String emailSender,
    required String emailSubject,
    String provider = 'OUTLOOK',
    String? username,
    String? password,
    bool autoFeedDb = false,
    String? userId,
  }) async {
    final response = await _dio.post(
      ApiConfig.pullMailboxEmails,
      data: {
        'emailSender': emailSender,
        'emailSubject': emailSubject,
        'provider': provider,
        'username': username,
        'password': password,
        'autoFeedDb': autoFeedDb,
        'userId': userId,
      },
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {};
  }

  Future<List<dynamic>> getCategoryHierarchy() async {
    final response = await _dio.get(ApiConfig.categoriesHierarchy);
    if (response.data is List) {
      return response.data as List;
    }
    return [];
  }

  Future<List<dynamic>> getCategoryStats({String? userId, String? bankCode}) async {
    try {
      final params = <String>[];
      if (userId != null && userId.isNotEmpty) params.add('userId=$userId');
      if (bankCode != null && bankCode.isNotEmpty && bankCode != 'ALL') params.add('bankCode=$bankCode');
      final query = params.isNotEmpty ? '?${params.join('&')}' : '';
      final url = '${ApiConfig.categoryStats}$query';
      final response = await _dio.get(url);
      if (response.data is List) {
        return response.data as List;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getUserBanks({String? userId}) async {
    try {
      final url = userId != null && userId.isNotEmpty
          ? '${ApiConfig.userBanks}?userId=$userId'
          : ApiConfig.userBanks;
      final response = await _dio.get(url);
      if (response.data is List) {
        return response.data as List;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<int> getDbTransactionCount({String? userId}) async {
    try {
      final url = userId != null && userId.isNotEmpty 
          ? '${ApiConfig.transactions}?userId=$userId' 
          : ApiConfig.transactions;
      final response = await _dio.get(url);
      if (response.data is List) {
        return (response.data as List).length;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  // 3. Infrastructure Health & Connectivity Check
  Future<ApiHealthResult> checkHealth() async {
    final sw = Stopwatch()..start();
    final healthUrl = ApiConfig.health;
    try {
      final response = await _dio.get(
        healthUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
        ),
      );
      sw.stop();
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final dbData = data['database'] as Map<String, dynamic>? ?? {};
        return ApiHealthResult(
          isHealthy: true,
          latencyMs: sw.elapsedMilliseconds,
          status: data['status']?.toString() ?? 'Healthy',
          service: data['service']?.toString() ?? 'ThemarIP.API',
          version: data['version']?.toString() ?? '2.4.0',
          dbProvider: dbData['provider']?.toString() ?? 'SQLite',
          dbConnected: dbData['connected'] == true,
          dbCategories: (dbData['categories'] as num?)?.toInt() ?? 0,
          dbTransactions: (dbData['transactions'] as num?)?.toInt() ?? 0,
          endpoint: '${_dio.options.baseUrl}$healthUrl',
        );
      }
    } catch (_) {
      // Fallback check to /statements/categories-hierarchy
      try {
        final fallbackRes = await _dio.get(
          ApiConfig.categoriesHierarchy,
          options: Options(
            receiveTimeout: const Duration(seconds: 3),
            sendTimeout: const Duration(seconds: 3),
          ),
        );
        sw.stop();
        if (fallbackRes.statusCode == 200) {
          final count =
              fallbackRes.data is List ? (fallbackRes.data as List).length : 0;
          return ApiHealthResult(
            isHealthy: true,
            latencyMs: sw.elapsedMilliseconds,
            status: 'Healthy',
            service: 'ThemarIP.API',
            version: '2.4.0',
            dbProvider: 'SQLite',
            dbConnected: true,
            dbCategories: count,
            dbTransactions: 0,
            endpoint: '${_dio.options.baseUrl}${ApiConfig.categoriesHierarchy}',
          );
        }
      } catch (fallbackError) {
        sw.stop();
        return ApiHealthResult(
          isHealthy: false,
          latencyMs: sw.elapsedMilliseconds,
          status: 'Offline',
          errorMessage: _formatErrorMessage(fallbackError),
          endpoint: '${_dio.options.baseUrl}$healthUrl',
        );
      }
    }
    sw.stop();
    return ApiHealthResult(
      isHealthy: false,
      latencyMs: sw.elapsedMilliseconds,
      status: 'Offline',
      errorMessage:
          'Could not connect to ThemarIP backend on ${_dio.options.baseUrl}',
      endpoint: '${_dio.options.baseUrl}$healthUrl',
    );
  }

  String _formatErrorMessage(dynamic error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out. Check backend port 5267.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Connection refused. Is the .NET API running on port 5267?';
      }
      return error.message ?? 'Network error connecting to API';
    }
    return error.toString();
  }
}

class ApiHealthResult {
  final bool isHealthy;
  final int latencyMs;
  final String status;
  final String service;
  final String version;
  final String dbProvider;
  final bool dbConnected;
  final int dbCategories;
  final int dbTransactions;
  final String? errorMessage;
  final String endpoint;

  ApiHealthResult({
    required this.isHealthy,
    required this.latencyMs,
    required this.status,
    this.service = 'ThemarIP.API',
    this.version = '2.4.0',
    this.dbProvider = 'SQLite',
    this.dbConnected = false,
    this.dbCategories = 0,
    this.dbTransactions = 0,
    this.errorMessage,
    required this.endpoint,
  });
}

