import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../ui/widgets.dart';
import 'users.dart';

class DashboardPage extends StatefulWidget {
  final bool active;
  const DashboardPage({super.key, required this.active});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _d;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant DashboardPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.get('/api/admin/stats', admin: true);
      if (mounted) setState(() {
            _d = Map<String, dynamic>.from(r as Map);
            _error = null;
          });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = _d;
    if (d == null) {
      return Center(
        child: _error != null
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                EmptyState(Icons.wifi_off_rounded, _error!),
                FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(140, 46)), onPressed: _load, child: const Text('تلاش دوباره')),
              ])
            : const CircularProgressIndicator(),
      );
    }
    final tiles = [
      ('کل کاربران', d['users_total'], Icons.people_rounded, cs.primary),
      ('عضو جدید امروز', d['users_today'], Icons.person_add_alt_1_rounded, const Color(0xFF16A34A)),
      ('۷ روز اخیر', d['users_week'], Icons.trending_up_rounded, const Color(0xFF0EA5E9)),
      ('مسدود شده', d['users_blocked'], Icons.block_rounded, const Color(0xFFEF4444)),
      ('خدمات', d['services'], Icons.apps_rounded, const Color(0xFFF59E0B)),
      ('بنرها', d['banners'], Icons.view_carousel_rounded, const Color(0xFFEC4899)),
    ];
    final recent = (d['recent_users'] as List).cast<Map>();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              for (final t in tiles)
                SoftCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconBadge(t.$3, size: 36, color: t.$4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(fa(t.$2), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(t.$1,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: exportUsersCsv,
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('خروجی کامل کاربران (CSV / اکسل)'),
          ),
          const SectionHeader('آخرین کاربران'),
          if (recent.isEmpty)
            const EmptyState(Icons.people_outline, 'هنوز کاربری ثبت‌نام نکرده است')
          else
            SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Column(
                children: [
                  for (final u in recent)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.primary.withAlpha(30),
                        child: Icon(Icons.person_rounded, color: cs.primary),
                      ),
                      title: Text((u['name'] ?? '').toString().isEmpty ? 'بدون نام' : u['name'].toString()),
                      subtitle: Text(fa(localPhone(u['phone'])), textDirection: TextDirection.ltr, textAlign: TextAlign.right),
                      trailing: Text(faDate(u['created_at'], time: false), style: const TextStyle(fontSize: 11.5)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
