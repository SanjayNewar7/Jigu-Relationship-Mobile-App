import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/widgets/glass_surface.dart';

class ConnectionDialog extends StatelessWidget {
  const ConnectionDialog({
    super.key,
    required this.yourName,
    required this.partnerName,
  });
  final String yourName;
  final String partnerName;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24),
    child: GlassSurface(
      opacity: .78,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/moods/joyful.png',
            width: 104,
            height: 104,
            semanticLabel: 'A smiling lily flower',
          ),
          const SizedBox(height: 18),
          Text(
            'Together in Jigu',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: plum),
          ),
          const SizedBox(height: 12),
          Text(
            '$yourName & $partnerName',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: plum),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your little space is connected. Let your story bloom.',
            textAlign: TextAlign.center,
            style: TextStyle(color: inkSoft, height: 1.4),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Our little world'),
            ),
          ),
        ],
      ),
    ),
  );
}
