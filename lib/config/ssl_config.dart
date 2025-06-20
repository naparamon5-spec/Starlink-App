import 'dart:io';
import 'package:flutter/foundation.dart';

class SSLConfig {
  static bool get isDevelopment => kDebugMode;

  static HttpOverrides get httpOverrides {
    if (isDevelopment) {
      return DevelopmentHttpOverrides();
    } else {
      return ProductionHttpOverrides();
    }
  }
}

class DevelopmentHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return true;
      };
  }
}

class ProductionHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // In production, we only accept valid certificates
        // You can add additional validation here if needed
        return false;
      };
  }
}
