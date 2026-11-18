import 'package:flutter/cupertino.dart';
import '../../../core/config.dart';
import '../../../core/widgets/glass_surface.dart';

class PlaceCard extends StatelessWidget {
  const PlaceCard({super.key, required this.label, required this.place});
  final String label;
  final Map<String, dynamic>? place;
  @override
  Widget build(BuildContext context) => GlassSurface(
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: sage.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            CupertinoIcons.location,
            color: Color(0xFF526A57),
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your person’s place',
                style: TextStyle(fontSize: 19, color: plum),
              ),
              const SizedBox(height: 4),
              Text(label),
              if (place != null && label != 'No recent location shared') ...[
                const SizedBox(height: 5),
                Text(
                  '${(place!['latitude'] as num).toStringAsFixed(4)}, ${(place!['longitude'] as num).toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
