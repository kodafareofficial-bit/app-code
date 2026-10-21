import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../ui/widgets.dart';
import 'content.dart';
import 'dashboard.dart';
import 'notify.dart';
import 'settings.dart';
import 'users.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;
  static const _titles = ['داشبورد', 'کاربران', 'محتوا و خدمات', 'اعلان‌ها', 'تنظیمات'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) async {
              if (v == 'preview') {
                // نمایش اپ مشتری بدون خروج از نشست مدیر
                await app.refresh(silent: true);
                if (!context.mounted) return;
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _UserPreview()));
              } else if (v == 'logout') {
                if (!await confirmDialog(context, 'خروج', 'از پنل مدیریت خارج می‌شوید؟', ok: 'خروج')) return;
                await app.logoutAdmin();
                if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(app.adminEmail ?? '', textDirection: TextDirection.ltr)),
              const PopupMenuItem(value: 'preview', child: Text('پیش‌نمایش اپ مشتری')),
              const PopupMenuItem(value: 'logout', child: Text('خروج')),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          DashboardPage(active: _tab == 0),
          UsersPage(active: _tab == 1),
          const ContentPage(),
          NotifyPage(active: _tab == 3),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'داشبورد'),
          NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'کاربران'),
          NavigationDestination(icon: Icon(Icons.dashboard_customize_outlined), selectedIcon: Icon(Icons.dashboard_customize_rounded), label: 'محتوا'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign_rounded), label: 'اعلان'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'تنظیمات'),
        ],
      ),
    );
  }
}

/// پیش‌نمایش ساده برای مدیر: همان خانه/خدمات که مشتری می‌بیند
class _UserPreview extends StatelessWidget {
  const _UserPreview();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('پیش‌نمایش اپ مشتری')),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Center(child: AppLogo(size: 90, radius: 26)),
            const SizedBox(height: 12),
            Center(child: Text(app.s('company_name'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
            Center(child: Text(app.s('tagline'))),
            if (app.banners.isNotEmpty) ...[
              const SectionHeader('بنرها'),
              for (final b in app.banners)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NetImage(b['image']?.toString(), height: 140, width: double.infinity, radius: 18),
                ),
            ],
            const SectionHeader('خدمات'),
            for (final s in app.services)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  child: Row(children: [
                    IconBadge(iconOf(s['icon'])),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(s['description'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
