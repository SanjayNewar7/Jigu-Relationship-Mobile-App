import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MessageGestures extends StatefulWidget {
  const MessageGestures({
    super.key,
    required this.child,
    required this.mine,
    required this.onReply,
    required this.onReact,
    required this.onMenu,
  });
  final Widget child;
  final bool mine;
  final VoidCallback onReply, onReact;
  final ValueChanged<Rect> onMenu;
  @override
  State<MessageGestures> createState() => _MessageGesturesState();
}

class _MessageGesturesState extends State<MessageGestures> {
  double distance = 0;
  bool crossed = false;
  void reset() => setState(() {
    distance = 0;
    crossed = false;
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onDoubleTap: widget.onReact,
    onLongPress: () {
      HapticFeedback.mediumImpact();
      final box = context.findRenderObject()! as RenderBox;
      widget.onMenu(box.localToGlobal(Offset.zero) & box.size);
    },
    onHorizontalDragUpdate: (details) {
      final next = (distance + details.delta.dx).clamp(
        widget.mine ? -64.0 : 0.0,
        widget.mine ? 0.0 : 64.0,
      );
      if (!crossed && next.abs() >= 56) {
        crossed = true;
        HapticFeedback.selectionClick();
      }
      setState(() => distance = next);
    },
    onHorizontalDragEnd: (_) {
      final reply = distance.abs() >= 56;
      reset();
      if (reply) widget.onReply();
    },
    onHorizontalDragCancel: reset,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      transform: Matrix4.translationValues(distance, 0, 0),
      child: widget.child,
    ),
  );
}
