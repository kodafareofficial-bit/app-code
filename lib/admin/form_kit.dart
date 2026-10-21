import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

enum FType { text, multiline, number, image, icon, bool, category, platform }

class FieldSpec {
  final String key;
  final String label;
  final FType type;
  final bool required;
  final String? hint;
  final bool ltr;
  const FieldSpec(this.key, this.label, this.type, {this.required = false, this.hint, this.ltr = false});
}

Future<String?> pickAndUploadImage() async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 88);
  if (x == null) return null;
  return Api.uploadImage(x);
}

/// فرم عمومی افزودن/ویرایش. در صورت ذخیره موفق true برمی‌گرداند.
Future<bool?> showEntityForm(
  BuildContext context, {
  required String title,
  required String endpoint, // مثل services
  required List<FieldSpec> fields,
  Map<String, dynamic>? item,
  List<Map<String, dynamic>> categories = const [],
}) {
  final vals = <String, dynamic>{};
  final ctrls = <String, TextEditingController>{};
  for (final f in fields) {
    final cur = item?[f.key];
    switch (f.type) {
      case FType.text:
      case FType.multiline:
      case FType.number:
        ctrls[f.key] = TextEditingController(text: cur == null ? '' : cur.toString());
        break;
      case FType.bool:
        vals[f.key] = item == null ? true : (cur == 1 || cur == true);
        break;
      default:
        vals[f.key] = cur;
    }
  }
  bool busy = false;
  bool uploading = false;

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => StatefulBuilder(
      builder: (c, setS) {
        Future<void> save() async {
          final body = <String, dynamic>{};
          for (final f in fields) {
            dynamic v;
            switch (f.type) {
              case FType.text:
              case FType.multiline:
                v = ctrls[f.key]!.text.trim();
                break;
              case FType.number:
                v = int.tryParse(_en(ctrls[f.key]!.text.trim())) ?? 0;
                break;
              default:
                v = vals[f.key];
            }
            if (f.required && (v == null || v.toString().isEmpty)) {
              toast('«${f.label}» را تکمیل کنید', error: true);
              return;
            }
            if (v != null || f.type == FType.category) body[f.key] = v;
          }
          setS(() => busy = true);
          try {
            if (item == null) {
              await Api.post('/api/admin/$endpoint', body, admin: true);
            } else {
              await Api.put('/api/admin/$endpoint/${item['id']}', body, admin: true);
            }
            if (c.mounted) Navigator.pop(c, true);
          } on ApiException catch (e) {
            toast(e.message, error: true);
            setS(() => busy = false);
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                for (final f in fields) ...[
                  _buildField(c, f, ctrls, vals, categories, setS, uploading, (v) => uploading = v),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 6),
                BusyButton(busy: busy || uploading, onPressed: save, label: 'ذخیره', icon: Icons.check_rounded),
              ],
            ),
          ),
        );
      },
    ),
  );
}

String _en(String s) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final i = fa.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return b.toString();
}

Widget _buildField(
  BuildContext c,
  FieldSpec f,
  Map<String, TextEditingController> ctrls,
  Map<String, dynamic> vals,
  List<Map<String, dynamic>> categories,
  void Function(void Function()) setS,
  bool uploading,
  void Function(bool) setUploading,
) {
  final cs = Theme.of(c).colorScheme;
  switch (f.type) {
    case FType.text:
    case FType.multiline:
    case FType.number:
      return TextField(
        controller: ctrls[f.key],
        maxLines: f.type == FType.multiline ? 4 : 1,
        keyboardType: f.type == FType.number
            ? TextInputType.number
            : f.type == FType.multiline
                ? TextInputType.multiline
                : (f.ltr ? TextInputType.url : TextInputType.text),
        textDirection: f.ltr ? TextDirection.ltr : null,
        textAlign: f.ltr ? TextAlign.left : TextAlign.start,
        decoration: fieldDeco(c, f.label, hint: f.hint),
      );
    case FType.bool:
      return SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Text(f.label),
        value: vals[f.key] == true,
        onChanged: (v) => setS(() => vals[f.key] = v),
      );
    case FType.image:
      final url = (vals[f.key] ?? '').toString();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.label, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          if (url.isNotEmpty) NetImage(url, height: 140, width: double.infinity, radius: 16),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: uploading
                    ? null
                    : () async {
                        setUploading(true);
                        setS(() {});
                        try {
                          final u = await pickAndUploadImage();
                          if (u != null) vals[f.key] = u;
                        } on ApiException catch (e) {
                          toast(e.message, error: true);
                        } finally {
                          setUploading(false);
                          if (c.mounted) setS(() {});
                        }
                      },
                icon: uploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_rounded),
                label: Text(url.isEmpty ? 'انتخاب تصویر' : 'تغییر تصویر'),
              ),
            ),
            if (url.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setS(() => vals[f.key] = ''),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ]),
        ],
      );
    case FType.icon:
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.label, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in kIcons.entries)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setS(() => vals[f.key] = e.key),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: vals[f.key] == e.key ? cs.primary : cs.surfaceContainerHighest,
                    ),
                    child: Icon(e.value, color: vals[f.key] == e.key ? cs.onPrimary : cs.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ],
      );
    case FType.category:
      final ids = categories.map((e) => e['id']).toList();
      final cur = ids.contains(vals[f.key]) ? vals[f.key] : null;
      return DropdownButtonFormField<dynamic>(
        value: cur,
        decoration: fieldDeco(c, f.label),
        items: [
          const DropdownMenuItem<dynamic>(value: null, child: Text('بدون دسته')),
          for (final e in categories) DropdownMenuItem<dynamic>(value: e['id'], child: Text(e['title'].toString())),
        ],
        onChanged: (v) => setS(() => vals[f.key] = v),
      );
    case FType.platform:
      final cur = kSocialNames.containsKey(vals[f.key]) ? vals[f.key] as String : null;
      return DropdownButtonFormField<String>(
        value: cur,
        decoration: fieldDeco(c, f.label),
        items: [
          for (final e in kSocialNames.entries)
            DropdownMenuItem(
              value: e.key,
              child: Row(children: [Icon(kSocialIcons[e.key], size: 18), const SizedBox(width: 8), Text(e.value)]),
            ),
        ],
        onChanged: (v) => setS(() => vals[f.key] = v),
      );
  }
}

/// ورودی رنگ با پیش‌نمایش و چند رنگ آماده
class ColorField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const ColorField({super.key, required this.label, required this.controller});

  static const presets = [
    '#6C4DFF', '#2563EB', '#0EA5E9', '#00C2A8', '#16A34A', '#F59E0B', '#EF4444', '#EC4899', '#0F0B2E', '#111827',
  ];

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (c, setS) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            onChanged: (_) => setS(() {}),
            decoration: fieldDeco(c, label, hint: '#6C4DFF').copyWith(
              suffixIcon: Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: hexColor(controller.text, Colors.grey),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.black12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in presets)
                GestureDetector(
                  onTap: () => setS(() => controller.text = p),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: hexColor(p, Colors.grey),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
