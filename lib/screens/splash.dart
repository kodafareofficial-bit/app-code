import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final minWait = Future.delayed(const Duration(milliseconds: 2400));
    // محتوای جدید (لوگو، رنگ‌ها، بنرها ...) هنگام اسپلش از سرور گرفته می‌شود
    final load = app.refresh(silent: true).timeout(const Duration(seconds: 5), onTimeout: () {});
    await Future.wait([minWait, load]);
    if (!mounted) return;
    String route = '/login';
    if (app.mode == 'admin' && app.isAdminLoggedIn) {
      route = '/admin';
    } else if (app.isUserLoggedIn) {
      route = '/home';
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = hexColor(app.s('splash_color'), const Color(0xFF0F0B2E));
    final accent = hexColor(app.s('accent_color'), const Color(0xFF00C2A8));
    final primary = hexColor(app.s('primary_color'), const Color(0xFF6C4DFF));
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -90,
            child: _blob(primary.withAlpha(90), 300),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _blob(accent.withAlpha(60), 320),
          ),
          Center(
            child: FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: Tween(begin: 0.8, end: 1.0).animate(fade),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(34),
                        boxShadow: [BoxShadow(color: primary.withAlpha(120), blurRadius: 50, spreadRadius: 2)],
                      ),
                      child: const AppLogo(size: 118, radius: 34),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      app.s('company_name'),
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      app.s('company_name_en'),
                      style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14, letterSpacing: 3),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      app.s('splash_text'),
                      style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 56,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c),
      );
}
