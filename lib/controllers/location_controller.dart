import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../services/couple_service.dart';

class LocationController {
  StreamSubscription<Position>? _stream;
  Timer? _retryTimer;
  Position? _pendingPosition;
  String? _activeCoupleId;
  bool _sending = false;
  final CoupleService service = CoupleService();
  int _generation = 0;
  bool _starting = false, _refreshing = false;
  DateTime? _lastSent;
  Future<void> _sendLatest() async {
    if (_sending || _pendingPosition == null || _activeCoupleId == null) return;
    _sending = true;
    final position = _pendingPosition!;
    final coupleId = _activeCoupleId!;
    try {
      await service.sendPosition(position, coupleId);
      if (identical(_pendingPosition, position)) _pendingPosition = null;
      _lastSent = DateTime.now();
    } catch (_) {
      // Keep only the newest place and retry when connectivity returns.
    } finally {
      _sending = false;
    }
  }

  Future<void> start(String coupleId, {bool requestPermission = true}) async {
    if (_starting) return;
    if (_stream != null) {
      await refreshPosition(coupleId);
      return;
    }
    _starting = true;
    final generation = ++_generation;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Please enable location services in phone settings.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Allow location access in phone settings to share your place.',
        );
      }
      if (generation != _generation) return;
      if (requestPermission) await service.setLocationEnabled(true);
      final settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Jigu is sharing your place',
          notificationText:
              'Your person can see your latest place. Turn sharing off in Jigu anytime.',
          notificationChannelName: 'Place sharing',
          notificationIcon: AndroidResource(name: 'ic_notification'),
          setOngoing: true,
        ),
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      ).timeout(const Duration(seconds: 20));
      if (generation != _generation) return;
      _activeCoupleId = coupleId;
      _pendingPosition = position;
      _retryTimer?.cancel();
      _retryTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _sendLatest(),
      );
      _stream = Geolocator.getPositionStream(locationSettings: settings).listen(
        (position) async {
          if (generation != _generation) return;
          _pendingPosition = position;
          if (_lastSent != null &&
              DateTime.now().difference(_lastSent!).inSeconds < 5) {
            return;
          }
          await _sendLatest();
        },
        onError: (Object error) {
          // Keep the latest position for a later retry. Resume can restore
          // the stream once the user returns to Jigu.
          final failedStream = _stream;
          if (failedStream != null) unawaited(failedStream.cancel());
          _stream = null;
        },
      );
      unawaited(_sendLatest());
    } finally {
      _starting = false;
    }
  }

  Future<void> refreshPosition(String coupleId) async {
    if (_refreshing || _stream == null) return;
    _refreshing = true;
    final generation = _generation;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 15));
      if (generation == _generation) {
        _activeCoupleId = coupleId;
        _pendingPosition = position;
        await _sendLatest();
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> suspend() async {
    _generation++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _pendingPosition = null;
    _activeCoupleId = null;
    await _stream?.cancel();
    _stream = null;
  }

  Future<void> stop() async {
    await suspend();
    await service.setLocationEnabled(false);
  }

  Future<void> dispose() => suspend();
}
