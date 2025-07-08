import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/splash_screen.dart'; // Import the SplashScreen
import 'pages/login_screen.dart'; // Import the LoginScreen
import 'config/ssl_config.dart';
import 'services/notification_service.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'providers/notification_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  // Set up SSL configuration based on environment
  HttpOverrides.global = SSLConfig.httpOverrides;
  // Create a test notification to verify the system works
  await NotificationService.createNotification(
    title: 'Welcome to Starlink App',
    message: 'Your notification system is working!',
    type: 'system',
    icon: Icons.notifications_active,
    color: Colors.blue,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Starlink App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF133343),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF133343),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(), // Set LoginScreen as the initial screen
    );
  }
}
