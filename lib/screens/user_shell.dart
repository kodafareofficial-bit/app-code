import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import 'home.dart';
import 'notifications.dart';
import 'profile.dart';
import 'services.dart';

class UserShell extends StatefulWidget {
  const UserShell({super.key});
  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // اعلان جدید هنگام باز بودن اپ
    app.onNewNotification = (n) {
      if (app.haptics) HapticFeedback.mediumImpact();
      final m = app.messengerKey.currentState;
      if (m == null) return;
      m
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 6),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((n['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
              if ((n['body'] ?? '').toString().isNotEmpty)
                Text((n['body']).toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
          action: SnackBarAction(label: 'مشاهده', onPressed: () => setState(() => _tab = 2)),
        ));
    };
    app.loadNotifications().catchError((_) {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // کاربر جدید: تکمیل پروفایل
      if (mounted && (app.user?['name'] ?? '').toString().isEmpty) {
        showProfileEditor(context, firstTime: true);
      }
    });
  }

  @override
  void dispose() {
    app.onNewNotification = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final unread = app.unread;
        return Scaffold(
          body: IndexedStack(
            index: _tab,
            children: [
              HomeTab(onOpenNotifications: () => setState(() => _tab = 2), onOpenServices: () => setState(() => _tab = 1)),
              const ServicesTab(),
              NotificationsTab(active: _tab == 2),
              const ProfileTab(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              const NavigationDestination(
                  icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'خانه'),
              const NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'خدمات'),
              NavigationDestination(
                icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications_none_rounded)),
                selectedIcon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications_rounded)),
                label: 'اعلان‌ها',
              ),
              const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'پروفایل'),
            ],
          ),
        );
      },
    );
  }
}
