import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'constants/app_theme.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'widgets/mobile_frame.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase.initializeApp error/warning: $e');
  }

  runApp(const ProviderScope(child: SpotNugasApp()));
}

class SpotNugasApp extends StatelessWidget {
  final List<Override> overrides;

  const SpotNugasApp({super.key, this.overrides = const []});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        title: 'SpotNugas',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) {
          return MobileFrame(child: child ?? const SizedBox.shrink());
        },
        home: const SplashScreen(),
      ),
    );
  }
}
