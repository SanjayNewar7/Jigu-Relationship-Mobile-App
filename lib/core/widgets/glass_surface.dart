import 'dart:ui';
import 'package:flutter/material.dart';
import '../config.dart';

/// A bounded backdrop blur. Separate filters keep overlapping surfaces correct.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.radius = 28,
    this.opacity = .52,
    this.blur = 18,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius, opacity, blur;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: plum.withValues(alpha: .045),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: .85)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: opacity + .12),
                Colors.white.withValues(alpha: opacity),
              ],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    ),
  );
}
