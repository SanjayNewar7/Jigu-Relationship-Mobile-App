import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config.dart';

/// Six petals unfurl from a closed bud, followed by the flower's stamens.
class LilyBloom extends StatelessWidget {
  const LilyBloom({super.key, this.size = 80, this.color = coral,
    this.opacity = 1, this.bloom = 1});
  final double size, opacity, bloom;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _LilyPainter(color.withValues(alpha: opacity), bloom)),
  );
}

class _LilyPainter extends CustomPainter {
  const _LilyPainter(this.color, this.bloom);
  final Color color;
  final double bloom;
  double phase(double start, double end) =>
      Curves.easeInOutCubic.transform(((bloom-start)/(end-start)).clamp(0.0, 1.0));
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width/2, size.height*.54);
    canvas.scale(size.shortestSide/120);
    final leafOpen = phase(0, .65);
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.scale(side, 1);
      canvas.rotate(-.15 * (1-leafOpen));
      final leaf = Path()..moveTo(0, 14)
        ..cubicTo(18, 12, 38, 28, 46, 41)
        ..cubicTo(22, 37, 7, 32, 0, 14);
      canvas.drawPath(leaf, Paint()..shader = LinearGradient(
        colors: [sage.withValues(alpha: color.a), const Color(0xFFB7C39D).withValues(alpha: color.a)],
      ).createShader(const Rect.fromLTWH(0, 14, 46, 28)));
      canvas.restore();
    }
    const angles = [-math.pi/3, math.pi/3, math.pi, -2*math.pi/3, 0.0, 2*math.pi/3];
    for (var i=0; i<6; i++) {
      final open = phase(i*.035, .78+i*.035);
      canvas.save();
      canvas.rotate(angles[i]*open);
      canvas.scale(.12+.88*open, .64+.36*open);
      final tip = 3+3*open;
      final petal = Path()..moveTo(0, 4)
        ..cubicTo(-10, -6, -25, -27, -9, -42)
        ..cubicTo(-3, -49, 5, -53, tip, -55)
        ..cubicTo(2, -44, 25, -29, 17, -15)
        ..cubicTo(12, -4, 4, 1, 0, 4);
      canvas.drawPath(petal, Paint()..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [
          Color.lerp(color, Colors.white.withValues(alpha: color.a), .74)!,
          Color.lerp(color, Colors.white.withValues(alpha: color.a), .2)!,
          color, const Color(0xFFF6E8AD).withValues(alpha: color.a),
        ], stops: const [0, .28, .62, 1],
      ).createShader(const Rect.fromLTWH(-20, -55, 42, 59)));
      canvas.drawPath(Path()..moveTo(0, 2)..cubicTo(4,-14,-4,-34,tip,-52),
        Paint()..color=Colors.white.withValues(alpha: color.a*.5)
          ..style=PaintingStyle.stroke..strokeWidth=.7);
      if (open>.45) {
        for (var j=0;j<7;j++) {
          final x=(j.isEven ? -1 : 1)*(2.0+j%3*2);
          final y=-10.0-j*3.3;
          canvas.drawOval(Rect.fromCenter(center: Offset(x,y),width:1.1,height:2),
            Paint()..color=plum.withValues(alpha:color.a*.4*open));
        }
      }
      canvas.restore();
    }
    final center = phase(.5, 1);
    final filament = Paint()..color=const Color(0xFFB39A55).withValues(alpha:color.a*center)
      ..strokeWidth=1.1..strokeCap=StrokeCap.round;
    for (var i=0;i<6;i++) {
      final angle=i*math.pi/3;
      final tip=Offset(math.sin(angle)*14*center, math.cos(angle)*12*center-4);
      canvas.drawPath(Path()..moveTo(0,3)..quadraticBezierTo(tip.dx*.3,-3,tip.dx,tip.dy),filament..style=PaintingStyle.stroke);
      canvas.drawOval(Rect.fromCenter(center:tip,width:3,height:5),
        Paint()..color=const Color(0xFFC48637).withValues(alpha:color.a*center));
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _LilyPainter old) => old.color != color || old.bloom != bloom;
}
