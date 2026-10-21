import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../ui/widgets.dart';

/// دریافت خروجی CSV کاربران و اشتراک‌گذاری/ذخیره آن (قابل باز شدن در اکسل)
Future<void> exportUsersCsv() async {
  try {
    toast('در حال تهیه خروجی...');
    final bytes = await Api.downloadUsersCsv();
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/codeoffer-users-${DateTime.now().millisecondsSinceEpoch}.csv');
    await f.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(f.path, mimeType: 'text/csv')], subject: 'خروجی کاربران کد آفر');
  } on ApiException catch (e) {
    toast(e.message, error: true);
  } catch (_) {
    toast('ذخیره یا اشتراک‌گذاری فایل ممکن نشد', error: true);
  }
}

class UsersPage extends StatefulWidget {
  final bool active;
  const UsersPage({super.key, required this.active});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _q = TextEditingController();
  final List<Map<String, dynamic>> _items = [];
  int _total = 0;
  int _page = 1;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  Timer? _debounce;

  @override
  void didUpdateWidget(covariant UsersPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load(reset: true);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(reset: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _page = 1;
    });
    try {
      final r = await Api.get('/api/admin/users?page=$_page&size=30&q=${Uri.encodeQueryComponent(_q.text.trim())}', admin: true);
      final list = (r['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        if (reset) _items.clear();
        _items.addAll(list);
        _total = r['total'] as int;
        _loaded = true;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _q,
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 450), () => _load(reset: true));
                },
                decoration: fieldDeco(context, 'جستجو: شماره، نام یا ایمیل', icon: Icons.search_rounded),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'خروجی CSV',
              onPressed: exportUsersCsv,
              icon: const Icon(Icons.file_download_outlined),
            ),
          ]),
        ),
        if (_loaded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('${fa(_total)} کاربر', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: _error != null && _items.isEmpty
                ? ListView(children: [const SizedBox(height: 80), EmptyState(Icons.wifi_off_rounded, _error!)])
                : _loaded && _items.isEmpty
                    ? ListView(children: const [SizedBox(height: 80), EmptyState(Icons.people_outline, 'کاربری یافت نشد')])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: _items.length + (_items.length < _total ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          if (i >= _items.length) {
                            return Padding(
                              padding: const EdgeInsets.all(8),
                              child: OutlinedButton(
                                onPressed: _loading
                                    ? null
                                    : () {
                                        _page++;
                                        _load();
                                      },
                                child: _loading
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('بارگذاری بیشتر'),
                              ),
                            );
                          }
                          final u = _items[i];
                          final blocked = u['blocked'] == 1;
                          final name = (u['name'] ?? '').toString();
                          return SoftCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            onTap: () async {
                              final changed = await showUserSheet(context, u);
                              if (changed == true) _load(reset: true);
                            },
                            child: Row(children: [
                              CircleAvatar(
                                backgroundColor: (blocked ? Colors.red : cs.primary).withAlpha(30),
                                child: Icon(blocked ? Icons.block_rounded : Icons.person_rounded,
                                    color: blocked ? Colors.red : cs.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(name.isEmpty ? 'بدون نام' : name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(fa(localPhone(u['phone'])),
                                      textDirection: TextDirection.ltr, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                                ]),
                              ),
                              Text(faDate(u['created_at'], time: false), style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                            ]),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

Future<bool?> showUserSheet(BuildContext context, Map<String, dynamic> u) {
  final name = TextEditingController(text: (u['name'] ?? '').toString());
  final email = TextEditingController(text: (u['email'] ?? '').toString());
  final city = TextEditingController(text: (u['city'] ?? '').toString());
  final bio = TextEditingController(text: (u['bio'] ?? '').toString());
  bool blocked = u['blocked'] == 1;
  bool busy = false;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text(fa(localPhone(u['phone'])),
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                ),
                IconButton.filledTonal(
                  tooltip: 'تماس',
                  onPressed: () => openLink(localPhone(u['phone'])),
                  icon: const Icon(Icons.call_outlined),
                ),
              ]),
              Text('عضویت: ${faDate(u['created_at'])}   |   آخرین ورود: ${faDate(u['last_login'])}',
                  style: TextStyle(fontSize: 12, color: Theme.of(c).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              TextField(controller: name, decoration: fieldDeco(c, 'نام', icon: Icons.person_outline)),
              const SizedBox(height: 10),
              TextField(
                controller: email,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                decoration: fieldDeco(c, 'ایمیل', icon: Icons.mail_outline_rounded),
              ),
              const SizedBox(height: 10),
              TextField(controller: city, decoration: fieldDeco(c, 'شهر', icon: Icons.location_city_rounded)),
              const SizedBox(height: 10),
              TextField(controller: bio, maxLines: 3, decoration: fieldDeco(c, 'توضیحات', icon: Icons.notes_rounded)),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('مسدود کردن کاربر'),
                subtitle: const Text('کاربر مسدود نمی‌تواند وارد شود'),
                value: blocked,
                onChanged: (v) => setS(() => blocked = v),
              ),
              const SizedBox(height: 6),
              BusyButton(
                busy: busy,
                label: 'ذخیره تغییرات',
                icon: Icons.check_rounded,
                onPressed: () async {
                  setS(() => busy = true);
                  try {
                    await Api.put('/api/admin/users/${u['id']}', {
                      'name': name.text.trim(),
                      'email': email.text.trim(),
                      'city': city.text.trim(),
                      'bio': bio.text.trim(),
                      'blocked': blocked,
                    }, admin: true);
                    if (c.mounted) Navigator.pop(c, true);
                  } on ApiException catch (e) {
                    toast(e.message, error: true);
                    setS(() => busy = false);
                  }
                },
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('حذف کاربر'),
                onPressed: () async {
                  if (!await confirmDialog(c, 'حذف کاربر', 'این کاربر برای همیشه حذف شود؟', ok: 'حذف', danger: true)) return;
                  try {
                    await Api.delete('/api/admin/users/${u['id']}', admin: true);
                    if (c.mounted) Navigator.pop(c, true);
                  } on ApiException catch (e) {
                    toast(e.message, error: true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
