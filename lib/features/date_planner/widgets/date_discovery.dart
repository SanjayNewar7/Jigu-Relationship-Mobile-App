import '../../../core/errors/app_error.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../services/date_planner_service.dart';
import '../../../utils/date_maps.dart';

class DateDiscovery extends StatefulWidget {
  const DateDiscovery({
    super.key,
    required this.onSelect,
    required this.onFavorite,
  });
  final ValueChanged<Map<String, dynamic>> onSelect;
  final Future<void> Function(Map<String, dynamic>) onFavorite;
  @override
  State<DateDiscovery> createState() => _DateDiscoveryState();
}

class _DateDiscoveryState extends State<DateDiscovery> {
  bool loading = false;
  String? error;
  String city = 'Discover somewhere lovely';
  String category = 'All';
  int radius = 15000;
  List<Map<String, dynamic>> places = [];
  final savedIds = <String>{};
  @override
  void initState() {
    super.initState();
    autoDiscover();
  }

  Future<void> autoDiscover() async {
    final permission = await Geolocator.checkPermission();
    if (mounted &&
        (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse)) {
      await discover();
    }
  }

  Future<void> discover() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Allow location to find nearby ideas, or enter your own venue below.',
        );
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Turn on phone location to find nearby ideas.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final result = await DatePlannerService().discover(
        position.latitude,
        position.longitude,
        radius,
      );
      if (!mounted) return;
      setState(() {
        city = result['city'] as String? ?? 'Around you';
        places = (result['places'] as List)
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = AppError.message(
            e,
            fallback:
                'Nearby ideas are unavailable right now. You can still plan a date with your own venue.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = places
        .where((p) => category == 'All' || p['category'] == category)
        .take(40)
        .toList();
    return GlassSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(city, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          const Text(
            'Find a lovely place for food, water, hills, culture, play or a ride. Location is used only for this search.',
          ),
          DropdownButton<int>(
            isExpanded: true,
            value: radius,
            items: const [
              DropdownMenuItem(
                value: 15000,
                child: Text('Around the city \u00b7 15 km'),
              ),
              DropdownMenuItem(
                value: 50000,
                child: Text('Further afield \u00b7 50 km'),
              ),
              DropdownMenuItem(
                value: 100000,
                child: Text('Neighbouring areas \u00b7 100 km'),
              ),
            ],
            onChanged: loading
                ? null
                : (value) {
                    setState(() {
                      radius = value!;
                      places = [];
                    });
                    discover();
                  },
          ),
          OutlinedButton.icon(
            onPressed: loading ? null : discover,
            icon: const Icon(Icons.explore_outlined),
            label: Text(
              loading ? 'Finding nearby ideas...' : 'Find ideas near me',
            ),
          ),
          if (error != null) Text(error!),
          if (places.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    [
                          'All',
                          'Dining',
                          'Resort',
                          'Nature',
                          'Riverside',
                          'Culture',
                          'Hills',
                          'Outdoors',
                          'Playful',
                          'Bike ride',
                        ]
                        .map(
                          (name) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(name),
                              selected: category == name,
                              onSelected: (_) =>
                                  setState(() => category = name),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            const Text(
              'Distances are straight-line estimates. Check opening hours and routes before going.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height:
                  315 *
                  MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: shown.length,
                separatorBuilder: (_, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final place = shown[index];
                  return SizedBox(
                    width: 255,
                    child: Card(
                      color: Colors.white.withValues(alpha: .7),
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place['category'],
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              place['title'] ?? place['name'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 19),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              place['address'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              place['description'] ?? '',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '${((place['distance'] as num) / 1000).toStringAsFixed(1)} km away',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () {
                                      widget.onSelect(place);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Venue added to your invitation',
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Choose this'),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'View on map',
                                  icon: const Icon(Icons.map_outlined),
                                  onPressed: () => openDateMap(
                                    place: place['name'],
                                    latitude: (place['latitude'] as num)
                                        .toDouble(),
                                    longitude: (place['longitude'] as num)
                                        .toDouble(),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Save to favourites',
                                  icon: Icon(
                                    savedIds.contains(place['id'])
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                  ),
                                  onPressed: savedIds.contains(place['id'])
                                      ? null
                                      : () async {
                                          try {
                                            await widget.onFavorite(place);
                                            if (mounted) {
                                              setState(
                                                () => savedIds.add(
                                                  place['id'] as String,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    AppError.message(
                                                      e,
                                                      fallback:
                                                          'Could not save this favourite.',
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Place information',
                icon: const Icon(Icons.info_outline, size: 16),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('About these places'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Map listings may change. Open Google Maps to explore the place and check its details.',
                        ),
                        TextButton(
                          onPressed: () =>
                              launchUrl(Uri.parse('https://www.geoapify.com/')),
                          child: const Text('Powered by Geoapify'),
                        ),
                        TextButton(
                          onPressed: () => launchUrl(
                            Uri.parse(
                              'https://www.openstreetmap.org/copyright',
                            ),
                          ),
                          child: const Text('OpenStreetMap contributors'),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (!loading && error == null && places.isEmpty)
            const Text('Choose a wider area or add a place you already love.'),
        ],
      ),
    );
  }
}
