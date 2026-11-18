import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/moment_image_service.dart';

class MomentPhotoView extends StatefulWidget {
  const MomentPhotoView({
    super.key,
    required this.moments,
    this.initialIndex = 0,
    this.imageLoader,
  });

  final List<Map<String, dynamic>> moments;
  final int initialIndex;
  final Future<File> Function(Map<String, dynamic>)? imageLoader;

  @override
  State<MomentPhotoView> createState() => _MomentPhotoViewState();
}

class _MomentPhotoViewState extends State<MomentPhotoView> {
  late final PageController controller;
  late int index;

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex.clamp(0, widget.moments.length - 1);
    controller = PageController(initialPage: index);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void move(int direction) {
    final next = index + direction;
    if (next >= 0 && next < widget.moments.length) {
      controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: const Color(0xFF18131E),
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: controller,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.moments.length,
              onPageChanged: (value) => setState(() => index = value),
              itemBuilder: (context, page) => _ZoomablePhoto(
                key: ValueKey(widget.moments[page]['id']),
                moment: widget.moments[page],
                imageLoader: widget.imageLoader,
                onSwipe: move,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Close photo',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(CupertinoIcons.xmark),
                    ),
                    const Spacer(),
                    if (widget.moments.length > 1)
                      Text(
                        '${index + 1} / ${widget.moments.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({
    super.key,
    required this.moment,
    required this.onSwipe,
    this.imageLoader,
  });
  final Map<String, dynamic> moment;
  final ValueChanged<int> onSwipe;
  final Future<File> Function(Map<String, dynamic>)? imageLoader;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  late final TransformationController transformation;
  late final Future<File> photo;
  bool zoomed = false;
  Offset? gestureStart;
  int pointers = 0;

  @override
  void initState() {
    super.initState();
    transformation = TransformationController()..addListener(onZoom);
    photo = (widget.imageLoader ?? MomentImageService().localFile)(
      widget.moment,
    );
  }

  void onZoom() {
    final next = transformation.value.getMaxScaleOnAxis() > 1.01;
    if (next != zoomed && mounted) setState(() => zoomed = next);
  }

  @override
  void dispose() {
    transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, viewport) => Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        pointers++;
        gestureStart = pointers == 1 ? event.position : null;
      },
      onPointerUp: (event) {
        if (pointers == 1 && gestureStart != null && !zoomed) {
          final movement = event.position - gestureStart!;
          if (movement.dx.abs() > 85 &&
              movement.dx.abs() > movement.dy.abs() * 1.25) {
            widget.onSwipe(movement.dx < 0 ? 1 : -1);
          }
        }
        pointers = (pointers - 1).clamp(0, 10);
        gestureStart = null;
      },
      onPointerCancel: (_) {
        pointers = 0;
        gestureStart = null;
      },
      child: InteractiveViewer(
        transformationController: transformation,
        minScale: 1,
        maxScale: 5,
        panEnabled: zoomed,
        constrained: false,
        child: SizedBox(
          width: viewport.maxWidth,
          height: viewport.maxHeight,
          child: FutureBuilder<File>(
            future: photo,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'This moment could not load.',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CupertinoActivityIndicator());
              }
              return Image.file(snapshot.data!, fit: BoxFit.contain);
            },
          ),
        ),
      ),
    ),
  );
}
