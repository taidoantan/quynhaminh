import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

class Api {
  static const base = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://10.0.2.2:5180');
  static Future<String?> token() async =>
      (await SharedPreferences.getInstance()).getString('token_v2');
  static Future<Map<String, String>> headers() async => {
        'Content-Type': 'application/json',
        if (await token() != null) 'Authorization': 'Bearer ${await token()}'
      };
  static Future<void> saveToken(String t) async =>
      (await SharedPreferences.getInstance()).setString('token_v2', t);
  static Future<void> clear() async =>
      (await SharedPreferences.getInstance()).clear();
  static Future<void> auth(String path, Map<String, dynamic> body) async {
    final r = await http.post(Uri.parse('$base$path'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    if (r.statusCode >= 300) throw Exception(r.body);
    await saveToken(jsonDecode(r.body)['token']);
  }

  static Future<List<dynamic>> families() async {
    final r = await http.get(Uri.parse('$base/api/families'),
        headers: await headers());
    if (r.statusCode >= 300) throw Exception(r.body);
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> createFamily(String name) async {
    final r = await http.post(Uri.parse('$base/api/families'),
        headers: await headers(), body: jsonEncode({'name': name}));
    if (r.statusCode >= 300) throw Exception(r.body);
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> joinFamily(String code) async {
    final r = await http.post(Uri.parse('$base/api/families/join'),
        headers: await headers(), body: jsonEncode({'inviteCode': code}));
    if (r.statusCode >= 300) throw Exception(r.body);
    return jsonDecode(r.body);
  }

  static Future<List<String>> categories(String type) async {
    final r = await http.get(Uri.parse('$base/api/categories?type=$type'),
        headers: await headers());
    return (jsonDecode(r.body) as List)
        .map((x) => x['name'] as String)
        .toList();
  }

  static Future<List<MoneyTransaction>> transactions(String familyId) async {
    final r = await http.get(
        Uri.parse('$base/api/transactions?familyId=$familyId'),
        headers: await headers());
    if (r.statusCode >= 300) throw Exception(r.body);
    return (jsonDecode(r.body) as List)
        .map((x) => MoneyTransaction.fromJson(x))
        .toList();
  }

  static Future<Map<String, dynamic>> summary(String familyId) async {
    final n = DateTime.now();
    final r = await http.get(
        Uri.parse(
            '$base/api/summary?familyId=$familyId&year=${n.year}&month=${n.month}'),
        headers: await headers());
    if (r.statusCode >= 300) throw Exception(r.body);
    return jsonDecode(r.body);
  }

  static Future<void> add(Map<String, dynamic> x) async {
    final r = await http.post(Uri.parse('$base/api/transactions'),
        headers: await headers(), body: jsonEncode(x));
    if (r.statusCode >= 300) throw Exception(r.body);
  }

  static Future<Map<String, dynamic>> scan(String dataUrl) async {
    final r = await http.post(Uri.parse('$base/api/receipts/analyze'),
        headers: await headers(), body: jsonEncode({'dataUrl': dataUrl}));
    if (r.statusCode >= 300) throw Exception(r.body);
    return jsonDecode(r.body);
  }
}
