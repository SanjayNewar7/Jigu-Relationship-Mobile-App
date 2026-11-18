import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Vector flowers stay sharp and transparent on every conversation theme.
class ThemeFlower extends StatelessWidget {
  const ThemeFlower({super.key, required this.name, required this.color});
  final String name;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$name flower',
    child: SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(painter: _Flower(name, color)),
    ),
  );
}

class _Flower extends CustomPainter {
  _Flower(this.name, this.color);
  final String name;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    const petals = {
      'lily': 6,
      'sage': 4,
      'midnight': 8,
      'rose': 9,
      'ocean': 5,
      'lavender': 3,
      'sunset': 12,
      'cocoa': 7,
    };
    final count = petals[name] ?? 6;
    final paint = Paint()..color = color;
    canvas.translate(size.width / 2, size.height / 2);
    for (var i = 0; i < count; i++) {
      canvas.save();
      canvas.rotate(i * 2 * math.pi / count);
      final path = Path()
        ..moveTo(0, 2)
        ..quadraticBezierTo(name == 'rose' ? 11 : 7, -7, 0, -14)
        ..quadraticBezierTo(-7, -7, 0, 2);
      canvas.drawPath(path, paint);
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, 3, Paint()..color = const Color(0xFFF4C977));
  }

  @override
  bool shouldRepaint(_Flower old) => old.name != name || old.color != color;
}
