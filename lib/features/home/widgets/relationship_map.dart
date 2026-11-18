import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config.dart';

class RelationshipMap extends StatefulWidget {
  const RelationshipMap({super.key, this.partner, this.own, this.tileProvider});
  final Map<String, dynamic>? partner, own;
  final TileProvider? tileProvider;
  @override
  State<RelationshipMap> createState() => _RelationshipMapState();
}

class _RelationshipMapState extends State<RelationshipMap> {
  final controller = MapController();
  bool ready = false, follow = true;
  int mapStyle = 0;
  static const tileUrls = [
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
  ];
  LatLng? point(Map<String, dynamic>? p) =>
      p?['latitude'] is num && p?['longitude'] is num
      ? LatLng(
          (p!['latitude'] as num).toDouble(),
          (p['longitude'] as num).toDouble(),
        )
      : null;
  @override
  void didUpdateWidget(covariant RelationshipMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = point(widget.partner) ?? point(widget.own);
    if (ready &&
        follow &&
        target != null &&
        target != (point(oldWidget.partner) ?? point(oldWidget.own))) {
      controller.move(
        target,
        controller.camera.zoom < 5 ? 15 : controller.camera.zoom,
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partner = point(widget.partner), own = point(widget.own);
    final target = partner ?? own;
    final time = DateTime.tryParse(
      widget.partner?['updated_at']?.toString() ?? '',
    );
    final fresh = time != null && DateTime.now().difference(time).inMinutes < 2;
    final speed = widget.partner?['speed_mps'] as num?;
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        height: 350,
        child: Stack(
          children: [
            RepaintBoundary(
              child: FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: target ?? const LatLng(20, 0),
                  initialZoom: target == null ? 2 : 15,
                  onMapReady: () => ready = true,
                  onPositionChanged: (_, gesture) {
                    if (gesture) follow = false;
                  },
                ),
                children: [
                  TileLayer(
                    key: ValueKey(mapStyle),
                    tileProvider: widget.tileProvider,
                    urlTemplate: tileUrls[mapStyle],
                    userAgentPackageName: 'com.sanjaya.jigu',
                  ),
                  if (partner != null && widget.partner?['accuracy_m'] is num)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: partner,
                          radius: (widget.partner!['accuracy_m'] as num)
                              .toDouble()
                              .clamp(0, 5000),
                          useRadiusInMeter: true,
                          color: coral.withValues(alpha: .14),
                          borderColor: coral,
                          borderStrokeWidth: 1,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (partner != null)
                        Marker(
                          point: partner,
                          width: 52,
                          height: 52,
                          child: const _Pin(icon: Icons.favorite, color: coral),
                        ),
                      if (own != null)
                        Marker(
                          point: own,
                          width: 42,
                          height: 42,
                          child: const _Pin(icon: Icons.person, color: sage),
                        ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      if (mapStyle == 0)
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () => launchUrl(
                            Uri.parse(
                              'https://www.openstreetmap.org/copyright',
                            ),
                          ),
                        )
                      else
                        TextSourceAttribution(
                          'Esri, Maxar, Earthstar Geographics and GIS User Community',
                          onTap: () => launchUrl(
                            Uri.parse(
                              'https://www.esri.com/en-us/legal/overview',
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 62,
              child: Card(
                color: cream,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    partner == null
                        ? (own == null
                              ? 'Your shared places will appear here'
                              : 'Your place - waiting for your person')
                        : fresh && speed != null
                        ? 'Your person - ${(speed * 3.6).toStringAsFixed(1)} km/h estimated'
                        : 'Your person - last shared place',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 12,
              child: IconButton.filledTonal(
                tooltip: 'Centre on shared place',
                onPressed: target == null
                    ? null
                    : () {
                        follow = true;
                        controller.move(target, 15);
                      },
                icon: const Icon(Icons.my_location),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 30,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Material(
                  color: cream.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(18),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Wrap(
                      spacing: 2,
                      children: [
                        for (final (index, label, icon) in [
                          (0, 'Map', Icons.map_outlined),
                          (1, 'Satellite', Icons.satellite_alt_outlined),
                          (2, 'Terrain', Icons.terrain_outlined),
                        ])
                          ChoiceChip(
                            label: Text(label),
                            avatar: Icon(icon, size: 16),
                            selected: mapStyle == index,
                            onSelected: (_) => setState(() => mapStyle = index),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
    ),
    child: Icon(icon, color: Colors.white, size: 23),
  );
}
