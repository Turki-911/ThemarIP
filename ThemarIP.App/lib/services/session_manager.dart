import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';

/// Global navigator key allowing programmatic navigation from services
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Persistent Session Manager for ThemarIP.
/// Keeps the user logged in forever (no idle auto-logout) so background SMS listening
/// and financial tracking never stop unless the user explicitly signs out.
class SessionManager with WidgetsBindingObserver {
  SessionManager._internal();
  static final SessionManager instance = SessionManager._internal();

  bool _isLoggingOut = false;
  bool _isInitialized = false;

  /// Initialize lifecycle observation (iOS keyboard/focus safety only; never logs out on idle)
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Dispose lifecycle observation
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isInitialized = false;
  }

  /// No-op: user sessions are permanent and never expire on inactivity
  void recordUserInteraction() {}

  /// No-op: user sessions are permanent and never expire on inactivity
  void resetTimer() {}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Unfocus any active keyboard/text field to avoid iOS focusItemsInRect issues
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  /// Explicit logout helper (only when explicitly requested)
  Future<void> forceLogout({String reason = 'Signed out.'}) async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      await AuthService.clearSession(keepBackgroundSms: true);

      final state = navigatorKey.currentState;
      if (state != null) {
        state.popUntil((route) => route.isFirst);
        state.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
          arguments: reason,
        );
      }
    } catch (e) {
      debugPrint('Error during forceLogout: $e');
    } finally {
      _isLoggingOut = false;
    }
  }
}

/// Wrapper retained for widget tree compatibility; does not expire user sessions.
class SessionTimeoutListener extends StatelessWidget {
  final Widget child;
  const SessionTimeoutListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
