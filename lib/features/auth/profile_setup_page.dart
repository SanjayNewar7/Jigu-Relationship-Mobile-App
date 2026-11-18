import '../../core/errors/app_error.dart';
import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/lily_backdrop.dart';
import '../../core/widgets/lily_bloom.dart';
import '../../services/profile_service.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key, required this.onSaved});
  final VoidCallback onSaved;
  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final name = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ProfileService().saveName(name.text);
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = AppError.message(
            e,
            fallback: 'Could not save your name. Please try again.',
          ),
        );
      }
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
              padding: const EdgeInsets.all(24),
              child: GlassSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: LilyBloom(size: 88)),
                    const SizedBox(height: 22),
                    Text(
                      'What should your partner call you?',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(color: plum),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your person will see this name when your spaces connect.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: inkSoft),
                    ),
                    const SizedBox(height: 25),
                    TextField(
                      controller: name,
                      enabled: !busy,
                      autofocus: true,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => save(),
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        hintText: 'The name your person knows',
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
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: busy ? null : save,
                      child: Text(busy ? 'Saving…' : 'Continue to Jigu'),
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
