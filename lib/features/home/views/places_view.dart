import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../core/config.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/jigu_controls.dart';
import '../widgets/place_card.dart';
import '../widgets/relationship_map.dart';

class PlacesView extends StatelessWidget {
  const PlacesView({
    super.key,
    required this.label,
    required this.place,
    required this.sharing,
    required this.busy,
    required this.onChanged,
    this.ownPlace,
    this.tileProvider,
    this.activity = '',
  });
  final String label;
  final TileProvider? tileProvider;
  final String activity;
  final Map<String, dynamic>? ownPlace;
  final Map<String, dynamic>? place;
  final bool sharing, busy;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('places'),
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 130),
    children: [
      const PageHeading(
        eyebrow: 'A LITTLE CLOSER',
        title: 'Where we are.',
        subtitle: 'A gentle way to feel close, wherever the day takes you.',
      ),
      RelationshipMap(
        partner: place,
        own: ownPlace,
        tileProvider: tileProvider,
      ),
      const SizedBox(height: 16),
      PlaceCard(label: label, place: place),
      if (activity.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(activity, textAlign: TextAlign.center),
        ),
      const SizedBox(height: 22),
      GlassSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Share my location',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 12),
                CupertinoSwitch(
                  value: sharing,
                  activeTrackColor: sage,
                  onChanged: busy ? null : onChanged,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              sharing
                  ? 'Your place updates as you move, even when Jigu is in the background. A phone notification shows while sharing is on.'
                  : 'Choose when you want to share your place.',
            ),
            const SizedBox(height: 18),
            const Divider(color: Color(0xFFDCD5DF)),
            const SizedBox(height: 12),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(CupertinoIcons.hand_raised, size: 18, color: inkSoft),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your choice stays saved between visits. Turn it off anytime to remove your shared location.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'You will always see when a location was last shared.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13),
      ),
    ],
  );
}
