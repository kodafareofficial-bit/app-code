import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../ui/widgets.dart';
import 'home.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final u = app.user ?? {};
        final name = (u['name'] ?? '').toString();
        final initial = name.isNotEmpty ? String.fromCharCode(name.runes.first) : '👤';
        return Scaffold(
          appBar: AppBar(title: const Text('پروفایل')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            children: [
              SoftCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: cs.primary.withAlpha(30),
                      child: Text(initial, style: TextStyle(fontSize: 26, color: cs.primary, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.isEmpty ? 'نام ثبت نشده' : name,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(fa(localPhone(u['phone'])),
                              textDirection: TextDirection.ltr,
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => showProfileEditor(context),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
              if ((u['email'] ?? '').toString().isNotEmpty || (u['city'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                SoftCard(
                  child: Column(children: [
                    if ((u['email'] ?? '').toString().isNotEmpty)
                      _info(Icons.mail_outline_rounded, u['email'].toString()),
                    if ((u['city'] ?? '').toString().isNotEmpty) _info(Icons.location_city_rounded, u['city'].toString()),
                    if ((u['bio'] ?? '').toString().isNotEmpty) _info(Icons.notes_rounded, u['bio'].toString()),
                  ]),
                ),
              ],

              const SectionHeader('تنظیمات'),
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_active_outlined),
                      title: const Text('دریافت اعلان‌ها'),
                      subtitle: const Text('اعلان‌های جدید شرکت'),
                      value: app.userNotifEnabled,
                      onChanged: (v) async {
                        try {
                          final r = await Api.put('/api/me', {
                            'name': u['name'] ?? '',
                            'email': u['email'] ?? '',
                            'city': u['city'] ?? '',
                            'bio': u['bio'] ?? '',
                            'notif_enabled': v,
                          });
                          await app.updateUser(Map<String, dynamic>.from(r['user'] as Map));
                        } on ApiException catch (e) {
                          toast(e.message, error: true);
                        }
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.web_asset_outlined),
                      title: const Text('نمایش پیام داخل برنامه'),
                      subtitle: const Text('هنگام باز بودن اپ، اعلان جدید نمایش داده شود'),
                      value: app.popupEnabled,
                      onChanged: app.setPopup,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.vibration_rounded),
                      title: const Text('لرزش'),
                      value: app.haptics,
                      onChanged: app.setHaptics,
                    ),
                    ListTile(
                      leading: const Icon(Icons.dark_mode_outlined),
                      title: const Text('پوسته برنامه'),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: ThemeMode.system, label: Text('خودکار')),
                          ButtonSegment(value: ThemeMode.light, label: Text('روشن')),
                          ButtonSegment(value: ThemeMode.dark, label: Text('تیره')),
                        ],
                        selected: {app.themeMode},
                        onSelectionChanged: (s) => app.setThemeMode(s.first),
                      ),
                    ),
                  ],
                ),
              ),

              if (app.socials.isNotEmpty) ...[
                const SectionHeader('ارتباط با ما'),
                SocialRow(socials: app.socials),
              ],
              if (app.s('support_phone').isNotEmpty || app.s('support_email').isNotEmpty) ...[
                const SizedBox(height: 14),
                SoftCard(
                  child: Column(children: [
                    if (app.s('support_phone').isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.call_outlined),
                        title: Text(fa(app.s('support_phone')), textDirection: TextDirection.ltr, textAlign: TextAlign.right),
                        onTap: () => openLink(app.s('support_phone')),
                      ),
                    if (app.s('support_email').isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.mail_outline_rounded),
                        title: Text(app.s('support_email'), textDirection: TextDirection.ltr, textAlign: TextAlign.right),
                        onTap: () => openLink(app.s('support_email')),
                      ),
                  ]),
                ),
              ],

              const SizedBox(height: 22),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded),
                label: const Text('خروج از حساب'),
                onPressed: () async {
                  if (!await confirmDialog(context, 'خروج', 'از حساب کاربری خارج می‌شوید؟', ok: 'خروج')) return;
                  await app.logoutUser();
                  if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
                onPressed: () async {
                  if (!await confirmDialog(context, 'حذف حساب',
                      'حساب شما و اطلاعاتش برای همیشه حذف می‌شود. ادامه می‌دهید؟',
                      ok: 'حذف حساب', danger: true)) return;
                  try {
                    await Api.delete('/api/me');
                    await app.logoutUser();
                    if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                  } on ApiException catch (e) {
                    toast(e.message, error: true);
                  }
                },
                child: const Text('حذف حساب کاربری'),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text('${app.s('company_name')} • نسخه ۱.۰.۰',
                    style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _info(IconData i, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(i, size: 19),
          const SizedBox(width: 12),
          Expanded(child: Text(t, style: const TextStyle(height: 1.6))),
        ]),
      );
}

Future<void> showProfileEditor(BuildContext context, {bool firstTime = false}) {
  final u = app.user ?? {};
  final name = TextEditingController(text: (u['name'] ?? '').toString());
  final email = TextEditingController(text: (u['email'] ?? '').toString());
  final city = TextEditingController(text: (u['city'] ?? '').toString());
  final bio = TextEditingController(text: (u['bio'] ?? '').toString());
  bool busy = false;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    isDismissible: !firstTime,
    enableDrag: !firstTime,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(firstTime ? 'تکمیل پروفایل' : 'ویرایش پروفایل',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(controller: name, decoration: fieldDeco(c, 'نام و نام خانوادگی', icon: Icons.person_outline)),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                decoration: fieldDeco(c, 'ایمیل (اختیاری)', icon: Icons.mail_outline_rounded),
              ),
              const SizedBox(height: 12),
              TextField(controller: city, decoration: fieldDeco(c, 'شهر (اختیاری)', icon: Icons.location_city_rounded)),
              const SizedBox(height: 12),
              TextField(
                controller: bio,
                maxLines: 3,
                decoration: fieldDeco(c, 'درباره من (اختیاری)', icon: Icons.notes_rounded),
              ),
              const SizedBox(height: 18),
              BusyButton(
                busy: busy,
                label: 'ذخیره',
                icon: Icons.check_rounded,
                onPressed: () async {
                  if (name.text.trim().isEmpty) {
                    toast('نام را وارد کنید', error: true);
                    return;
                  }
                  setS(() => busy = true);
                  try {
                    final r = await Api.put('/api/me', {
                      'name': name.text.trim(),
                      'email': email.text.trim(),
                      'city': city.text.trim(),
                      'bio': bio.text.trim(),
                    });
                    await app.updateUser(Map<String, dynamic>.from(r['user'] as Map));
                    if (c.mounted) Navigator.pop(c);
                  } on ApiException catch (e) {
                    toast(e.message, error: true);
                    setS(() => busy = false);
                  }
                },
              ),
              if (firstTime)
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('بعداً')),
            ],
          ),
        ),
      ),
    ),
  );
}
