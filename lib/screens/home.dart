import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'services.dart';

class HomeTab extends StatelessWidget {
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenServices;
  const HomeTab({super.key, required this.onOpenNotifications, required this.onOpenServices});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final primary = hexColor(app.s('primary_color'), const Color(0xFF6C4DFF));
        final accent = hexColor(app.s('accent_color'), const Color(0xFF00C2A8));
        final name = (app.user?['name'] ?? '').toString();
        final cs = Theme.of(context).colorScheme;
        final topPad = MediaQuery.of(context).padding.top;
        final shown = app.services.take(6).toList();

        return RefreshIndicator(
          onRefresh: () async {
            try {
              await app.refresh();
            } on ApiException catch (e) {
              toast(e.message, error: true);
            }
          },
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ---- هدر ----
              Container(
                padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 26),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [primary, Color.lerp(primary, accent, 0.7)!],
                  ),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
                ),
                child: Row(
                  children: [
                    const AppLogo(size: 46, radius: 14),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.isEmpty ? 'خوش آمدید 👋' : 'سلام $name 👋',
                              style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 12.5)),
                          const SizedBox(height: 2),
                          Text(app.s('company_name'),
                              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(backgroundColor: Colors.white.withAlpha(45)),
                      onPressed: onOpenNotifications,
                      icon: Badge(
                        isLabelVisible: app.unread > 0,
                        label: Text('${app.unread}'),
                        child: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---- بنرها ----
                    if (app.banners.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      BannerCarousel(banners: app.banners),
                    ],

                    // ---- دسته‌ها ----
                    if (app.categories.isNotEmpty) ...[
                      const SectionHeader('دسته‌بندی خدمات'),
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: app.categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, i) {
                            final c = app.categories[i];
                            return SizedBox(
                              width: 88,
                              child: SoftCard(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                onTap: onOpenServices,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(iconOf(c['icon']), color: cs.primary),
                                    const SizedBox(height: 6),
                                    Text(c['title'].toString(),
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11.5, height: 1.3)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // ---- خدمات ----
                    SectionHeader('خدمات ما',
                        trailing: TextButton(onPressed: onOpenServices, child: const Text('مشاهده همه'))),
                    if (shown.isEmpty)
                      const EmptyState(Icons.inventory_2_outlined, 'هنوز خدمتی ثبت نشده است')
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: shown.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.92,
                        ),
                        itemBuilder: (_, i) => ServiceCard(service: shown[i]),
                      ),

                    // ---- درباره ----
                    if (app.s('about').isNotEmpty) ...[
                      const SectionHeader('درباره ما'),
                      SoftCard(
                        child: Text(app.s('about'), style: TextStyle(height: 1.9, color: cs.onSurfaceVariant)),
                      ),
                    ],

                    // ---- شبکه‌های اجتماعی ----
                    if (app.socials.isNotEmpty) ...[
                      const SectionHeader('ما را دنبال کنید'),
                      SocialRow(socials: app.socials),
                    ],
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class BannerCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> banners;
  const BannerCarousel({super.key, required this.banners});
  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _pc = PageController(viewportFraction: 0.96);
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.banners.length < 2 || !_pc.hasClients) return;
      final next = (_i + 1) % widget.banners.length;
      _pc.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = widget.banners.length;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 7.5,
          child: PageView.builder(
            controller: _pc,
            itemCount: n,
            onPageChanged: (v) => setState(() => _i = v),
            itemBuilder: (_, i) {
              final b = widget.banners[i];
              final link = (b['link'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: link.isEmpty ? null : () => openLink(link),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      NetImage(b['image']?.toString(), radius: 22),
                      if ((b['title'] ?? '').toString().isNotEmpty)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 22, 14, 12),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withAlpha(150)],
                              ),
                            ),
                            child: Text(b['title'].toString(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (n > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              n,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _i ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _i ? cs.primary : cs.outlineVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class SocialRow extends StatelessWidget {
  final List<Map<String, dynamic>> socials;
  const SocialRow({super.key, required this.socials});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final s in socials)
          Tooltip(
            message: kSocialNames[s['platform']] ?? s['platform'].toString(),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => openLink(s['url'].toString()),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: cs.primary.withAlpha(24),
                  border: Border.all(color: cs.primary.withAlpha(60)),
                ),
                child: Icon(kSocialIcons[s['platform']] ?? Icons.link_rounded, color: cs.primary),
              ),
            ),
          ),
      ],
    );
  }
}
