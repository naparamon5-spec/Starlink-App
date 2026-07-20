import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static const String _defaultApiBaseUrl =
      'https://starlink-api.ardentnetworks.com.ph/api';

  /// Falls back to the default when `.env` was never loaded (e.g. in tests, or
  /// if the asset is missing from a build) instead of throwing.
  static String get apiBaseUrl {
    if (!dotenv.isInitialized) return _defaultApiBaseUrl;
    return dotenv.env['API_BASE_URL'] ?? _defaultApiBaseUrl;
  }
}
