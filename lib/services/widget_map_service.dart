import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';

/// A single visible OSM tile, cached for seven days. No background prefetch.
class WidgetMapService {
  Future<String?> snapshot(Map<String, dynamic>? place) async {
    if (place == null) return null;
    final lat = (place['latitude'] as num).toDouble().clamp(-85.05, 85.05);
    final lon = (place['longitude'] as num).toDouble();
    const zoom = 14, n = 16384;
    final x = (lon + 180) / 360 * n;
    final radians = lat * math.pi / 180;
    final y =
        (1 - math.log(math.tan(radians) + 1 / math.cos(radians)) / math.pi) /
        2 *
        n;
    final directory = Directory(
      '${(await getApplicationSupportDirectory()).path}/widget-map',
    );
    await directory.create(recursive: true);
    final tile = File('${directory.path}/$zoom-${x.floor()}-${y.floor()}.png');
    try {
      if (!await tile.exists() ||
          DateTime.now().difference((await tile.stat()).modified).inDays >= 7) {
        final client = HttpClient()
          ..userAgent = 'com.sanjaya.jigu/1.0 (private relationship app)';
        try {
          final request = await client
              .getUrl(
                Uri.parse(
                  'https://tile.openstreetmap.org/$zoom/${x.floor()}/${y.floor()}.png',
                ),
              )
              .timeout(const Duration(seconds: 10));
          final response = await request.close().timeout(
            const Duration(seconds: 10),
          );
          if (response.statusCode != 200) return null;
          final bytes = await response
              .fold<List<int>>([], (all, chunk) => all..addAll(chunk))
              .timeout(const Duration(seconds: 10));
          await tile.writeAsBytes(bytes, flush: true);
        } finally {
          client.close(force: true);
        }
      }
      final codec = await ui.instantiateImageCodec(await tile.readAsBytes());
      final image = (await codec.getNextFrame()).image;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImage(image, ui.Offset.zero, ui.Paint());
      final point = ui.Offset((x - x.floor()) * 256, (y - y.floor()) * 256);
      canvas.drawCircle(
        point,
        11,
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      canvas.drawCircle(
        point,
        8,
        ui.Paint()..color = const ui.Color(0xFFB888AF),
      );
      final picture = recorder.endRecording();
      final rendered = await picture.toImage(256, 256);
      final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
      rendered.dispose();
      picture.dispose();
      image.dispose();
      codec.dispose();
      if (data == null) return null;
      final file = File('${directory.path}/place.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      // Bound the cache without prefetching or retaining a location trail.
      await for (final old in directory.list()) {
        if (old is File && old.path != tile.path && old.path != file.path) {
          await old.delete();
        }
      }
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
