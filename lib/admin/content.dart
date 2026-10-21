import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../ui/widgets.dart';
import 'form_kit.dart';

class ContentPage extends StatelessWidget {
  const ContentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'خدمات'),
              Tab(text: 'دسته‌ها'),
              Tab(text: 'بنرها'),
              Tab(text: 'شبکه‌های اجتماعی'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                EntityList(
                  endpoint: 'services',
                  addLabel: 'افزودن خدمت',
                  withCategories: true,
                  fields: const [
                    FieldSpec('title', 'عنوان خدمت', FType.text, required: true),
                    FieldSpec('description', 'توضیحات', FType.multiline),
                    FieldSpec('category_id', 'دسته‌بندی', FType.category),
                    FieldSpec('price', 'قیمت / برچسب (مثلاً از ۵ میلیون تومان)', FType.text),
                    FieldSpec('icon', 'آیکن', FType.icon),
                    FieldSpec('image', 'تصویر (اختیاری)', FType.image),
                    FieldSpec('sort', 'ترتیب نمایش (عدد کمتر = بالاتر)', FType.number),
                    FieldSpec('active', 'نمایش در اپ', FType.bool),
                  ],
                  titleOf: (i) => i['title'].toString(),
                  subtitleOf: (i) => i['price'].toString().isEmpty ? i['description'].toString() : i['price'].toString(),
                  leadingOf: (i) => IconBadge(iconOf(i['icon']), size: 42),
                ),
                EntityList(
                  endpoint: 'categories',
                  addLabel: 'افزودن دسته',
                  fields: const [
                    FieldSpec('title', 'عنوان دسته', FType.text, required: true),
                    FieldSpec('icon', 'آیکن', FType.icon),
                    FieldSpec('sort', 'ترتیب نمایش', FType.number),
                    FieldSpec('active', 'نمایش در اپ', FType.bool),
                  ],
                  titleOf: (i) => i['title'].toString(),
                  subtitleOf: (i) => '',
                  leadingOf: (i) => IconBadge(iconOf(i['icon']), size: 42),
                ),
                EntityList(
                  endpoint: 'banners',
                  addLabel: 'افزودن بنر',
                  fields: const [
                    FieldSpec('image', 'تصویر بنر (پیشنهادی ۱۶:۷)', FType.image, required: true),
                    FieldSpec('title', 'عنوان روی بنر (اختیاری)', FType.text),
                    FieldSpec('link', 'لینک هنگام لمس (اختیاری)', FType.text, ltr: true, hint: 'https://...'),
                    FieldSpec('sort', 'ترتیب نمایش', FType.number),
                    FieldSpec('active', 'نمایش در اپ', FType.bool),
                  ],
                  titleOf: (i) => i['title'].toString().isEmpty ? 'بنر ${i['id']}' : i['title'].toString(),
                  subtitleOf: (i) => i['link'].toString(),
                  leadingOf: (i) => NetImage(i['image']?.toString(), width: 64, height: 42, radius: 10),
                ),
                EntityList(
                  endpoint: 'socials',
                  addLabel: 'افزودن شبکه اجتماعی',
                  fields: const [
                    FieldSpec('platform', 'پلتفرم', FType.platform, required: true),
                    FieldSpec('url', 'لینک یا شماره', FType.text, required: true, ltr: true, hint: 'https://t.me/yourid'),
                    FieldSpec('sort', 'ترتیب نمایش', FType.number),
                  ],
                  titleOf: (i) => kSocialNames[i['platform']] ?? i['platform'].toString(),
                  subtitleOf: (i) => i['url'].toString(),
                  leadingOf: (i) => IconBadge(kSocialIcons[i['platform']] ?? Icons.link_rounded, size: 42),
                  hasActive: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EntityList extends StatefulWidget {
  final String endpoint;
  final String addLabel;
  final List<FieldSpec> fields;
  final String Function(Map<String, dynamic>) titleOf;
  final String Function(Map<String, dynamic>) subtitleOf;
  final Widget Function(Map<String, dynamic>) leadingOf;
  final bool withCategories;
  final bool hasActive;
  const EntityList({
    super.key,
    required this.endpoint,
    required this.addLabel,
    required this.fields,
    required this.titleOf,
    required this.subtitleOf,
    required this.leadingOf,
    this.withCategories = false,
    this.hasActive = true,
  });
  @override
  State<EntityList> createState() => _EntityListState();
}

class _EntityListState extends State<EntityList> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _cats = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  List<Map<String, dynamic>> _asList(dynamic v) =>
      (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Api.get('/api/admin/${widget.endpoint}', admin: true);
      _items = _asList((r as Map)['items']);
      if (widget.withCategories) {
        final c = await Api.get('/api/admin/categories', admin: true);
        _cats = _asList((c as Map)['items']);
      }
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final ok = await showEntityForm(
      context,
      title: item == null ? widget.addLabel : 'ویرایش',
      endpoint: widget.endpoint,
      fields: widget.fields,
      item: item,
      categories: _cats,
    );
    if (ok == true) {
      await _load();
      app.refresh(silent: true); // تغییرات برای کاربران هم اعمال می‌شود
      toast('ذخیره شد و برای کاربران اعمال می‌شود');
    }
  }

  Future<void> _delete(Map<String, dynamic> i) async {
    if (!await confirmDialog(context, 'حذف', '«${widget.titleOf(i)}» حذف شود؟', ok: 'حذف', danger: true)) return;
    try {
      await Api.delete('/api/admin/${widget.endpoint}/${i['id']}', admin: true);
      await _load();
      app.refresh(silent: true);
    } on ApiException catch (e) {
      toast(e.message, error: true);
    }
  }

  Future<void> _toggle(Map<String, dynamic> i, bool v) async {
    try {
      await Api.put('/api/admin/${widget.endpoint}/${i['id']}', {'active': v}, admin: true);
      await _load();
      app.refresh(silent: true);
    } on ApiException catch (e) {
      toast(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: Text(widget.addLabel),
      ),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(children: [const SizedBox(height: 80), EmptyState(Icons.wifi_off_rounded, _error!)])
                  : _items.isEmpty
                      ? ListView(children: const [SizedBox(height: 80), EmptyState(Icons.inbox_outlined, 'هنوز موردی اضافه نشده است')])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, idx) {
                            final i = _items[idx];
                            final active = !widget.hasActive || i['active'] == 1;
                            return Opacity(
                              opacity: active ? 1 : 0.55,
                              child: SoftCard(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                onTap: () => _openForm(i),
                                child: Row(children: [
                                  widget.leadingOf(i),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(widget.titleOf(i), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      if (widget.subtitleOf(i).isNotEmpty)
                                        Text(widget.subtitleOf(i),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textDirection: widget.endpoint == 'socials' || widget.endpoint == 'banners' ? TextDirection.ltr : null,
                                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                    ]),
                                  ),
                                  if (widget.hasActive) Switch(value: i['active'] == 1, onChanged: (v) => _toggle(i, v)),
                                  IconButton(
                                    onPressed: () => _delete(i),
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    color: const Color(0xFFC62828),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
            ),
    );
  }
}
