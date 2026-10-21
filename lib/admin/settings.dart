import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../ui/widgets.dart';
import 'form_kit.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with AutomaticKeepAliveClientMixin {
  final Map<String, TextEditingController> _c = {};
  String _logo = '';
  bool _smsEnabled = false;
  bool _tokenSet = false;
  String _smsMode = 'pattern';
  bool _loaded = false;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  static const _textKeys = [
    'company_name', 'company_name_en', 'tagline', 'about', 'splash_text', 'support_phone', 'support_email',
    'primary_color', 'accent_color', 'splash_color',
    'sms_base_url', 'sms_token', 'sms_from_number', 'sms_pattern_code', 'sms_pattern_param', 'sms_message_template',
  ];

  @override
  bool get wantKeepAlive => true;

  TextEditingController _ctl(String k) => _c.putIfAbsent(k, () => TextEditingController());

  @override
  void initState() {
    super.initState();
    for (final k in _textKeys) {
      _ctl(k);
    }
    Future.microtask(_load);
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Api.get('/api/admin/settings', admin: true);
      final s = Map<String, dynamic>.from((r as Map)['settings'] as Map);
      for (final k in _textKeys) {
        if (k == 'sms_token') continue;
        _ctl(k).text = (s[k] ?? '').toString();
      }
      if (!mounted) return;
      setState(() {
        _logo = (s['logo'] ?? '').toString();
        _smsEnabled = s['sms_enabled'] == '1';
        _tokenSet = s['sms_token_set'] == '1';
        _smsMode = (s['sms_mode'] ?? 'pattern').toString() == 'webservice' ? 'webservice' : 'pattern';
        _loaded = true;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        for (final k in _textKeys) k: _ctl(k).text.trim(),
        'logo': _logo,
        'sms_enabled': _smsEnabled ? '1' : '0',
        'sms_mode': _smsMode,
      };
      await Api.put('/api/admin/settings', body, admin: true);
      await app.refresh(silent: true);
      _ctl('sms_token').clear();
      await _load();
      toast('تنظیمات ذخیره شد و برای همه کاربران اعمال می‌شود');
    } on ApiException catch (e) {
      toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testSms() async {
    final phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('ارسال پیامک آزمایشی'),
        content: TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: fieldDeco(c, 'شماره موبایل', hint: '09123456789'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('ارسال'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _save();
      await Api.post('/api/admin/sms/test', {'phone': phone.text.trim()}, admin: true);
      toast('درخواست ارسال به ippanel انجام شد (کد آزمایشی: ۱۲۳۴۵)');
    } on ApiException catch (e) {
      toast(e.message, error: true);
    }
  }

  void _changePassword() {
    final cur = TextEditingController();
    final np = TextEditingController();
    final ne = TextEditingController(text: app.adminEmail ?? '');
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('حساب مدیر'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ne, textDirection: TextDirection.ltr, decoration: fieldDeco(c, 'ایمیل')),
            const SizedBox(height: 10),
            TextField(controller: cur, obscureText: true, decoration: fieldDeco(c, 'رمز فعلی')),
            const SizedBox(height: 10),
            TextField(controller: np, obscureText: true, decoration: fieldDeco(c, 'رمز جدید (حداقل ۸ کاراکتر)')),
            const SizedBox(height: 8),
            const Text(
              'توجه: اگر ADMIN_PASSWORD روی سرور تنظیم شده باشد، با هر ریستارت سرور همان مقدار دوباره اعمال می‌شود.',
              style: TextStyle(fontSize: 11.5, height: 1.7),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
            onPressed: () async {
              try {
                await Api.put('/api/admin/account', {
                  'current_password': cur.text,
                  if (np.text.isNotEmpty) 'new_password': np.text,
                  if (ne.text.trim().isNotEmpty && ne.text.trim() != app.adminEmail) 'new_email': ne.text.trim(),
                }, admin: true);
                if (c.mounted) Navigator.pop(c);
                toast('اطلاعات حساب بروزرسانی شد؛ دوباره وارد شوید');
                await app.logoutAdmin();
                if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              } on ApiException catch (e) {
                toast(e.message, error: true);
              }
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  Widget _field(String k, String label, {bool ltr = false, int lines = 1, String? hint, bool obscure = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _ctl(k),
          maxLines: obscure ? 1 : lines,
          obscureText: obscure,
          textDirection: ltr ? TextDirection.ltr : null,
          textAlign: ltr ? TextAlign.left : TextAlign.start,
          decoration: fieldDeco(context, label, hint: hint),
        ),
      );

  Widget _section(String title, IconData icon, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                IconBadge(icon, size: 38),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    if (!_loaded) {
      return Center(
        child: _error != null
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                EmptyState(Icons.wifi_off_rounded, _error!),
                FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(140, 46)), onPressed: _load, child: const Text('تلاش دوباره')),
              ])
            : const CircularProgressIndicator(),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        _section('برند و ظاهر اپ', Icons.palette_outlined, [
          Row(children: [
            AppLogoPreview(url: _logo),
            const SizedBox(width: 14),
            Expanded(
              child: Column(children: [
                OutlinedButton.icon(
                  onPressed: _uploading
                      ? null
                      : () async {
                          setState(() => _uploading = true);
                          try {
                            final u = await pickAndUploadImage();
                            if (u != null) setState(() => _logo = u);
                          } on ApiException catch (e) {
                            toast(e.message, error: true);
                          } finally {
                            if (mounted) setState(() => _uploading = false);
                          }
                        },
                  icon: _uploading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_rounded),
                  label: const Text('آپلود لوگو'),
                ),
                if (_logo.isNotEmpty)
                  TextButton(onPressed: () => setState(() => _logo = ''), child: const Text('حذف لوگو (استفاده از پیش‌فرض)')),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          _field('company_name', 'نام شرکت'),
          _field('company_name_en', 'نام انگلیسی', ltr: true),
          _field('tagline', 'شعار'),
          _field('about', 'درباره ما', lines: 4),
          _field('splash_text', 'متن صفحه اسپلش'),
          ColorField(label: 'رنگ اصلی', controller: _ctl('primary_color')),
          const SizedBox(height: 12),
          ColorField(label: 'رنگ فرعی', controller: _ctl('accent_color')),
          const SizedBox(height: 12),
          ColorField(label: 'رنگ پس‌زمینه اسپلش', controller: _ctl('splash_color')),
        ]),
        _section('اطلاعات تماس', Icons.support_agent_rounded, [
          _field('support_phone', 'تلفن پشتیبانی', ltr: true),
          _field('support_email', 'ایمیل پشتیبانی', ltr: true),
        ]),
        _section('پنل پیامکی ippanel', Icons.sms_outlined, [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('فعال‌سازی ارسال پیامک ورود'),
            subtitle: Text(_smsEnabled ? 'کد تایید با ippanel ارسال می‌شود' : 'غیرفعال: کد فقط در لاگ سرور چاپ می‌شود (حالت تست)'),
            value: _smsEnabled,
            onChanged: (v) => setState(() => _smsEnabled = v),
          ),
          const SizedBox(height: 6),
          _field('sms_base_url', 'آدرس پایه API', ltr: true, hint: 'https://edge.ippanel.com/v1'),
          _field('sms_token', _tokenSet ? 'توکن API (ذخیره شده ✓ — برای تغییر، مقدار جدید بنویسید)' : 'توکن API (Authorization)', ltr: true, obscure: true),
          _field('sms_from_number', 'شماره ارسال‌کننده', ltr: true, hint: '+983000505'),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'pattern', label: Text('الگو (پترن)')),
              ButtonSegment(value: 'webservice', label: Text('متن ساده')),
            ],
            selected: {_smsMode},
            onSelectionChanged: (s) => setState(() => _smsMode = s.first),
          ),
          const SizedBox(height: 12),
          if (_smsMode == 'pattern') ...[
            _field('sms_pattern_code', 'کد الگو (Pattern Code)', ltr: true),
            _field('sms_pattern_param', 'نام متغیر کد در الگو', ltr: true, hint: 'code'),
          ] else
            _field('sms_message_template', 'متن پیام (از {code} استفاده کنید)', lines: 2),
          Text(
            'پیشنهاد: برای OTP از «الگو» استفاده کنید؛ ارسال الگویی فوری است و نیاز به تایید مانیتورینگ ندارد.',
            style: TextStyle(fontSize: 12, height: 1.7, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _testSms, icon: const Icon(Icons.send_rounded), label: const Text('ذخیره و ارسال پیامک آزمایشی')),
        ]),
        const SizedBox(height: 18),
        BusyButton(busy: _saving, onPressed: _save, label: 'ذخیره همه تنظیمات', icon: Icons.save_outlined),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _changePassword,
          icon: const Icon(Icons.lock_reset_rounded),
          label: const Text('تغییر ایمیل / رمز مدیر'),
        ),
      ],
    );
  }
}

class AppLogoPreview extends StatelessWidget {
  final String url;
  const AppLogoPreview({super.key, required this.url});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: url.isNotEmpty
          ? NetImage(url, width: 84, height: 84, fit: BoxFit.contain)
          : Image.asset('assets/logo.png', width: 84, height: 84, fit: BoxFit.cover),
    );
  }
}
