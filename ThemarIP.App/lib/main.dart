import 'package:flutter/material.dart';
import 'config/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/bmpf_main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BmpfApp());
}

class BmpfApp extends StatelessWidget {
  const BmpfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThemarIP — Bank Muscat PFM Intelligence',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/terms': (context) => const TermsScreen(),
        '/register': (context) => const RegisterScreen(),
        '/login': (context) => const LoginScreen(),
        '/upload': (context) => const BmpfMainScreen(initialPageIndex: 0),
        '/categories': (context) => const BmpfMainScreen(initialPageIndex: 1),
        '/hierarchy': (context) => const BmpfMainScreen(initialPageIndex: 1),
      },
    );
  }
}
