import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/lily_backdrop.dart';
import '../../core/widgets/jigu_controls.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config.dart';
import '../../core/widgets/lily_bloom.dart';
import '../../services/auth_service.dart';
import 'forgot_password_page.dart';
import '../../utils/auth_error_message.dart';

class Login extends StatefulWidget {
  const Login({super.key, this.callbackError});
  final String? callbackError;
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool creating = false;
  bool obscurePassword = true;
  bool busy = false;
  String? error;
  String? notice;
  Timer? resendTimer;
  bool resendCoolingDown = false;

  @override
  void initState() {
    super.initState();
    error = widget.callbackError;
  }

  @override
  void didUpdateWidget(covariant Login oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.callbackError != oldWidget.callbackError) {
      error = widget.callbackError;
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    resendTimer?.cancel();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    final address = email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address)) {
      setState(() => error = 'Enter a valid email address.');
      return;
    }
    if (password.text.length < 6) {
      setState(() => error = 'Use at least six characters for your password.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      if (creating) {
        final response = await AuthService().signUp(address, password.text);
        if (mounted && response.session == null) {
          setState(() {
            creating = false;
            notice =
                'Check your email to confirm, then return to Jigu. Already confirmed? Sign in below.';
          });
        }
      } else {
        await AuthService().signIn(address, password.text);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => error = authErrorMessage(e));
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resendConfirmation() async {
    if (busy || resendCoolingDown) return;
    final address = email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address)) {
      setState(() => error = 'Enter your email address above first.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await AuthService().resendConfirmation(address);
      if (!mounted) return;
      setState(() {
        notice =
            'If your account needs confirmation, a fresh link is on its way. Open only the newest email on this phone. Already confirmed? Sign in.';
        resendCoolingDown = true;
      });
      resendTimer?.cancel();
      resendTimer = Timer(const Duration(seconds: 60), () {
        if (mounted) setState(() => resendCoolingDown = false);
      });
    } catch (e) {
      if (mounted) setState(() => error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LilyBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
              child: AutofillGroup(
                child: Column(
                  children: [
                    const LilyBloom(size: 60),
                    const SizedBox(height: 12),
                    const Text(
                      'jigu',
                      style: TextStyle(
                        fontSize: 32,
                        color: plum,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A little world for two.',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your moments. Your person.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    GlassSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CupertinoSlidingSegmentedControl<bool>(
                            groupValue: creating,
                            backgroundColor: plum.withValues(alpha: .05),
                            thumbColor: Colors.white.withValues(alpha: .9),
                            onValueChanged: (value) {
                              if (!busy && value != null) {
                                setState(() {
                                  creating = value;
                                  error = null;
                                });
                              }
                            },
                            children: const {
                              false: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Sign in',
                                  style: TextStyle(
                                    fontFamily: 'Sniglet',
                                    fontWeight: FontWeight.w400,
                                    color: plum,
                                  ),
                                ),
                              ),
                              true: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Create account',
                                  style: TextStyle(
                                    fontFamily: 'Sniglet',
                                    fontWeight: FontWeight.w400,
                                    color: plum,
                                  ),
                                ),
                              ),
                            },
                          ),
                          const SizedBox(height: 26),
                          Text(
                            creating ? 'Let love bloom.' : 'Hello, you.',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            creating
                                ? 'Make a little space for your story.'
                                : 'Your shared space is waiting.',
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: email,
                            enabled: !busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(CupertinoIcons.mail, size: 20),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: password,
                            enabled: !busy,
                            obscureText: obscurePassword,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!busy) submit();
                            },
                            autofillHints: [
                              creating
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                CupertinoIcons.lock,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                tooltip: obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                  () => obscurePassword = !obscurePassword,
                                ),
                                icon: Icon(
                                  obscurePassword
                                      ? CupertinoIcons.eye
                                      : CupertinoIcons.eye_slash,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 180),
                            alignment: Alignment.topCenter,
                            child: error == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        error!,
                                        style: const TextStyle(
                                          color: Color(0xFF973D59),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 24),
                          JiguButton(
                            label: creating ? 'Create our space' : 'Come on in',
                            onPressed: submit,
                            busy: busy,
                            icon: CupertinoIcons.arrow_right,
                          ),
                          if (notice != null) ...[
                            const SizedBox(height: 16),
                            Semantics(
                              liveRegion: true,
                              child: Text(notice!, textAlign: TextAlign.center),
                            ),
                          ],
                          if (!creating) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ForgotPasswordPage(
                                          initialEmail: email.text.trim(),
                                        ),
                                      ),
                                    ),
                              child: const Text('Forgot password?'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: busy || resendCoolingDown
                                  ? null
                                  : resendConfirmation,
                              child: Text(
                                resendCoolingDown
                                    ? 'Email requested — please wait'
                                    : 'Resend confirmation email',
                              ),
                            ),
                          ],
                          if (creating) ...[
                            const SizedBox(height: 14),
                            const Text(
                              'We will email you a confirmation link.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: inkSoft),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.heart, color: sage, size: 15),
                        SizedBox(width: 7),
                        Text(
                          'Just you. Just us.',
                          style: TextStyle(fontSize: 13, color: inkSoft),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
