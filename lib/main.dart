import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/theme_service.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/notification_service.dart';
import 'screens/auth/splash_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with the generated options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        // Manages theme switching and persistence
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // Provides authentication logic and user state
        Provider(create: (_) => AuthService()),
        // Provides real-time messaging capabilities
        Provider(create: (_) => ChatService()),
        // Provides notification functionality
        Provider(create: (_) => NotificationService()),
      ],
      child: const BloodyApp(),
    ),
  );
}

class BloodyApp extends StatelessWidget {
  const BloodyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to theme changes to rebuild the app with the correct theme
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Blood Connect',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      // Start with the Splash Screen to determine if the user is logged in
      home: const SplashScreen(),
    );
  }
}
