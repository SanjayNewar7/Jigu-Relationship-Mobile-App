import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'chat_palette.dart';

class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key, required this.palette, required this.name});
  final ChatPalette palette;
  final String name;
  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();
  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${widget.name} is typing',
    liveRegion: true,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: widget.palette.received,
            borderRadius: BorderRadius.circular(22),
          ),
          child: AnimatedBuilder(
            animation: animation,
            builder: (_, child) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        MediaQuery.disableAnimationsOf(context)
                            ? 0
                            : -3 *
                                  math.sin(
                                    animation.value * 2 * math.pi - i * .7,
                                  ),
                      ),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: widget.palette.muted,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
