import 'package:flutter/material.dart';
import '../config.dart';
import 'lily_bloom.dart';

class LilyBackdrop extends StatelessWidget {
  const LilyBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFBFA), Color(0xFFF9E5ED), Color(0xFFF4F6EF)],
          ),
        ),
      ),
      const Positioned(
        top: -110,
        right: -130,
        child: _Glow(color: Color(0xFFF4C6D8), size: 430),
      ),
      const Positioned(
        bottom: -150,
        left: -190,
        child: _Glow(color: Color(0xFFD8E4D7), size: 490),
      ),
      const Positioned(
        right: -75,
        top: 90,
        child: IgnorePointer(
          child: ExcludeSemantics(child: LilyBloom(size: 280, opacity: .12)),
        ),
      ),
      const Positioned(
        left: -50,
        bottom: 90,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: LilyBloom(size: 180, color: sage, opacity: .08),
          ),
        ),
      ),
      child,
    ],
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}
