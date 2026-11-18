import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/lily_backdrop.dart';
import '../../services/auth_service.dart';
import '../../utils/auth_error_message.dart';

class PasswordPage extends StatefulWidget {
  const PasswordPage({
    super.key,
    required this.recovery,
    required this.onFinished,
  });
  final bool recovery;
  final VoidCallback onFinished;

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final current = TextEditingController();
  final next = TextEditingController();
  final repeat = TextEditingController();
  bool busy = false;
  bool obscure = true;
  String? error;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    repeat.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    if (!widget.recovery && current.text.isEmpty) {
      setState(() => error = 'Enter your current password.');
      return;
    }
    if (next.text.length < 8) {
      setState(
        () => error = 'Choose a password with at least eight characters.',
      );
      return;
    }
    if (next.text != repeat.text) {
      setState(() => error = 'The new passwords do not match.');
      return;
    }
    if (!widget.recovery && next.text == current.text) {
      setState(() => error = 'Choose a different password.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AuthService().changePassword(
        newPassword: next.text,
        currentPassword: widget.recovery ? null : current.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your password has been updated.')),
      );
      widget.onFinished();
    } on AuthException catch (e) {
      if (mounted) setState(() => error = authErrorMessage(e));
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Password could not be updated. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.recovery ? 'Reset password' : 'Change password'),
    ),
    body: LilyBackdrop(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.lock_outline, size: 42, color: coral),
          const SizedBox(height: 12),
          Text(
            widget.recovery ? 'A fresh beginning' : 'Keep your space yours',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: plum),
          ),
          const SizedBox(height: 8),
          Text(
            widget.recovery
                ? 'Your reset link brought you back to Jigu. Choose a new password below.'
                : 'Enter your current password, then type the new one twice.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: inkSoft),
          ),
          const SizedBox(height: 22),
          GlassSurface(
            child: Column(
              children: [
                if (!widget.recovery) ...[
                  TextField(
                    controller: current,
                    obscureText: obscure,
                    enabled: !busy,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: next,
                  obscureText: obscure,
                  enabled: !busy,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: repeat,
                  obscureText: obscure,
                  enabled: !busy,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => save(),
                  decoration: const InputDecoration(
                    labelText: 'Repeat new password',
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    label: Text(obscure ? 'Show passwords' : 'Hide passwords'),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Color(0xFF973D59)),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : save,
                    child: Text(busy ? 'Updating...' : 'Update password'),
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
