import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config.dart';
import '../../core/widgets/lily_backdrop.dart';
import '../../core/widgets/glass_surface.dart';
import 'legal_content.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({
    super.key,
    required this.title,
    required this.sections,
    this.publicUrl,
  });
  final String title;
  final List<LegalSection> sections;
  final String? publicUrl;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: LilyBackdrop(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: plum),
          ),
          const SizedBox(height: 5),
          const Text(
            'Jigu  •  Updated 14 November 2026',
            style: TextStyle(color: inkSoft),
          ),
          const SizedBox(height: 18),
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassSurface(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.heading,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: plum),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      section.body,
                      style: const TextStyle(height: 1.5, color: inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (publicUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open public version'),
                onPressed: () => launchUrl(
                  Uri.parse(publicUrl!),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
