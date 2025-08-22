import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HttpHelper {
  final http.Client _client;
  HttpHelper([http.Client? client]) : _client = client ?? http.Client();

  Future<http.Response> sendWithRetry(http.BaseRequest request, {int maxRetries = 3}) async {
    int attempt = 0;
    Duration delay = const Duration(milliseconds: 400);
    while (true) {
      attempt++;
      try {
        final streamed = await _client.send(request);
        final res = await http.Response.fromStream(streamed);
        if (_shouldRetry(res) && attempt < maxRetries) {
          await Future.delayed(delay);
          delay *= 2;
          continue;
        }
        return res;
      } on http.ClientException catch (_) {
        if (attempt >= maxRetries) rethrow;
        await Future.delayed(delay);
        delay *= 2;
      }
    }
  }

  bool _shouldRetry(http.Response res) =>
      res.statusCode == 429 || (res.statusCode >= 500 && res.statusCode < 600);

  Future<Map<String, dynamic>> getJson(Uri uri, {Map<String, String>? headers}) async {
    final req = http.Request('GET', uri);
    if (headers != null) req.headers.addAll(headers);
    final res = await sendWithRetry(req);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw HttpException('GET ${uri.toString()} failed ${res.statusCode}');
  }
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => message;
}
