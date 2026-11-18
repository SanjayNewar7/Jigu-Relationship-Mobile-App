import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;

class DateInvitationExportService {
  Future<void> save(RenderRepaintBoundary boundary, String dateId) async {
    final pixelRatio = math.min(2.5, 3200 / boundary.size.height);
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Could not render the invitation.');
      final jpeg = await compute(_toJpeg, data.buffer.asUint8List());
      await Gal.putImageBytes(
        jpeg,
        album: 'Jigu',
        name: 'jigu-date-${dateId.substring(0, math.min(dateId.length, 8))}',
      );
    } finally {
      image.dispose();
    }
  }
}

Uint8List _toJpeg(Uint8List png) {
  final decoded = img.decodePng(png);
  if (decoded == null) throw StateError('Could not encode the invitation.');
  return Uint8List.fromList(img.encodeJpg(decoded, quality: 94));
}
