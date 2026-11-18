import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/features/moment_editor/controllers/caption_gesture_gate.dart';

void main() {
  test('brief stationary caption tap opens editing', () {
    final gate = CaptionGestureGate()..begin('caption', Offset.zero, 1, 0);
    expect(gate.end('caption', Offset.zero, 1, 0), isTrue);
  });

  test('drag, pinch, rotation and changed layer are not taps', () {
    final gate = CaptionGestureGate()..begin('caption', Offset.zero, 1, 0);
    gate.update(ScaleUpdateDetails(focalPointDelta: const Offset(12, 0)));
    expect(gate.end('caption', Offset.zero, 1, 0), isFalse);

    gate.begin('caption', Offset.zero, 1, 0);
    gate.update(ScaleUpdateDetails(pointerCount: 2, scale: 1.2));
    expect(gate.end('caption', Offset.zero, 1, 0), isFalse);

    gate.begin('caption', Offset.zero, 1, 0);
    expect(gate.end('caption', Offset.zero, 1.15, .2), isFalse);

    gate.begin('caption', Offset.zero, 1, 0);
    expect(gate.end('other', Offset.zero, 1, 0), isFalse);
  });
}
