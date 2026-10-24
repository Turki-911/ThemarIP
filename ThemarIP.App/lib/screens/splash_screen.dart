import 'package:flutter/material.dart';
import 'onboarding_screen.dart';

/// The app's initial `/splash` route now renders the Omani-culture 2-page Splash/Onboarding
/// experience (matching attached Image #1 and Image #2) directly on startup.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingScreen(isSplashEntry: true);
  }
}
