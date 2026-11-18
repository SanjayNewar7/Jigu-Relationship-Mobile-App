import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'chat_palette.dart';

class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key, required this.name, required this.child});
  final String name;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.forName(name);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.background,
            Color.alphaBlend(
              palette.sent.withValues(alpha: .10),
              palette.background,
            ),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _WallpaperPainter(palette.sent.withValues(alpha: .055), name),
        child: child,
      ),
    );
  }
}

class _WallpaperPainter extends CustomPainter {
  _WallpaperPainter(this.color, this.name);
  final Color color;
  final String name;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (double y = 40; y < size.height; y += 140) {
      for (double x = 30; x < size.width; x += 130) {
        canvas.save();
        canvas.translate(x, y);
        if (name == 'ocean' || name == 'sunset') {
          final path = Path()
            ..moveTo(-22, 0)
            ..quadraticBezierTo(-10, -16, 0, 0)
            ..quadraticBezierTo(10, 16, 22, 0);
          canvas.drawPath(path, paint);
        } else {
          for (var i = 0; i < 6; i++) {
            canvas.rotate(math.pi / 3);
            canvas.drawOval(const Rect.fromLTWH(-5, -25, 10, 25), paint);
          }
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_WallpaperPainter old) =>
      old.color != color || old.name != name;
}
