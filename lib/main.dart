import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase is only configured for Android/iOS (via google-services.json /
  // GoogleService-Info.plist). It isn't set up for web yet — calling
  // initializeApp() there throws because it needs FirebaseOptions. FCM
  // itself already skips web (see FcmService), so just skip init here too.
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }
  runApp(const JolshiriApp());
}

class JolshiriApp extends StatelessWidget {
  const JolshiriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jolshiri Smart City',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
