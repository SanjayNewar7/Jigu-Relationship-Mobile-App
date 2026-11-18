import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/lily_backdrop.dart';
import '../../services/auth_service.dart';
import '../../utils/auth_error_message.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail = ''});
  final String initialEmail;
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final email = TextEditingController(text: widget.initialEmail);
  bool busy = false, sent = false;
  Timer? cooldown;
  String? error;

  @override
  void dispose() {
    cooldown?.cancel();
    email.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final address = email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address)) {
      setState(() => error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AuthService().sendPasswordReset(address);
      if (mounted) {
        setState(() => sent = true);
        cooldown?.cancel();
        cooldown = Timer(const Duration(seconds: 60), () {
          if (mounted) setState(() => sent = false);
        });
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => error = authErrorMessage(e));
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not send a reset link. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Forgot password')),
    body: LilyBackdrop(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 44, color: coral),
          const SizedBox(height: 12),
          Text(
            'Find your way back',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: plum),
          ),
          const SizedBox(height: 8),
          const Text(
            'We’ll send a password reset link to your email. Open it on this phone to return to Jigu.',
            textAlign: TextAlign.center,
            style: TextStyle(color: inkSoft),
          ),
          const SizedBox(height: 22),
          GlassSurface(
            child: Column(
              children: [
                TextField(
                  controller: email,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Account email address',
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Color(0xFF973D59)),
                    ),
                  ),
                if (sent)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'If an account uses this email, a reset link is on its way. Check your inbox and spam folder. Use the newest link.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy || sent ? null : send,
                    child: Text(
                      busy
                          ? 'Sending...'
                          : sent
                          ? 'Link requested'
                          : 'Send reset link',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
