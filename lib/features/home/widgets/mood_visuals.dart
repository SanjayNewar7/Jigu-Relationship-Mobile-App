import 'package:flutter/material.dart';
import '../../../core/config.dart';
import '../models/couple_quote_bank.dart';

extension MoodVisuals on JiguMood {
  String get asset => 'assets/moods/$name.png';
  Color get tint => const [
    Color(0xFFD75B91),
    Color(0xFFE68B46),
    Color(0xFF9170CC),
    Color(0xFF47A386),
    Color(0xFFE17D9E),
    Color(0xFFE46B65),
    Color(0xFF677DC8),
    Color(0xFF4A9BB6),
  ][index];
}

/// Quiet, opaque surfaces keep these small controls crisp over the Today backdrop.
class ReflectionSurface extends StatelessWidget {
  const ReflectionSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xFFFFFCFA),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFEADFE3)),
    ),
    child: child,
  );
}

class MoodPicker extends StatelessWidget {
  const MoodPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final JiguMood? selected;
  final ValueChanged<JiguMood> onSelected;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns =
          box.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.2
          ? 4
          : 2;
      final width = (box.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final mood in JiguMood.values)
            SizedBox(
              width: width,
              child: Semantics(
                selected: selected == mood,
                child: Material(
                  color: selected == mood
                      ? mood.tint.withValues(alpha: .12)
                      : const Color(0xFFF7F3F2),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onSelected(mood),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 116),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected == mood
                              ? mood.tint
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          Image.asset(
                            mood.asset,
                            width: 60,
                            height: 60,
                            cacheWidth: 192,
                            cacheHeight: 192,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                            excludeFromSemantics: true,
                            gaplessPlayback: true,
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              mood.title,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, color: plum),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
