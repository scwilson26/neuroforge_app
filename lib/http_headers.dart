import 'package:shared_preferences/shared_preferences.dart';

class HttpHeadersHelper {
  static const _authKey = 'auth_token';

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString(_authKey);
    if (t == null || t.trim().isEmpty) return null;
    return t.trim();
  }

  static Future<Map<String, String>> previewHeaders() async {
    final h = <String, String>{'Accept': 'application/json'};
    final token = await getAuthToken();
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  static Future<Map<String, String>> zipHeaders() async {
    final h = <String, String>{'Accept': 'application/zip'};
    final token = await getAuthToken();
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }
}
