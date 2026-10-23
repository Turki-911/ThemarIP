import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';

/// Global navigator key allowing programmatic navigation from services and timers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Centralized Session & Inactivity Manager for ThemarIP.
/// Enforces mandatory security policy: auto-logout after 15 minutes of inactivity.
class SessionManager with WidgetsBindingObserver {
  SessionManager._internal();
  static final SessionManager instance = SessionManager._internal();

  /// 15 minutes inactivity timeout
  static const Duration timeoutDuration = Duration(minutes: 15);

  DateTime _lastActivityTime = DateTime.now();
  DateTime? _pausedAt;
  Timer? _inactivityTimer;
  bool _isLoggingOut = false;
  bool _isInitialized = false;

  /// Initialize lifecycle observation
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);
    resetTimer();
  }

  /// Dispose lifecycle observation
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _isInitialized = false;
  }

  /// Record user touch, scroll, tap or keypress to refresh the idle timer
  void recordUserInteraction() {
    _lastActivityTime = DateTime.now();
    _resetInactivityTimer();
  }

  void resetTimer() {
    _lastActivityTime = DateTime.now();
    _resetInactivityTimer();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(timeoutDuration, () {
      _checkAndTriggerTimeout('Your session expired due to 15 minutes of inactivity.');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pausedAt = DateTime.now();
      _inactivityTimer?.cancel();
      // Unfocus any active keyboard/text field to avoid iOS focusItemsInRect issues
      FocusManager.instance.primaryFocus?.unfocus();
    } else if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final pausedTime = _pausedAt;
      _pausedAt = null;

      if (pausedTime != null) {
        final elapsedInBackground = now.difference(pausedTime);
        if (elapsedInBackground >= timeoutDuration) {
          _checkAndTriggerTimeout('Your session expired due to 15 minutes of inactivity.');
          return;
        }
      }

      // Check total time since last user interaction
      final totalIdle = now.difference(_lastActivityTime);
      if (totalIdle >= timeoutDuration) {
        _checkAndTriggerTimeout('Your session expired due to 15 minutes of inactivity.');
        return;
      }

      // Restart timer for remaining time
      final remaining = timeoutDuration - totalIdle;
      _inactivityTimer?.cancel();
      _inactivityTimer = Timer(remaining > Duration.zero ? remaining : timeoutDuration, () {
        _checkAndTriggerTimeout('Your session expired due to 15 minutes of inactivity.');
      });
    }
  }

  Future<void> _checkAndTriggerTimeout(String reason) async {
    if (_isLoggingOut) return;

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      // User is already logged out or on public screen
      return;
    }

    await forceLogout(reason: reason);
  }

  /// Forces immediate session termination and redirects safely to Login screen
  Future<void> forceLogout({String reason = 'Session expired. Please sign in again.'}) async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      _inactivityTimer?.cancel();
      _inactivityTimer = null;

      await AuthService.clearSession();

      final state = navigatorKey.currentState;
      if (state != null) {
        // Dismiss any open dialogs or bottom sheets first
        state.popUntil((route) => route.isFirst);

        // Safely push to login screen with expiration message
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
      _lastActivityTime = DateTime.now();
    }
  }
}

/// Global widget wrapper that catches all user pointer interactions
/// to keep the session alive while actively using the app.
class SessionTimeoutListener extends StatelessWidget {
  final Widget child;
  const SessionTimeoutListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => SessionManager.instance.recordUserInteraction(),
      onPointerMove: (_) => SessionManager.instance.recordUserInteraction(),
      onPointerUp: (_) => SessionManager.instance.recordUserInteraction(),
      child: child,
    );
  }
}
