import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/widgets/lily_bloom.dart';
import '../../core/widgets/lily_backdrop.dart';

/// One timeline keeps the bloom, wordmark, and exit in sync even on a slow launch.
class SplashView extends StatefulWidget {
  const SplashView({super.key, this.onComplete});
  final VoidCallback? onComplete;
  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3100),
  );
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      animation.duration = const Duration(milliseconds: 700);
    }
    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onComplete?.call();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) animation.forward();
    });
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  double phase(
    double value,
    double begin,
    double end, [
    Curve curve = Curves.easeOutCubic,
  ]) => curve.transform(((value - begin) / (end - begin)).clamp(0.0, 1.0));
  @override
  Widget build(BuildContext context) => Scaffold(
    body: LilyBackdrop(
      child: Center(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, flower) {
            final value = MediaQuery.disableAnimationsOf(context)
                ? 1.0
                : animation.value;
            final bloom = phase(value, .05, .42, Curves.easeInOutCubic);
            final fade = phase(value, .02, .28);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  key: const ValueKey('lily-fade'),
                  opacity: fade,
                  child: Transform.translate(
                    offset: Offset(0, 24 * (1 - fade)),
                    child: Transform.scale(
                      scale: .92 + .08 * bloom,
                      child: Transform.rotate(
                        angle: -.025 * (1 - fade),
                        child: RepaintBoundary(
                          child: LilyBloom(
                            size: 200,
                            bloom: phase(value, .04, .58),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Semantics(
                  label: 'Jigu',
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(4, (index) {
                        final progress = phase(
                          value,
                          .30 + index * .06,
                          .53 + index * .06,
                        );
                        return Opacity(
                          key: ValueKey('letter-$index'),
                          opacity: progress,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - progress)),
                            child: Text(
                              'JIGU'[index],
                              style: const TextStyle(
                                fontSize: 52,
                                letterSpacing: 6,
                                color: plum,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Opacity(
                  opacity: phase(value, .65, .80),
                  child: const Text(
                    'a little place for us',
                    style: TextStyle(fontSize: 15, color: inkSoft),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
