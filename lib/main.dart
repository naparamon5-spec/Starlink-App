import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart'; // 👈 add this

import 'pages/splash_screen.dart';
import 'pages/reset_password.dart';
import 'providers/notification_provider.dart';
import 'config/ssl_config.dart'
    if (dart.library.html) 'config/ssl_config_stub.dart'
    as ssl_config;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  if (!kIsWeb) {
    ssl_config.setupSSLConfig();
  }

  // 👇 OneSignal setup (only on mobile, not web)
  if (!kIsWeb) {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose); // remove in production
    OneSignal.initialize("Ye5a4e262-1dd1-413e-a3a7-3c4ec50f3164");
    OneSignal.Notifications.requestPermission(false);
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

// 👇 Changed from StatelessWidget to StatefulWidget
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
  }

  void _handleIncomingLinks() {
    // App opened from CLOSED state via the email link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _navigateFromLink(uri);
    });

    // App already open or in background
    _appLinks.uriLinkStream.listen((uri) {
      _navigateFromLink(uri);
    });
  }

  void _navigateFromLink(Uri uri) {
    if (uri.host == 'sandbox.ardentnetworks.com.ph' &&
        uri.path == '/reset-password') {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder:
                (_) => ResetPasswordScreen(
                  token: token,
                  email: '', // 👈 pass empty, backend only needs token
                  verificationCode:
                      '', // 👈 pass empty, backend only needs token
                ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // 👈 attach global key
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
      home: const SplashScreen(),
    );
  }
}
