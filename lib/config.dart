import 'package:flutter/foundation.dart';

/// API configuration with --dart-define override.
class ApiConfig {
  /// e.g. --dart-define=API_BASE_URL=https://api.example.com
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000',
  );

  static Uri uri(String path, [Map<String, dynamic>? query]) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$cleanBase$cleanPath').replace(queryParameters: query);
  }
}
