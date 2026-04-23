import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart'; // 👈 add this

import 'pages/login_screen.dart';
import 'pages/reset_password.dart';
import 'pages/customer/home/customer_home_screen.dart';
import 'pages/admin/admin_home_screen.dart';
import 'pages/end-user/home/home_screen.dart';
import 'services/api_service.dart';
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

  final initialHome = await _resolveInitialHomeForLaunch();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MyApp(initialHome: initialHome),
    ),
  );
}

Widget _getScreenForRole(String role, {int userId = 0}) {
  switch (role.toLowerCase()) {
    case 'admin':
    case 'agent':
      return const AdminHomeScreen();
    case 'end_user':
    case 'end-user':
    case 'enduser':
      return HomeScreen(userId: userId, loginMessage: 'Session restored');
    case 'customer':
    case 'biller':
    default:
      return CustomerHomeScreen(loginMessage: 'Session restored');
  }
}

Future<Widget> _resolveInitialHomeForLaunch() async {
  if (kIsWeb) {
    final uri = Uri.base;
    if (uri.host == 'sandbox.ardentnetworks.com.ph' &&
        uri.path == '/reset-password') {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        return ResetPasswordScreen(
          token: token,
          email: '',
          verificationCode: '',
        );
      }
    }
    return const LoginScreen();
  }

  final token = await ApiService.getValidAccessToken();
  if (token == null || token.isEmpty) {
    return const LoginScreen();
  }

  final profileResponse = await ApiService.getCurrentUserProfile();
  if (profileResponse['status'] == 'success' && profileResponse['data'] != null) {
    final userData = profileResponse['data'];
    final userId =
        (userData['id'] is int)
            ? userData['id'] as int
            : int.tryParse(userData['id']?.toString() ?? '') ?? 0;
    final userRole =
        (userData['role'] ?? userData['type'] ?? 'customer')
            .toString()
            .toLowerCase();
    return _getScreenForRole(userRole, userId: userId);
  }

  return CustomerHomeScreen(loginMessage: 'Session restored');
}

// 👇 Changed from StatelessWidget to StatefulWidget
class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.initialHome});

  final Widget initialHome;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _handleIncomingLinks();
    }
  }

  void _handleIncomingLinks() {
    // App opened from CLOSED state via the email link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _navigateFromLink(uri);
    });

    // App already open or in background
    _appLinks.uriLinkStream.listen(
      (uri) => _navigateFromLink(uri),
      onError: (err) => debugPrint('Deep link error: $err'),
    );
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
                  email: '',
                  verificationCode: '',
                ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
      home: widget.initialHome,
    );
  }
}
