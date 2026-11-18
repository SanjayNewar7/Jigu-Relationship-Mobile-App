import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config.dart';

class DatePlaceMapPicker extends StatefulWidget {
  const DatePlaceMapPicker({super.key, required this.onChanged});
  final ValueChanged<LatLng> onChanged;

  @override
  State<DatePlaceMapPicker> createState() => _DatePlaceMapPickerState();
}

class _DatePlaceMapPickerState extends State<DatePlaceMapPicker> {
  final map = MapController();
  final mapKey = GlobalKey();
  LatLng? pin;
  bool ready = false;
  bool locating = false;

  @override
  void initState() {
    super.initState();
    locate(requestPermission: false);
  }

  Future<void> locate({required bool requestPermission}) async {
    if (locating) return;
    setState(() => locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (requestPermission && permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setPin(point);
      if (ready) map.move(point, 16);
    } catch (_) {
      if (requestPermission && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not find your location. Tap the map to set the pin.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void setPin(LatLng point) {
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude < -90 ||
        point.latitude > 90 ||
        point.longitude < -180 ||
        point.longitude > 180) {
      return;
    }
    setState(() => pin = point);
    widget.onChanged(point);
  }

  void dragPin(DragUpdateDetails details) {
    final box = mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !ready) return;
    final offset = box.globalToLocal(details.globalPosition);
    setPin(map.camera.screenOffsetToLatLng(offset));
  }

  @override
  void dispose() {
    map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Choose the exact spot',
        style: TextStyle(fontSize: 18, color: plum),
      ),
      const SizedBox(height: 5),
      const Text('Tap the map, or hold and drag the pin. Pinch to zoom.'),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          key: mapKey,
          height: 290,
          child: Stack(
            children: [
              FlutterMap(
                mapController: map,
                options: MapOptions(
                  initialCenter: const LatLng(20, 0),
                  initialZoom: 4,
                  minZoom: 3,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(
                    flags:
                        InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom |
                        InteractiveFlag.scrollWheelZoom,
                  ),
                  onMapReady: () {
                    ready = true;
                    if (pin != null) map.move(pin!, 16);
                  },
                  onTap: (_, point) => setPin(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.sanjaya.jigu',
                  ),
                  if (pin != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: pin!,
                          width: 64,
                          height: 70,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPressMoveUpdate: (details) => dragPin(
                              DragUpdateDetails(
                                globalPosition: details.globalPosition,
                              ),
                            ),
                            child: const Icon(
                              Icons.location_pin,
                              color: coral,
                              size: 54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton.filledTonal(
                  tooltip: 'Find my location',
                  onPressed: locating
                      ? null
                      : () => locate(requestPermission: true),
                  icon: locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 7),
      Text(
        pin == null
            ? 'Choose a spot on the map to continue'
            : 'Pinned at ${pin!.latitude.toStringAsFixed(6)}, ${pin!.longitude.toStringAsFixed(6)}',
        style: const TextStyle(fontSize: 12, color: inkSoft),
      ),
    ],
  );
}
