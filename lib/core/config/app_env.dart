import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://starlink-api.ardentnetworks.com.ph/api';
}
