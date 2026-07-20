import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:starlink_app/shared/widgets/force_update_dialog.dart';
import 'package:starlink_app/services/version_service.dart';

import 'package:starlink_app/features/auth/login_screen.dart';
import 'package:starlink_app/features/auth/reset_password.dart';
import 'package:starlink_app/features/customer/home/customer_home_screen.dart';
import 'package:starlink_app/features/admin/admin_home_screen.dart';
import 'package:starlink_app/features/end_user/home/home_screen.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/providers/notification_provider.dart';
import 'package:starlink_app/core/config/ssl_config.dart'
    if (dart.library.html) 'package:starlink_app/core/config/ssl_config_stub.dart'
    as ssl_config;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  if (!kIsWeb) {
    ssl_config.setupSSLConfig();
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
    // if (uri.host == 'startlink-sandbox-api.ardentnetworks.com.ph' &&
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
  if (profileResponse['status'] == 'success' &&
      profileResponse['data'] != null) {
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _appLinks = AppLinks();
  DateTime? _lastPausedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Schedule the version gate to run after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppVersion();
    });

    if (!kIsWeb) {
      _handleIncomingLinks();
    }
  }

  Future<void> _checkAppVersion() async {
    final versionInfo = await AppVersionService().checkVersion();
    if (!mounted) return;
    if (versionInfo['isOutdated'] == true &&
        versionInfo['isMandatory'] == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => ForceUpdateDialog(downloadUrl: versionInfo['downloadUrl']),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_lastPausedTime != null) {
        final duration = DateTime.now().difference(_lastPausedTime!);
        // Logout if app was in background for > 5 minutes
        if (duration.inMinutes >= 5) {
          ApiService.clearTokens();
        }
      }
      _lastPausedTime = null;
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
      title: 'Starlink Dashboard',
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
