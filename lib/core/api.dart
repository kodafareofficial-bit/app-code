import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'config.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

class Api {
  static String? userToken;
  static String? adminToken;

  /// فراخوانی می‌شود وقتی سرور 401 برگرداند (admin=true برای نشست مدیر)
  static void Function(bool admin)? onUnauthorized;

  static String get _base => apiBaseUrl.replaceAll(RegExp(r'/+$'), '');

  /// تبدیل مسیر نسبی (مثل /uploads/x.png) به آدرس کامل
  static String abs(String? p) {
    if (p == null || p.isEmpty) return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    return _base + (p.startsWith('/') ? p : '/$p');
  }

  static Map<String, String> _headers(bool admin) {
    final t = admin ? adminToken : userToken;
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  static dynamic _decode(http.Response res) {
    final text = utf8.decode(res.bodyBytes);
    if (text.isEmpty) return {};
    try {
      return jsonDecode(text);
    } catch (_) {
      return {};
    }
  }

  static Never _fail(http.Response res, bool admin) {
    final data = _decode(res);
    final msg = (data is Map && data['error'] != null)
        ? data['error'].toString()
        : 'خطای سرور (${res.statusCode})';
    if (res.statusCode == 401) onUnauthorized?.call(admin);
    throw ApiException(msg, res.statusCode);
  }

  static Future<dynamic> _send(String method, String path,
      {Object? body, bool admin = false}) async {
    final uri = Uri.parse('$_base$path');
    final h = _headers(admin);
    final enc = body == null ? null : jsonEncode(body);
    try {
      late http.Response res;
      const t = Duration(seconds: 25);
      switch (method) {
        case 'POST':
          res = await http.post(uri, headers: h, body: enc).timeout(t);
          break;
        case 'PUT':
          res = await http.put(uri, headers: h, body: enc).timeout(t);
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: h).timeout(t);
          break;
        default:
          res = await http.get(uri, headers: h).timeout(t);
      }
      if (res.statusCode >= 400) _fail(res, admin);
      return _decode(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('اتصال به سرور برقرار نشد. اینترنت یا آدرس سرور را بررسی کنید.');
    }
  }

  static Future<dynamic> get(String path, {bool admin = false}) => _send('GET', path, admin: admin);
  static Future<dynamic> post(String path, Object body, {bool admin = false}) =>
      _send('POST', path, body: body, admin: admin);
  static Future<dynamic> put(String path, Object body, {bool admin = false}) =>
      _send('PUT', path, body: body, admin: admin);
  static Future<dynamic> delete(String path, {bool admin = false}) =>
      _send('DELETE', path, admin: admin);

  /// آپلود تصویر توسط مدیر (base64 داخل JSON)؛ مسیر نسبی فایل را برمی‌گرداند
  static Future<String> uploadImage(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw ApiException('حجم تصویر باید کمتر از ۵ مگابایت باشد');
    }
    try {
      final res = await http
          .post(
            Uri.parse('$_base/api/admin/upload'),
            headers: _headers(true),
            body: jsonEncode({'filename': file.name, 'data': base64Encode(bytes)}),
          )
          .timeout(const Duration(seconds: 90));
      if (res.statusCode >= 400) _fail(res, true);
      return (_decode(res) as Map)['url'].toString();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('آپلود تصویر ناموفق بود');
    }
  }

  /// فایل CSV کاربران (بایت‌های خام با BOM برای اکسل)
  static Future<List<int>> downloadUsersCsv() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/api/admin/users/export.csv'), headers: _headers(true))
          .timeout(const Duration(seconds: 60));
      if (res.statusCode >= 400) _fail(res, true);
      return res.bodyBytes;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('دریافت خروجی ناموفق بود');
    }
  }
}
