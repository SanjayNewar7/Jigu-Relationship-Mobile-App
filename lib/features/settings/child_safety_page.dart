import 'package:flutter/material.dart';
import '../../core/errors/app_error.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/lily_backdrop.dart';
import '../../services/child_safety_service.dart';
import 'legal_content.dart';
import 'legal_page.dart';

class ChildSafetyPage extends StatefulWidget {
  const ChildSafetyPage({super.key});
  @override
  State<ChildSafetyPage> createState() => _ChildSafetyPageState();
}

class _ChildSafetyPageState extends State<ChildSafetyPage> {
  final details = TextEditingController();
  String category = 'child_safety';
  bool sending = false;
  String? error;
  bool sent = false;

  @override
  void dispose() {
    details.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (sending) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await ChildSafetyService().submit(
        category: category,
        details: details.text,
      );
      if (mounted) setState(() => sent = true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = AppError.message(
            e,
            fallback: 'Your report could not be sent. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Child safety')),
    body: LilyBackdrop(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          GlassSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A safe little space',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Jigu prohibits child sexual abuse and exploitation, including abusive images, grooming, and sexual exploitation of minors.',
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LegalPage(
                        title: 'Child safety standards',
                        sections: childSafetySections,
                        publicUrl:
                            'https://sanjaynewar7.github.io/Jigu-/child-safety.html',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Read our safety standards'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassSurface(
            child: sent
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline),
                      SizedBox(height: 10),
                      Text('Your report was sent.'),
                      SizedBox(height: 6),
                      Text(
                        'Thank you for helping keep Jigu safe. We will review the concern.',
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Report a child safety concern',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tell us what happened. Do not include or resend abusive images.',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(labelText: 'Concern'),
                        items: const [
                          DropdownMenuItem(
                            value: 'child_safety',
                            child: Text('Child safety'),
                          ),
                          DropdownMenuItem(
                            value: 'sexual_exploitation',
                            child: Text('Sexual exploitation'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Other safety concern'),
                          ),
                        ],
                        onChanged: sending
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => category = value);
                                }
                              },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: details,
                        enabled: !sending,
                        minLines: 4,
                        maxLines: 8,
                        maxLength: 4000,
                        decoration: const InputDecoration(
                          labelText: 'What happened?',
                          hintText:
                              'Describe the concern and where you saw it in Jigu',
                          alignLabelWithHint: true,
                        ),
                      ),
                      if (error != null)
                        Text(error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: sending ? null : submit,
                        child: Text(sending ? 'Sending…' : 'Send report'),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'For immediate danger, contact local emergency services. You can also reach us at sanjaynewar007@gmail.com.',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}
