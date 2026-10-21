import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../ui/widgets.dart';

class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});
  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  int? _cat; // null = همه
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final q = _q.text.trim();
        final items = app.services.where((s) {
          if (_cat != null && s['category_id'] != _cat) return false;
          if (q.isEmpty) return true;
          return s['title'].toString().contains(q) || s['description'].toString().contains(q);
        }).toList();

        return Scaffold(
          appBar: AppBar(title: const Text('خدمات')),
          body: RefreshIndicator(
            onRefresh: () async {
              try {
                await app.refresh();
              } on ApiException catch (e) {
                toast(e.message, error: true);
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                TextField(
                  controller: _q,
                  onChanged: (_) => setState(() {}),
                  decoration: fieldDeco(context, 'جستجو در خدمات', icon: Icons.search_rounded),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: const Text('همه'),
                          selected: _cat == null,
                          onSelected: (_) => setState(() => _cat = null),
                        ),
                      ),
                      for (final c in app.categories)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(
                            avatar: Icon(iconOf(c['icon']), size: 16),
                            label: Text(c['title'].toString()),
                            selected: _cat == c['id'],
                            onSelected: (_) => setState(() => _cat = c['id'] as int),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  const EmptyState(Icons.search_off_rounded, 'خدمتی پیدا نشد')
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.92,
                    ),
                    itemBuilder: (_, i) => ServiceCard(service: items[i]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  const ServiceCard({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final price = (service['price'] ?? '').toString();
    return SoftCard(
      onTap: () => showServiceDetail(context, service),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((service['image'] ?? '').toString().isNotEmpty)
            NetImage(service['image'].toString(), width: 48, height: 48, radius: 15, fallbackIcon: iconOf(service['icon']))
          else
            IconBadge(iconOf(service['icon'])),
          const SizedBox(height: 12),
          Text(service['title'].toString(),
              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
          const SizedBox(height: 4),
          Expanded(
            child: Text(service['description'].toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.6, color: cs.onSurfaceVariant)),
          ),
          if (price.isNotEmpty)
            Text(price, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary)),
        ],
      ),
    );
  }
}

void showServiceDetail(BuildContext context, Map<String, dynamic> s) {
  final cs = Theme.of(context).colorScheme;
  final price = (s['price'] ?? '').toString();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        children: [
          if ((s['image'] ?? '').toString().isNotEmpty) ...[
            NetImage(s['image'].toString(), height: 180, width: double.infinity, radius: 20),
            const SizedBox(height: 16),
          ] else
            Align(alignment: Alignment.centerRight, child: IconBadge(iconOf(s['icon']), size: 64)),
          const SizedBox(height: 12),
          Text(s['title'].toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          if (price.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: cs.primary.withAlpha(25), borderRadius: BorderRadius.circular(12)),
              child: Text(price, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 14),
          Text(s['description'].toString(), style: TextStyle(height: 2, color: cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('درخواست مشاوره'),
            onPressed: () {
              final phone = app.s('support_phone');
              final tg = app.socials.where((x) => x['platform'] == 'telegram' || x['platform'] == 'whatsapp');
              if (phone.isNotEmpty) {
                openLink(phone);
              } else if (tg.isNotEmpty) {
                openLink(tg.first['url'].toString());
              } else if (app.s('support_email').isNotEmpty) {
                openLink(app.s('support_email'));
              } else {
                toast('راه ارتباطی ثبت نشده است');
              }
            },
          ),
        ],
      ),
    ),
  );
}
