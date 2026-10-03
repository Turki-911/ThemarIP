import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  // Default Mac LAN IP address (detected on current Wi-Fi)
  static const String defaultLanHost = '192.168.0.201';
  static const String livePublicApiUrl =
      'https://public-applications-hartford-title.trycloudflare.com/api';
  static String? _customHost;

  static const String _prefKeyHost = 'themarip_custom_api_host';

  /// Load any previously configured custom IP from local device storage
  static Future<void> loadSavedHost() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (kIsWeb) {
        // On web, always clear any saved host so it routes via browser origin
        await prefs.remove(_prefKeyHost);
        _customHost = null;
        return;
      }
      final saved = prefs.getString(_prefKeyHost);
      if (saved != null && saved.trim().isNotEmpty) {
        final val = saved.trim();
        // Purge old expired quick tunnels or old hotspot IP
        if (val.contains('then-eyes-comm-dicke') ||
            val.contains('brick-concerned') ||
            val == '172.20.10.5') {
          await prefs.remove(_prefKeyHost);
          _customHost = null;
        } else {
          _customHost = val;
        }
      }
    } catch (_) {}
  }

  /// Update and persist the backend server host/IP
  static Future<void> setCustomHost(String hostOrIp) async {
    final clean = hostOrIp.trim();
    if (clean.isEmpty) {
      _customHost = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefKeyHost);
      } catch (_) {}
    } else {
      _customHost = clean;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKeyHost, clean);
      } catch (_) {}
    }
  }

  /// Returns the current active host (hostname or IP)
  static String get activeHost {
    if (_customHost != null && _customHost!.isNotEmpty) {
      return _customHost!;
    }
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && !origin.startsWith('http://localhost') && !origin.startsWith('http://127.0.0.1')) {
        return origin;
      }
      return 'localhost';
    }
    // Default to the live public HTTPS backend for all mobile devices (iOS & Android)
    // so testers, family, and friends connect seamlessly over public internet (4G/5G/Wi-Fi).
    return livePublicApiUrl;
  }

  /// Returns the full base API URL (e.g. http://172.20.10.5:5267/api)
  static String get baseUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && !origin.startsWith('http://localhost') && !origin.startsWith('http://127.0.0.1')) {
        return '$origin/api';
      }
      return 'http://localhost:5267/api';
    }

    if (_customHost != null && _customHost!.isNotEmpty) {
      final host = _customHost!;
      if (host.startsWith('http://') || host.startsWith('https://')) {
        return host.endsWith('/api') ? host : '$host/api';
      }
      return 'http://$host:5267/api';
    }

    final host = activeHost;
    if (host.startsWith('http://') || host.startsWith('https://')) {
      return host.endsWith('/api') ? host : '$host/api';
    }
    return 'http://$host:5267/api';
  }

  // Endpoints
  static const String health = '/health';
  static const String register = '/auth/register';
  static const String login = '/auth/login';

  static const String statements = '/statements';
  static const String statementsUpload = '/statements/upload';
  static const String statementsParse = '/statements/parse';
  static const String statementsConfirm = '/statements/confirm';
  static const String parseNotification = '/statements/parse-notification';
  static const String confirmNotification = '/statements/confirm-notification';
  static const String pullMailboxEmails = '/statements/pull-mailbox-emails';
  static const String categoriesHierarchy = '/statements/categories-hierarchy';
  static const String merchants = '/statements/merchants';
  static const String categoryRules = '/statements/category-rules';
  static const String categoryStats = '/statements/category-stats';
  static const String userBanks = '/statements/user-banks';

  static const String transactions = '/statements/transactions';
  static const String transactionsSummary = '/transactions/summary';
  static const String transactionsCategories = '/transactions/categories';

  static const String currentSubscription = '/subscriptions/current';
  static const String setAccountNumber = '/auth/set-account-number';
  static const String fetchNboStatement = '/statements/fetch-nbo';
}
