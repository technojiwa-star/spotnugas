import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../main_navigation_screen.dart';
import '../onboarding_screen.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  static Future<Widget> resolveInitialDestination(WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedOnboarding =
        prefs.getBool('onboarding_completed') ?? false;
    final currentUser = ref.read(authRepositoryProvider).currentUser;

    if (currentUser != null) {
      // Returning authenticated user or returning guest user
      return const MainNavigationScreen();
    } else if (!hasCompletedOnboarding) {
      // First-time user
      return const OnboardingScreen();
    } else {
      // Unauthenticated returning user
      return const LoginScreen(isFirstTime: false);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return const MainNavigationScreen();
        }
        return FutureBuilder<bool>(
          future: SharedPreferences.getInstance().then(
            (prefs) => prefs.getBool('onboarding_completed') ?? false,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(
                backgroundColor: AppColors.lightCreamBackground,
                body: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryTeal,
                  ),
                ),
              );
            }
            final hasCompletedOnboarding = snapshot.data ?? false;
            if (!hasCompletedOnboarding) {
              return const OnboardingScreen();
            }
            return const LoginScreen(isFirstTime: false);
          },
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.lightCreamBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryTeal),
        ),
      ),
      error: (err, stack) => const LoginScreen(isFirstTime: false),
    );
  }
}
