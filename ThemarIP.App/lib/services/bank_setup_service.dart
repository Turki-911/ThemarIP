import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Stores which banks the user chose to connect (per user, on device)
/// and decides whether the post-onboarding bank picker must be shown.
class BankSetupService {
  static const String _doneKeyPrefix = 'themarip_bank_setup_done_';
  static const String _banksKeyPrefix = 'themarip_selected_banks_';

  static Future<String> _userKey() async {
    final user = await AuthService.getUser();
    return (user?.id ?? user?.email ?? 'anonymous').toLowerCase();
  }

  /// True once the user has completed the bank picker on this device.
  static Future<bool> isSetupDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_doneKeyPrefix${await _userKey()}') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Bank codes the user selected (e.g. ['NBO', 'BANK_DHOFAR']).
  static Future<List<String>> getSelectedBanks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('$_banksKeyPrefix${await _userKey()}') ?? const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveSelection(List<String> bankCodes) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _userKey();
    await prefs.setStringList('$_banksKeyPrefix$key', bankCodes);
    await prefs.setBool('$_doneKeyPrefix$key', true);
  }

  /// Adds one bank to the stored selection (used by the in-app "Add bank" flow).
  static Future<void> addBank(String bankCode) async {
    final current = List<String>.from(await getSelectedBanks());
    if (!current.contains(bankCode)) {
      current.add(bankCode);
      await saveSelection(current);
    }
  }

  /// Removes (unsyncs) one bank from the stored selection.
  static Future<void> removeBank(String bankCode) async {
    final current = List<String>.from(await getSelectedBanks());
    current.removeWhere((c) => c.toUpperCase() == bankCode.toUpperCase());
    await saveSelection(current);
  }

  /// Route to the bank picker if not done yet, otherwise to the hierarchy page.
  static Future<void> routeAfterAuth(BuildContext context) async {
    final done = await isSetupDone();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(done ? '/categories' : '/bank-setup');
  }
}
