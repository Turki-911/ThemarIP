import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

/// Bridges the native Android SMS receiver (see SmsReceiver.kt) with the app.
///
/// The native side forwards bank SMS to the API on its own, even when the app is closed.
/// This class only (1) keeps it configured with the API URL + supported sender IDs
/// (managed from the admin portal) and (2) asks for the SMS permission once.
class SmsService {
  static const MethodChannel _channel = MethodChannel('themarip/sms');
  static const String askedKey = 'themarip_sms_permission_asked';

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Call after the user is signed in. Safe to call repeatedly; never throws.
  static Future<void> start(BuildContext context, {bool forceAsk = false}) async {
    if (!_supported) return;
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return;

      List<String> senders = [];
      try {
        senders = await _fetchSenders(token);
      } catch (e) {
        debugPrint('Fetch senders notice: $e');
      }
      if (senders.isEmpty) {
        senders = const ['bank muscat', 'BankMuscat', 'BM-ALERT', 'NBO', 'OmanArabBank', 'BankDhofar', 'SoharInt'];
      }

      await _channel.invokeMethod('configure', {
        'baseUrl': ApiConfig.baseUrl,
        'senders': senders,
      });

      if (await _channel.invokeMethod<bool>('hasPermission') == true) return;

      final prefs = await SharedPreferences.getInstance();
      if (!forceAsk && prefs.getBool(askedKey) == true) return; // asked once; respect the answer
      if (!context.mounted) return;

      final agree = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.sms_outlined, color: Color(0xFF00E5FF)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Detect Bank SMS Automatically?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Allow ThemarIP to receive bank SMS so your purchases and credits '
            'appear instantly. Only messages from your verified bank senders are processed; '
            'all personal messages are ignored.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF0A0E1A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Allow & Activate', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      await prefs.setBool(askedKey, true);
      if (agree == true) {
        await _channel.invokeMethod<bool>('requestPermission');
      }
    } catch (e) {
      debugPrint('SmsService.start skipped: $e');
    }
  }

  /// Forget cached config and any queued, unsent messages (call on sign-out).
  static Future<void> clear() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('clear');
    } catch (_) {}
  }

  static Future<List<String>> _fetchSenders(String token) async {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ));
    final res = await dio.get('/sms/senders');
    return (res.data as List).map((e) => e.toString()).toList();
  }
}
