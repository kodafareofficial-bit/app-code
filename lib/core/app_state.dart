import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'config.dart';

typedef Json = Map<String, dynamic>;

List<Json> _list(dynamic v) =>
    (v is List) ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Json>[];

class AppState extends ChangeNotifier {
  final navKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  // ---- محتوای پویا (از سرور) ----
  Json settings = {
    'company_name': 'کد آفر',
    'company_name_en': 'Code Offer',
    'tagline': 'راهکارهای نرم‌افزاری حرفه‌ای',
    'about': '',
    'logo': '',
    'primary_color': '#6C4DFF',
    'accent_color': '#00C2A8',
    'splash_color': '#0F0B2E',
    'splash_text': 'به کد آفر خوش آمدید',
    'support_phone': '',
    'support_email': '',
  };
  List<Json> banners = [];
  List<Json> categories = [];
  List<Json> services = [];
  List<Json> socials = [];

  // ---- نشست ----
  Json? user;
  String? adminEmail;
  String mode = 'user'; // user | admin

  // ---- اعلان‌ها ----
  List<Json> notifications = [];
  int seenNotifId = 0;
  int _knownNotifId = -1; // آخرین شناسه‌ای که لیست محلی می‌شناسد
  int serverLastNotifId = 0;

  // ---- تنظیمات محلی ----
  ThemeMode themeMode = ThemeMode.system;
  bool popupEnabled = true;
  bool haptics = true;

  bool initialized = false;
  Timer? _timer;
  void Function(Json n)? onNewNotification;
  late SharedPreferences _prefs;

  String s(String key) => (settings[key] ?? '').toString();

  bool get isUserLoggedIn => Api.userToken != null && user != null;
  bool get isAdminLoggedIn => Api.adminToken != null;

  int get unread => notifications.where((n) => (n['id'] as int) > seenNotifId).length;

  bool get userNotifEnabled => (user?['notif_enabled'] ?? 1) == 1;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    Api.userToken = _prefs.getString('user_token');
    Api.adminToken = _prefs.getString('admin_token');
    adminEmail = _prefs.getString('admin_email');
    mode = _prefs.getString('mode') ?? 'user';
    final u = _prefs.getString('user');
    if (u != null) {
      try {
        user = Map<String, dynamic>.from(jsonDecode(u) as Map);
      } catch (_) {}
    }
    final t = _prefs.getString('theme') ?? 'system';
    themeMode = t == 'dark' ? ThemeMode.dark : t == 'light' ? ThemeMode.light : ThemeMode.system;
    popupEnabled = _prefs.getBool('popup') ?? true;
    haptics = _prefs.getBool('haptics') ?? true;
    seenNotifId = _prefs.getInt('seen_notif') ?? -1;

    final cached = _prefs.getString('bootstrap');
    if (cached != null) {
      try {
        _applyBootstrap(Map<String, dynamic>.from(jsonDecode(cached) as Map));
      } catch (_) {}
    }
    Api.onUnauthorized = (admin) {
      if (admin) {
        logoutAdmin();
      } else {
        logoutUser();
      }
      navKey.currentState?.pushNamedAndRemoveUntil('/login', (r) => false);
    };
    initialized = true;
    notifyListeners();
  }

  void _applyBootstrap(Json d) {
    final st = d['settings'];
    if (st is Map) settings = {...settings, ...Map<String, dynamic>.from(st)};
    banners = _list(d['banners']);
    categories = _list(d['categories']);
    services = _list(d['services']);
    socials = _list(d['socials']);
    serverLastNotifId = (d['last_notification_id'] ?? 0) as int;
  }

  /// دریافت آخرین محتوا از سرور. هر تغییری که مدیر بدهد از همین‌جا خودکار به کاربر می‌رسد.
  Future<void> refresh({bool silent = false}) async {
    try {
      final d = await Api.get('/api/public/bootstrap');
      _applyBootstrap(Map<String, dynamic>.from(d as Map));
      await _prefs.setString('bootstrap', jsonEncode(d));
      if (isUserLoggedIn && serverLastNotifId > _knownNotifId) {
        await loadNotifications(announce: _knownNotifId >= 0);
      }
      notifyListeners();
    } catch (e) {
      if (!silent) rethrow;
    }
  }

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: pollSeconds), (_) => refresh(silent: true));
  }

  void stopPolling() => _timer?.cancel();

  Future<void> loadNotifications({bool announce = false}) async {
    if (!isUserLoggedIn) return;
    final d = await Api.get('/api/notifications');
    final items = _list((d as Map)['items']);
    final prevKnown = _knownNotifId;
    notifications = items;
    final maxId = items.isEmpty ? 0 : items.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b);
    _knownNotifId = maxId;
    if (seenNotifId < 0) {
      // اولین ورود: اعلان‌های قدیمی را خوانده‌شده حساب کن
      seenNotifId = maxId;
      await _prefs.setInt('seen_notif', seenNotifId);
    }
    if (announce && userNotifEnabled && popupEnabled && maxId > prevKnown && items.isNotEmpty) {
      final fresh = items.firstWhere((e) => (e['id'] as int) == maxId);
      onNewNotification?.call(fresh);
    }
    notifyListeners();
  }

  Future<void> markAllSeen() async {
    if (notifications.isEmpty) return;
    final maxId = notifications.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b);
    if (maxId > seenNotifId) {
      seenNotifId = maxId;
      await _prefs.setInt('seen_notif', seenNotifId);
      notifyListeners();
    }
  }

  // ---- ورود/خروج کاربر ----
  Future<void> loginUser(String token, Json u) async {
    Api.userToken = token;
    user = u;
    mode = 'user';
    await _prefs.setString('user_token', token);
    await _prefs.setString('user', jsonEncode(u));
    await _prefs.setString('mode', 'user');
    _knownNotifId = -1;
    notifyListeners();
  }

  Future<void> updateUser(Json u) async {
    user = u;
    await _prefs.setString('user', jsonEncode(u));
    notifyListeners();
  }

  Future<void> logoutUser() async {
    Api.userToken = null;
    user = null;
    notifications = [];
    _knownNotifId = -1;
    await _prefs.remove('user_token');
    await _prefs.remove('user');
    notifyListeners();
  }

  // ---- ورود/خروج مدیر ----
  Future<void> loginAdmin(String token, String email) async {
    Api.adminToken = token;
    adminEmail = email;
    mode = 'admin';
    await _prefs.setString('admin_token', token);
    await _prefs.setString('admin_email', email);
    await _prefs.setString('mode', 'admin');
    notifyListeners();
  }

  Future<void> logoutAdmin() async {
    Api.adminToken = null;
    adminEmail = null;
    mode = 'user';
    await _prefs.remove('admin_token');
    await _prefs.remove('admin_email');
    await _prefs.setString('mode', 'user');
    notifyListeners();
  }

  // ---- تنظیمات محلی ----
  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    await _prefs.setString('theme', m == ThemeMode.dark ? 'dark' : m == ThemeMode.light ? 'light' : 'system');
    notifyListeners();
  }

  Future<void> setPopup(bool v) async {
    popupEnabled = v;
    await _prefs.setBool('popup', v);
    notifyListeners();
  }

  Future<void> setHaptics(bool v) async {
    haptics = v;
    await _prefs.setBool('haptics', v);
    notifyListeners();
  }
}

final app = AppState();
