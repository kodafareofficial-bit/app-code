import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeStep = false;
  bool _busy = false;
  int _left = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String _digits(String s) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final r in s.runes) {
      final c = String.fromCharCode(r);
      final i = fa.indexOf(c) >= 0 ? fa.indexOf(c) : ar.indexOf(c);
      b.write(i >= 0 ? '$i' : c);
    }
    return b.toString();
  }

  bool get _phoneOk => RegExp(r'^0?9\d{9}$').hasMatch(_digits(_phone.text).trim());

  void _startTimer(int s) {
    _timer?.cancel();
    setState(() => _left = s);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  Future<void> _request() async {
    if (!_phoneOk) {
      toast('شماره موبایل را درست وارد کنید (مثال: 09123456789)', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Api.post('/api/auth/request-otp', {'phone': _digits(_phone.text).trim()});
      if (!mounted) return;
      setState(() => _codeStep = true);
      _startTimer(60);
      if (r is Map && r['dev_code'] != null) toast('کد تست: ${r['dev_code']}');
    } on ApiException catch (e) {
      toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _digits(_code.text).trim();
    if (code.length != 5) return;
    setState(() => _busy = true);
    try {
      final r = await Api.post('/api/auth/verify-otp', {'phone': _digits(_phone.text).trim(), 'code': code});
      await app.loginUser(r['token'] as String, Map<String, dynamic>.from(r['user'] as Map));
      app.refresh(silent: true);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } on ApiException catch (e) {
      toast(e.message, error: true);
      _code.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = hexColor(app.s('primary_color'), const Color(0xFF6C4DFF));
    final accent = hexColor(app.s('accent_color'), const Color(0xFF00C2A8));
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 36, 24, 44),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [primary, Color.lerp(primary, accent, 0.65)!],
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(42)),
            ),
            child: Column(
              children: [
                const AppLogo(size: 84, radius: 26),
                const SizedBox(height: 16),
                Text(app.s('company_name'),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(app.s('tagline'), style: TextStyle(color: Colors.white.withAlpha(210), fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _codeStep ? _codeView(cs) : _phoneView(cs),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _phoneView(ColorScheme cs) {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('ورود | ثبت‌نام', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('شماره موبایل خود را وارد کنید تا کد تایید برایتان پیامک شود.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.7)),
        const SizedBox(height: 22),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]'))],
          style: const TextStyle(fontSize: 18, letterSpacing: 2),
          decoration: fieldDeco(context, 'شماره موبایل', icon: Icons.phone_iphone_rounded, hint: '09123456789')
              .copyWith(counterText: ''),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _request(),
        ),
        const SizedBox(height: 18),
        BusyButton(busy: _busy, onPressed: _phoneOk ? _request : null, label: 'دریافت کد تایید', icon: Icons.sms_outlined),
        const SizedBox(height: 18),
        Center(
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/admin-login'),
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: const Text('ورود مدیر'),
          ),
        ),
      ],
    );
  }

  Widget _codeView(ColorScheme cs) {
    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('کد تایید', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('کد ۵ رقمی ارسال‌شده به ${fa(localPhone(_digits(_phone.text)))} را وارد کنید.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.7)),
        const SizedBox(height: 22),
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLength: 5,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]'))],
          style: const TextStyle(fontSize: 28, letterSpacing: 14, fontWeight: FontWeight.w700),
          decoration: fieldDeco(context, 'کد تایید').copyWith(counterText: ''),
          onChanged: (v) {
            setState(() {});
            if (_digits(v).length == 5) _verify();
          },
        ),
        const SizedBox(height: 18),
        BusyButton(
          busy: _busy,
          onPressed: _digits(_code.text).length == 5 ? _verify : null,
          label: 'تایید و ورود',
          icon: Icons.check_circle_outline,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      _timer?.cancel();
                      setState(() {
                        _codeStep = false;
                        _code.clear();
                      });
                    },
              child: const Text('ویرایش شماره'),
            ),
            TextButton(
              onPressed: (_left > 0 || _busy) ? null : _request,
              child: Text(_left > 0 ? 'ارسال مجدد (${fa(_left)})' : 'ارسال مجدد کد'),
            ),
          ],
        ),
      ],
    );
  }
}
