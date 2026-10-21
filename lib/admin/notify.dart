import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../ui/widgets.dart';
import 'form_kit.dart';

class NotifyPage extends StatefulWidget {
  final bool active;
  const NotifyPage({super.key, required this.active});
  @override
  State<NotifyPage> createState() => _NotifyPageState();
}

class _NotifyPageState extends State<NotifyPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _link = TextEditingController();
  String _image = '';
  bool _busy = false;
  bool _uploading = false;
  List<Map<String, dynamic>> _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant NotifyPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Api.get('/api/admin/notifications', admin: true);
      if (!mounted) return;
      setState(() {
        _items = (r['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty) {
      toast('عنوان اعلان را وارد کنید', error: true);
      return;
    }
    if (!await confirmDialog(context, 'ارسال اعلان', 'این اعلان برای همه کاربران ارسال شود؟', ok: 'ارسال')) return;
    setState(() => _busy = true);
    try {
      await Api.post('/api/admin/notifications', {
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'image': _image,
        'link': _link.text.trim(),
      }, admin: true);
      _title.clear();
      _body.clear();
      _link.clear();
      _image = '';
      toast('اعلان ارسال شد؛ کاربران در چند ثانیه دریافت می‌کنند');
      await _load();
    } on ApiException catch (e) {
      toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('اعلان جدید', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(controller: _title, decoration: fieldDeco(context, 'عنوان', icon: Icons.title_rounded)),
                const SizedBox(height: 10),
                TextField(controller: _body, maxLines: 4, decoration: fieldDeco(context, 'متن پیام')),
                const SizedBox(height: 10),
                TextField(
                  controller: _link,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  decoration: fieldDeco(context, 'لینک (اختیاری)', icon: Icons.link_rounded, hint: 'https://...'),
                ),
                const SizedBox(height: 10),
                if (_image.isNotEmpty) ...[
                  NetImage(_image, height: 130, width: double.infinity, radius: 14),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: _uploading
                      ? null
                      : () async {
                          setState(() => _uploading = true);
                          try {
                            final u = await pickAndUploadImage();
                            if (u != null) _image = u;
                          } on ApiException catch (e) {
                            toast(e.message, error: true);
                          } finally {
                            if (mounted) setState(() => _uploading = false);
                          }
                        },
                  icon: _uploading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.image_outlined),
                  label: Text(_image.isEmpty ? 'افزودن تصویر (اختیاری)' : 'تغییر تصویر'),
                ),
                const SizedBox(height: 14),
                BusyButton(busy: _busy, onPressed: _send, label: 'ارسال به همه کاربران', icon: Icons.send_rounded),
              ],
            ),
          ),
          const SectionHeader('اعلان‌های ارسال‌شده'),
          if (_error != null)
            EmptyState(Icons.wifi_off_rounded, _error!)
          else if (_items.isEmpty)
            const EmptyState(Icons.notifications_off_outlined, 'هنوز اعلانی ارسال نشده است')
          else
            for (final n in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SoftCard(
                  child: Row(children: [
                    IconBadge(Icons.campaign_rounded, size: 40, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (n['body'].toString().isNotEmpty)
                          Text(n['body'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                        Text(faDate(n['created_at']), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      ]),
                    ),
                    IconButton(
                      color: const Color(0xFFC62828),
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        if (!await confirmDialog(context, 'حذف اعلان', 'این اعلان حذف شود؟', ok: 'حذف', danger: true)) return;
                        try {
                          await Api.delete('/api/admin/notifications/${n['id']}', admin: true);
                          _load();
                        } on ApiException catch (e) {
                          toast(e.message, error: true);
                        }
                      },
                    ),
                  ]),
                ),
              ),
        ],
      ),
    );
  }
}
