import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiError implements Exception {
  final String message;
  final int status;
  ApiError(this.message, this.status);
  @override
  String toString() => message;
}

class Api {
  static const baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://10.0.2.2:5180');
  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();
  static Future<String?> token() async => (await _prefs).getString('token');
  static Future<void> logout() async {
    final p = await _prefs;
    await p.remove('token');
    await p.remove('activeFund');
  }

  static Future<Map<String, String>> _headers() async => {
        'Content-Type': 'application/json',
        if (await token() != null) 'Authorization': 'Bearer ${await token()}'
      };

  static Future<dynamic> request(String method, String path,
      {Object? body, bool retryQueue = false}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final h = await _headers();
      late http.Response r;
      if (method == 'GET') {
        r = await http
            .get(uri, headers: h)
            .timeout(const Duration(seconds: 20));
      } else if (method == 'POST') {
        r = await http
            .post(uri, headers: h, body: jsonEncode(body))
            .timeout(const Duration(seconds: 30));
      } else if (method == 'PUT') {
        r = await http
            .put(uri, headers: h, body: jsonEncode(body))
            .timeout(const Duration(seconds: 30));
      } else {
        r = await http
            .delete(uri, headers: h)
            .timeout(const Duration(seconds: 20));
      }
      if (r.statusCode < 200 || r.statusCode >= 300) {
        String msg = 'Máy chủ trả về lỗi ${r.statusCode}';
        try {
          final x = jsonDecode(r.body);
          msg = x['message'] ?? x['title'] ?? msg;
        } catch (_) {}
        throw ApiError(msg, r.statusCode);
      }
      if (r.body.isEmpty) return null;
      return jsonDecode(utf8.decode(r.bodyBytes));
    } on SocketException catch (_) {
      if (retryQueue && method != 'GET') await _enqueue(method, path, body);
      throw ApiError('Không có mạng. Dữ liệu đã được lưu để đồng bộ sau.', 0);
    } on http.ClientException catch (_) {
      if (retryQueue && method != 'GET') await _enqueue(method, path, body);
      throw ApiError('Không thể kết nối máy chủ.', 0);
    }
  }

  static Future<Map<String, dynamic>> auth(
      bool register, String name, String email, String password) async {
    final x = await request(
        'POST', '/api/auth/${register ? 'register' : 'login'}',
        body: register
            ? {'displayName': name, 'email': email, 'password': password}
            : {'email': email, 'password': password});
    await (await _prefs).setString('token', x['token']);
    return Map<String, dynamic>.from(x);
  }

  static Future<List<dynamic>> funds() async =>
      List<dynamic>.from(await request('GET', '/api/funds'));
  static Future<dynamic> createFund(String name) =>
      request('POST', '/api/funds', body: {'name': name});
  static Future<dynamic> joinFund(String code) =>
      request('POST', '/api/funds/join', body: {'inviteCode': code});
  static Future<List<dynamic>> list(String fund, String resource,
          {String query = ''}) async =>
      List<dynamic>.from(await request('GET',
          '/api/funds/$fund/$resource${query.isEmpty ? '' : '?$query'}'));
  static Future<dynamic> dashboard(String fund, int year, int month) =>
      request('GET', '/api/funds/$fund/dashboard?year=$year&month=$month');
  static Future<Map<String, dynamic>> transactions(String fund,
          {String query = ''}) async =>
      Map<String, dynamic>.from(await request('GET',
          '/api/funds/$fund/transactions${query.isEmpty ? '' : '?$query'}'));
  static Future<dynamic> save(
          String fund, String resource, Map<String, dynamic> body,
          {String? id}) =>
      request(id == null ? 'POST' : 'PUT',
          '/api/funds/$fund/$resource${id == null ? '' : '/$id'}',
          body: body, retryQueue: true);
  static Future<void> remove(String fund, String resource, String id) async =>
      request('DELETE', '/api/funds/$fund/$resource/$id', retryQueue: true);
  static Future<dynamic> analyze(String fund, String dataUrl) =>
      request('POST', '/api/funds/$fund/receipts/analyze',
          body: {'fundId': fund, 'dataUrl': dataUrl});
  static String downloadUrl(String fund, String kind, {String query = ''}) =>
      '$baseUrl/api/funds/$fund/$kind${query.isEmpty ? '' : '?$query'}';
  static Future<void> _enqueue(String method, String path, Object? body) async {
    final p = await _prefs;
    final q = p.getStringList('offlineQueue') ?? [];
    q.add(jsonEncode({'method': method, 'path': path, 'body': body}));
    await p.setStringList('offlineQueue', q);
  }

  static Future<int> syncQueue() async {
    final p = await _prefs;
    final q = p.getStringList('offlineQueue') ?? [];
    int done = 0;
    final left = <String>[];
    for (final raw in q) {
      try {
        final x = jsonDecode(raw);
        await request(x['method'], x['path'], body: x['body']);
        done++;
      } catch (_) {
        left.add(raw);
      }
    }
    await p.setStringList('offlineQueue', left);
    return done;
  }

  static Future<void> cache(String key, Object value) async =>
      (await _prefs).setString('cache_$key', jsonEncode(value));
  static Future<dynamic> cached(String key) async {
    final s = (await _prefs).getString('cache_$key');
    return s == null ? null : jsonDecode(s);
  }
}
