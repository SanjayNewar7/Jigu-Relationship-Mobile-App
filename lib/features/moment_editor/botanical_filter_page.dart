import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config.dart';
import 'models/botanical_filter.dart';
import 'services/botanical_renderer.dart';
import 'widgets/discard_moment_dialog.dart';

class BotanicalFilterPage extends StatefulWidget {
  const BotanicalFilterPage({
    super.key,
    required this.path,
    required this.onContinue,
  });
  final String path;
  final ValueChanged<Uint8List> onContinue;
  @override
  State<BotanicalFilterPage> createState() => _BotanicalFilterPageState();
}

class _BotanicalFilterPageState extends State<BotanicalFilterPage>
    with SingleTickerProviderStateMixin {
  BotanicalRenderer? renderer;
  late final AnimationController settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  final scroll = ScrollController();
  int selected = 0, next = 0;
  double progress = 0, direction = 0, distance = 0, intensity = .85;
  bool exporting = false, failed = false, closing = false;
  static const presets = BotanicalFilter.presets;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => failed = false);
    try {
      final loaded = await BotanicalRenderer.load(widget.path);
      if (!mounted) {
        loaded.dispose();
        return;
      }
      setState(() => renderer = loaded);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  void dispose() {
    settle.dispose();
    scroll.dispose();
    renderer?.dispose();
    super.dispose();
  }

  Future<void> close() async {
    if (closing || exporting) return;
    closing = true;
    final discard = await confirmDiscardMoment(context);
    if (!mounted) return;
    closing = false;
    if (discard) Navigator.pop(context);
  }

  void select(int index) {
    if (settle.isAnimating || exporting) return;
    HapticFeedback.selectionClick();
    setState(() {
      selected = index;
      next = index;
      progress = 0;
    });
    if (scroll.hasClients) {
      scroll.animateTo(
        (index * 82.0 - MediaQuery.sizeOf(context).width / 2 + 41).clamp(
          0.0,
          scroll.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void drag(DragUpdateDetails details, double width) {
    if (settle.isAnimating || exporting) return;
    distance += details.delta.dx;
    setState(() {
      direction = distance < 0 ? -1 : 1;
      next = (selected + (direction < 0 ? 1 : -1)) % presets.length;
      progress = (distance.abs() / width).clamp(0.0, 1.0);
    });
  }

  Future<void> release(double velocity, {bool cancel = false}) async {
    if (settle.isAnimating || exporting) return;
    final commit =
        !cancel &&
        (progress > .35 ||
            (velocity.abs() > 500 && velocity.sign == direction));
    final start = progress;
    final target = commit ? 1.0 : 0.0;
    void tick() {
      if (mounted) {
        setState(
          () => progress =
              start +
              (target - start) * Curves.easeOutCubic.transform(settle.value),
        );
      }
    }

    settle.addListener(tick);
    try {
      await settle.forward(from: 0).orCancel;
    } catch (_) {
      return;
    } finally {
      settle.removeListener(tick);
    }
    if (!mounted) return;
    final index = commit ? next : selected;
    select(index);
  }

  Future<void> continueEditing() async {
    if (exporting || settle.isAnimating) return;
    setState(() => exporting = true);
    try {
      final bytes = selected == 0
          ? await File(widget.path).readAsBytes()
          : await renderer!.export(selected, intensity);
      if (mounted) widget.onContinue(bytes);
    } catch (_) {
      if (mounted) {
        setState(() => exporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not prepare this photo. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = presets[progress > .5 ? next : selected];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF211B20),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: exporting ? null : close,
                      tooltip: 'Close editor',
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    const Expanded(
                      child: Column(
                        children: [
                          Text(
                            'A little atmosphere',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Sniglet',
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            'Swipe your photo to explore',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    if (renderer == null) {
                      return Center(
                        child: failed
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Filters could not load.',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  TextButton(
                                    onPressed: load,
                                    child: const Text('Try again'),
                                  ),
                                  TextButton(
                                    onPressed: continueEditing,
                                    child: const Text('Use original photo'),
                                  ),
                                ],
                              )
                            : const CircularProgressIndicator(color: coral),
                      );
                    }
                    return Center(
                      child: AspectRatio(
                        aspectRatio:
                            renderer!.image.width / renderer!.image.height,
                        child: LayoutBuilder(
                          builder: (_, imageBox) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragStart: (_) {
                              if (!settle.isAnimating) distance = 0;
                            },
                            onHorizontalDragUpdate: (d) =>
                                drag(d, imageBox.maxWidth),
                            onHorizontalDragEnd: (d) =>
                                release(d.primaryVelocity ?? 0),
                            onHorizontalDragCancel: () =>
                                release(0, cancel: true),
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _FilterPainter(
                                  renderer!,
                                  selected,
                                  next,
                                  progress,
                                  direction,
                                  intensity,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  children: [
                    Text(
                      shown.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontFamily: 'Sniglet',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      shown.subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 84,
                child: ListView.builder(
                  controller: scroll,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  itemCount: presets.length,
                  itemBuilder: (_, index) => SizedBox(
                    width: 82,
                    child: Semantics(
                      selected: selected == index,
                      button: true,
                      child: InkWell(
                        onTap: renderer == null ? null : () => select(index),
                        borderRadius: BorderRadius.circular(18),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: presets[index].color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected == index
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                index == 0
                                    ? Icons.filter_none_rounded
                                    : Icons.local_florist_outlined,
                                color: index == 12 ? Colors.white : plum,
                                size: 18,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              presets[index].name,
                              style: TextStyle(
                                fontSize: 11,
                                color: selected == index
                                    ? Colors.white
                                    : Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Text(
                      'Soft',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    Expanded(
                      child: Slider(
                        value: intensity,
                        activeColor: coral,
                        inactiveColor: Colors.white24,
                        label: '${(intensity * 100).round()}%',
                        onChanged:
                            selected == 0 || exporting || renderer == null
                            ? null
                            : (value) => setState(() => intensity = value),
                      ),
                    ),
                    const Text(
                      'Full',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: coral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: renderer == null || exporting
                        ? null
                        : continueEditing,
                    icon: exporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      exporting
                          ? 'Preparing your photo…'
                          : 'Continue to text & stickers',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPainter extends CustomPainter {
  _FilterPainter(
    this.renderer,
    this.current,
    this.next,
    this.progress,
    this.direction,
    this.intensity,
  );
  final BotanicalRenderer renderer;
  final int current, next;
  final double progress, direction, intensity;
  @override
  void paint(Canvas canvas, Size size) => renderer.paint(
    canvas,
    size,
    current,
    next,
    progress,
    direction,
    intensity,
  );
  @override
  bool shouldRepaint(_FilterPainter old) =>
      old.current != current ||
      old.next != next ||
      old.progress != progress ||
      old.direction != direction ||
      old.intensity != intensity;
}
