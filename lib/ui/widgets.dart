import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/app_state.dart';

const Map<String, IconData> kIcons = {
  'code': Icons.code_rounded,
  'phone_android': Icons.phone_android_rounded,
  'language': Icons.language_rounded,
  'support_agent': Icons.support_agent_rounded,
  'apps': Icons.apps_rounded,
  'design_services': Icons.design_services_rounded,
  'cloud': Icons.cloud_outlined,
  'shopping_cart': Icons.shopping_cart_outlined,
  'security': Icons.security_rounded,
  'storage': Icons.storage_rounded,
  'brush': Icons.brush_rounded,
  'analytics': Icons.analytics_outlined,
  'bolt': Icons.bolt_rounded,
  'rocket_launch': Icons.rocket_launch_outlined,
  'palette': Icons.palette_outlined,
  'build': Icons.build_outlined,
  'campaign': Icons.campaign_outlined,
  'school': Icons.school_outlined,
  'star': Icons.star_outline_rounded,
  'chat': Icons.chat_bubble_outline_rounded,
  'web': Icons.web_rounded,
  'memory': Icons.memory_rounded,
  'lock': Icons.lock_outline_rounded,
  'payments': Icons.payments_outlined,
};
IconData iconOf(dynamic n) => kIcons[n?.toString()] ?? Icons.widgets_rounded;

const Map<String, IconData> kSocialIcons = {
  'instagram': Icons.camera_alt_outlined,
  'telegram': Icons.send_rounded,
  'whatsapp': Icons.chat_rounded,
  'linkedin': Icons.work_outline_rounded,
  'github': Icons.code_rounded,
  'youtube': Icons.play_circle_outline_rounded,
  'twitter': Icons.alternate_email_rounded,
  'eitaa': Icons.forum_outlined,
  'aparat': Icons.smart_display_outlined,
  'website': Icons.public_rounded,
  'phone': Icons.call_outlined,
  'email': Icons.mail_outline_rounded,
};
const Map<String, String> kSocialNames = {
  'instagram': 'اینستاگرام',
  'telegram': 'تلگرام',
  'whatsapp': 'واتس‌اپ',
  'linkedin': 'لینکدین',
  'github': 'گیت‌هاب',
  'youtube': 'یوتیوب',
  'twitter': 'ایکس (توییتر)',
  'eitaa': 'ایتا',
  'aparat': 'آپارات',
  'website': 'وب‌سایت',
  'phone': 'تلفن',
  'email': 'ایمیل',
};

void toast(String msg, {bool error = false}) {
  final m = app.messengerKey.currentState;
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFC62828) : null,
    ));
}

Future<void> openLink(String raw) async {
  var u = raw.trim();
  if (u.isEmpty) return;
  if (RegExp(r'^[\d+\s-]+$').hasMatch(u)) {
    u = 'tel:${u.replaceAll(RegExp(r'[\s-]'), '')}';
  } else if (!u.contains(':')) {
    u = u.contains('@') && !u.contains('/') ? 'mailto:$u' : 'https://$u';
  }
  try {
    final ok = await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    if (!ok) toast('باز کردن لینک ممکن نشد', error: true);
  } catch (_) {
    toast('باز کردن لینک ممکن نشد', error: true);
  }
}

class NetImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double? width, height;
  final double radius;
  final IconData fallbackIcon;
  const NetImage(this.url,
      {super.key,
      this.fit = BoxFit.cover,
      this.width,
      this.height,
      this.radius = 0,
      this.fallbackIcon = Icons.image_outlined});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: width,
      height: height,
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: cs.onSurfaceVariant.withAlpha(120)),
    );
    final full = Api.abs(url);
    final child = full.isEmpty
        ? placeholder
        : Image.network(
            full,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => placeholder,
            loadingBuilder: (c, w, p) => p == null ? w : placeholder,
          );
    return radius > 0 ? ClipRRect(borderRadius: BorderRadius.circular(radius), child: child) : child;
  }
}

/// لوگوی برند: اگر مدیر لوگو آپلود کرده باشد همان، وگرنه لوگوی داخل اپ
class AppLogo extends StatelessWidget {
  final double size;
  final double radius;
  const AppLogo({super.key, this.size = 64, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final logo = app.s('logo');
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: logo.isNotEmpty
          ? NetImage(logo, width: size, height: size, fit: BoxFit.contain)
          : Image.asset('assets/logo.png', width: size, height: size, fit: BoxFit.cover),
    );
  }
}

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: color ?? (dark ? const Color(0xFF1A1733) : Colors.white),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cs.outlineVariant.withAlpha(dark ? 70 : 110)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 54, color: c.withAlpha(110)),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: c)),
        ]),
      ),
    );
  }
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  const IconBadge(this.icon, {super.key, this.size = 48, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [c.withAlpha(60), c.withAlpha(20)],
        ),
      ),
      child: Icon(icon, color: c, size: size * 0.5),
    );
  }
}

class BusyButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  const BusyButton({super.key, required this.busy, required this.onPressed, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Text(label),
            ]),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, String title, String body, {String ok = 'تایید', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(90, 44),
            backgroundColor: danger ? const Color(0xFFC62828) : null,
          ),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

InputDecoration fieldDeco(BuildContext context, String label, {IconData? icon, String? hint, Widget? suffix}) {
  final cs = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon),
    suffixIcon: suffix,
    filled: true,
    fillColor: dark ? const Color(0xFF1A1733) : Colors.white,
    enabledBorder: b(cs.outlineVariant),
    focusedBorder: b(cs.primary, 1.6),
    border: b(cs.outlineVariant),
  );
}
