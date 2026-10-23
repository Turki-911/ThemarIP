import 'dart:ui';
import 'package:flutter/material.dart';
import 'config/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/bmpf_main_screen.dart';
import 'services/session_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize 15-minute inactivity session tracking
  SessionManager.instance.initialize();

  // Guard against crashes and white-screen freezes on iOS idle/resume
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[ThemarIP] Caught FlutterError: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[ThemarIP] Caught PlatformDispatcher error: $error\n$stack');
    return true; // Prevents app termination on transient network/graphics drop
  };

  // Safe fallback UI if a rendering boundary error occurs (prevents blank white screen)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF0A0E1A),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh_rounded, size: 48, color: Color(0xFF00E5FF)),
                const SizedBox(height: 16),
                const Text(
                  'Workspace Paused',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The screen was paused while idle. Tap below to resume your workspace.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    navigatorKey.currentState?.pushNamedAndRemoveUntil('/categories', (r) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: const Color(0xFF0A0E1A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Resume Workspace', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  runApp(const BmpfApp());
}

class BmpfApp extends StatelessWidget {
  const BmpfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'ThemarIP — Bank Muscat PFM Intelligence',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/splash',
      builder: (context, child) {
        return SessionTimeoutListener(
          child: child ?? const SizedBox.shrink(),
        );
      },
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/terms': (context) => const TermsScreen(),
        '/register': (context) => const RegisterScreen(),
        '/login': (context) => const LoginScreen(),
        '/upload': (context) => const BmpfMainScreen(initialPageIndex: 2),
        '/categories': (context) => const BmpfMainScreen(initialPageIndex: 0),
        '/hierarchy': (context) => const BmpfMainScreen(initialPageIndex: 0),
        '/profile': (context) => const BmpfMainScreen(initialPageIndex: 1),
      },
    );
  }
}
