import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/features/auth/presentation/login_page.dart';
import 'package:fcd_app/src/features/home/presentation/home_shell.dart';
import 'package:fcd_app/src/features/splash/presentation/splash_page.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FcdApp extends StatelessWidget {
  const FcdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCD',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _BootstrapGate(),
    );
  }
}

class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate();

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  bool _splashFinished = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _splashFinished = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionController>(
      builder: (context, session, child) {
        final shouldShowSplash = !_splashFinished || session.isChecking;

        Widget page;
        if (shouldShowSplash) {
          page = const SplashPage();
        } else if (session.isAuthenticated) {
          page = const HomeShell();
        } else {
          page = const LoginPage(key: ValueKey('login'));
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: page,
        );
      },
    );
  }
}
