import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config.dart';
import '../../core/widgets/glass_surface.dart';
import '../../core/widgets/lily_backdrop.dart';
import '../../core/widgets/lily_bloom.dart';

class DeveloperPage extends StatelessWidget {
  const DeveloperPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('About Jigu')),
    body: LilyBackdrop(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: LilyBloom(size: 124)),
          const SizedBox(height: 10),
          Text(
            'A little world for two',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: plum),
          ),
          const SizedBox(height: 8),
          const Text(
            'Moments, places, dates, and the days you share.',
            textAlign: TextAlign.center,
            style: TextStyle(color: inkSoft),
          ),
          const SizedBox(height: 22),
          GlassSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Made by', style: TextStyle(color: inkSoft)),
                const SizedBox(height: 4),
                Text(
                  'Sanjaya Rajbhandari',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: plum),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Jigu was made to help two people feel close through the little things.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Website'),
                  subtitle: const Text('sanjayarajbhandari.com.np'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => launchUrl(
                    Uri.parse('https://sanjayarajbhandari.com.np'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                const Divider(height: 1, indent: 18, endIndent: 18),
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('Contact'),
                  subtitle: const Text('Sanjaynewar007@gmail.com'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => launchUrl(
                    Uri(
                      scheme: 'mailto',
                      path: 'Sanjaynewar007@gmail.com',
                      queryParameters: {'subject': 'Jigu support'},
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('Jigu 1.0.0', style: TextStyle(color: inkSoft)),
          ),
        ],
      ),
    ),
  );
}
