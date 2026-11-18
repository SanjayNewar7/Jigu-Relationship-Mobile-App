import 'package:flutter/material.dart';
import 'moment_card.dart';

class MomentCarousel extends StatefulWidget {
  const MomentCarousel({
    super.key,
    required this.moments,
    this.onLike,
    this.onSave,
    this.onDelete,
  });

  final List<Map<String, dynamic>> moments;
  final Future<void> Function(Map<String, dynamic>)? onLike, onSave, onDelete;

  @override
  State<MomentCarousel> createState() => _MomentCarouselState();
}

class _MomentCarouselState extends State<MomentCarousel> {
  int index = 0;
  double dragDistance = 0;

  @override
  void didUpdateWidget(covariant MomentCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.moments.isEmpty) {
      index = 0;
      return;
    }
    final selectedId = index < oldWidget.moments.length
        ? oldWidget.moments[index]['id']
        : null;
    final retained = widget.moments.indexWhere((m) => m['id'] == selectedId);
    index = retained < 0 ? index.clamp(0, widget.moments.length - 1) : retained;
  }

  void move(int direction) {
    final next = index + direction;
    if (next >= 0 && next < widget.moments.length) {
      setState(() => index = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.moments.isEmpty) {
      return const MomentCard(moment: null);
    }
    final moment = widget.moments[index];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => dragDistance = 0,
          onHorizontalDragUpdate: (details) =>
              dragDistance += details.primaryDelta ?? 0,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (dragDistance < -40 || velocity < -250) move(1);
            if (dragDistance > 40 || velocity > 250) move(-1);
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOut,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: MomentCard(
              key: ValueKey(moment['id']),
              moment: moment,
              galleryMoments: widget.moments,
              galleryIndex: index,
              onPrevious: index == 0 ? null : () => move(-1),
              onNext: index == widget.moments.length - 1 ? null : () => move(1),
              onLike: widget.onLike,
              onSave: widget.onSave,
              onDelete: widget.onDelete,
            ),
          ),
        ),
      ],
    );
  }
}
