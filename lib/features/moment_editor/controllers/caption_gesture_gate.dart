import 'package:flutter/gestures.dart';

/// Allows caption editing only after a brief tap without movement or scaling.
class CaptionGestureGate {
  String? _layerId;
  DateTime? _startedAt;
  Offset _offset = Offset.zero;
  double _scale = 1, _rotation = 0, _distance = 0;
  bool _transformed = false;

  void begin(String layerId, Offset offset, double scale, double rotation) {
    _layerId = layerId;
    _startedAt = DateTime.now();
    _offset = offset;
    _scale = scale;
    _rotation = rotation;
    _distance = 0;
    _transformed = false;
  }

  void update(ScaleUpdateDetails details) {
    _distance += details.focalPointDelta.distance;
    if (details.pointerCount > 1 ||
        _distance > 8 ||
        (details.scale - 1).abs() > .02 ||
        details.rotation.abs() > .02) {
      _transformed = true;
    }
  }

  bool end(String layerId, Offset offset, double scale, double rotation) {
    final startedAt = _startedAt;
    final edit = _layerId == layerId &&
        startedAt != null &&
        DateTime.now().difference(startedAt) <
            const Duration(milliseconds: 450) &&
        !_transformed &&
        (offset - _offset).distance < 3 &&
        (scale - _scale).abs() < .01 &&
        (rotation - _rotation).abs() < .01;
    _layerId = null;
    _startedAt = null;
    return edit;
  }
}
