import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'admin/admin_shell.dart';
import 'core/app_state.dart';
import 'screens/admin_login.dart';
import 'screens/login.dart';
import 'screens/splash.dart';
import 'screens/user_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await app.init();
  runApp(const CodeOfferApp());
}

class CodeOfferApp extends StatefulWidget {
  const CodeOfferApp({super.key});
  @override
  State<CodeOfferApp> createState() => _CodeOfferAppState();
}

class _CodeOfferAppState extends State<CodeOfferApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    app.startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    app.stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      app.refresh(silent: true);
      app.startPolling();
    } else if (state == AppLifecycleState.paused) {
      app.stopPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final primary = hexColor(app.s('primary_color'), const Color(0xFF6C4DFF));
        return MaterialApp(
          title: app.s('company_name'),
          debugShowCheckedModeBanner: false,
          navigatorKey: app.navKey,
          scaffoldMessengerKey: app.messengerKey,
          locale: const Locale('fa', 'IR'),
          supportedLocales: const [Locale('fa', 'IR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildTheme(Brightness.light, primary),
          darkTheme: buildTheme(Brightness.dark, primary),
          themeMode: app.themeMode,
          initialRoute: '/',
          routes: {
            '/': (_) => const SplashScreen(),
            '/login': (_) => const LoginScreen(),
            '/admin-login': (_) => const AdminLoginScreen(),
            '/home': (_) => const UserShell(),
            '/admin': (_) => const AdminShell(),
          },
        );
      },
    );
  }
}
