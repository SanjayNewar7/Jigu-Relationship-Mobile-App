import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Transparent fixture tiles keep UI tests offline; they do not simulate map data.
class OfflineTiles extends TileProvider {
  final image = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      image;
}
