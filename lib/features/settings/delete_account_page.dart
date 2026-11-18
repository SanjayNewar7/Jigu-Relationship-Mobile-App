import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/lily_backdrop.dart';
import '../../services/auth_service.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({
    super.key,
    required this.email,
    required this.onDeleted,
  });
  final String email;
  final Future<void> Function() onDeleted;
  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> remove() async {
    if (busy) return;
    if (password.text.isEmpty || confirmation.text.trim() != 'DELETE') {
      setState(() => error = 'Enter your password and type DELETE to confirm.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AuthService().deleteAccount(password.text);
      await widget.onDeleted();
    } on FunctionException catch (exception) {
      if (mounted) {
        setState(
          () => error = exception.details is Map
              ? '${(exception.details as Map)['message'] ?? 'Deletion could not finish.'}'
              : 'Deletion could not finish. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Deletion could not finish. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Delete account')),
    body: LilyBackdrop(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Your data, your choice',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: plum),
          ),
          const SizedBox(height: 12),
          const Text(
            'Deleting your account is permanent. Leaving a shared space and logging out are separate actions.',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 18),
          GlassSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.privacy_tip_outlined, color: coral, size: 28),
                const SizedBox(height: 12),
                Text(
                  'What will be removed',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: plum),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your account, private journal, location, notification devices, and every shared space you belong to will be deleted. The spaces, shared moments, date plans, and stored photos will also disappear for your partner. Photos either of you saved to a phone gallery cannot be removed by Jigu.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Account: ${widget.email}',
            style: const TextStyle(color: inkSoft),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            enabled: !busy,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirmation,
            enabled: !busy,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Type DELETE to confirm',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: busy ? null : remove,
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(busy ? 'Deleting…' : 'Permanently delete account'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => launchUrl(
              Uri(
                scheme: 'mailto',
                path: 'Sanjaynewar007@gmail.com',
                queryParameters: {
                  'subject': 'Jigu account deletion request',
                  'body':
                      'Please help delete my Jigu account.\nAccount email: ${widget.email}',
                },
              ),
            ),
            child: const Text('Need help? Email support'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Public deletion instructions'),
            onPressed: () => launchUrl(
              Uri.parse(
                'https://sanjaynewar7.github.io/Jigu-/delete-account.html',
              ),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
    ),
  );
}
