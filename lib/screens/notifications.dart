import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../ui/widgets.dart';

class NotificationsTab extends StatefulWidget {
  final bool active;
  const NotificationsTab({super.key, required this.active});
  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  int _frozenSeen = 1 << 30; // برای نمایش نقطه «جدید» حتی بعد از علامت‌گذاری

  @override
  void didUpdateWidget(covariant NotificationsTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _frozenSeen = app.seenNotifId;
      app.loadNotifications().catchError((_) {});
      Future.delayed(const Duration(milliseconds: 1200), () => app.markAllSeen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final items = app.notifications;
        return Scaffold(
          appBar: AppBar(title: const Text('اعلان‌ها')),
          body: RefreshIndicator(
            onRefresh: () async {
              try {
                await app.loadNotifications();
              } on ApiException catch (e) {
                toast(e.message, error: true);
              }
            },
            child: items.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 120),
                    EmptyState(Icons.notifications_off_outlined, 'اعلانی وجود ندارد'),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final n = items[i];
                      final isNew = (n['id'] as int) > _frozenSeen;
                      final link = (n['link'] ?? '').toString();
                      final img = (n['image'] ?? '').toString();
                      return SoftCard(
                        onTap: link.isEmpty ? null : () => openLink(link),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconBadge(Icons.campaign_rounded, size: 40, color: cs.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n['title'].toString(),
                                          style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5)),
                                      Text(faDate(n['created_at']),
                                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                if (isNew)
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                            if (img.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              NetImage(img, width: double.infinity, height: 150, radius: 14),
                            ],
                            if ((n['body'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(n['body'].toString(), style: TextStyle(height: 1.9, color: cs.onSurfaceVariant)),
                            ],
                            if (link.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(children: [
                                Icon(Icons.open_in_new_rounded, size: 15, color: cs.primary),
                                const SizedBox(width: 6),
                                Text('باز کردن لینک', style: TextStyle(fontSize: 12, color: cs.primary)),
                              ]),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
