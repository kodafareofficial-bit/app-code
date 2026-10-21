import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../ui/widgets.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      toast('ایمیل و رمز عبور را وارد کنید', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Api.post('/api/admin/login', {'email': _email.text.trim(), 'password': _pass.text});
      await app.loginAdmin(r['token'] as String, r['email'] as String);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/admin', (_) => false);
    } on ApiException catch (e) {
      toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('ورود مدیریت')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 10),
            Center(child: IconBadge(Icons.admin_panel_settings_rounded, size: 84, color: cs.primary)),
            const SizedBox(height: 22),
            Text('پنل مدیریت ${app.s('company_name')}',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('با ایمیل و رمز عبور مدیر وارد شوید.',
                textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 28),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              autofillHints: const [AutofillHints.email],
              decoration: fieldDeco(context, 'ایمیل', icon: Icons.mail_outline_rounded),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pass,
              obscureText: _hide,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _login(),
              decoration: fieldDeco(
                context,
                'رمز عبور',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
            const SizedBox(height: 22),
            BusyButton(busy: _busy, onPressed: _login, label: 'ورود به پنل', icon: Icons.login_rounded),
          ],
        ),
      ),
    );
  }
}
