import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'pages/splash_screen.dart'; // Import the SplashScreen
import 'pages/login_screen.dart'; // Import the LoginScreen
import 'services/notification_service.dart';
import 'package:provider/provider.dart';
import 'providers/notification_provider.dart';

// Only import and use SSL config on non-web platforms
import 'config/ssl_config.dart'
    if (dart.library.html) 'config/ssl_config_stub.dart'
    as ssl_config;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  // Set up SSL configuration based on environment (only on non-web platforms)
  if (!kIsWeb) {
    ssl_config.setupSSLConfig();
  }
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
