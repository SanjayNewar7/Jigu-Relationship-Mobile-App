import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/login_page.dart';
import '../features/auth/password_page.dart';
import '../features/auth/profile_gate.dart';
import '../features/splash/splash_view.dart';
import 'config.dart';
import 'theme/lily_theme.dart';
import '../utils/auth_error_message.dart';

class Jigu extends StatelessWidget {
  const Jigu({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Jigu',
    debugShowCheckedModeBanner: false,
    theme: LilyTheme.light,
    home: const Entry(),
  );
}

class Entry extends StatefulWidget {
  const Entry({super.key});
  @override
  State<Entry> createState() => _EntryState();
}

class _EntryState extends State<Entry> {
  bool ready = false;
  StreamSubscription<AuthState>? authSubscription;
  String? callbackError;
  bool recovering = false;
  @override
  void initState() {
    super.initState();
    if (url.isNotEmpty && key.isNotEmpty) {
      authSubscription = db.auth.onAuthStateChange.listen(
        (state) {
          if (!mounted) return;
          setState(() {
            callbackError = null;
            if (state.event == AuthChangeEvent.passwordRecovery) {
              recovering = true;
            } else if (state.event == AuthChangeEvent.signedOut) {
              recovering = false;
            }
          });
        },
        onError: (Object error, StackTrace stackTrace) {
          if (mounted) setState(() => callbackError = authErrorMessage(error));
        },
      );
    }
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return SplashView(
        onComplete: () {
          if (mounted) setState(() => ready = true);
        },
      );
    }
    if (url.isEmpty || key.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Jigu needs its connection settings.')),
      );
    }
    if (recovering && db.auth.currentUser != null) {
      return PasswordPage(
        recovery: true,
        onFinished: () {
          if (mounted) setState(() => recovering = false);
        },
      );
    }
    return db.auth.currentUser == null
        ? Login(callbackError: callbackError)
        : ProfileGate(key: ValueKey(db.auth.currentUser!.id));
  }
}
