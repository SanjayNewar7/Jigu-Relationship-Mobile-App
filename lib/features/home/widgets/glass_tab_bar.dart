import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/config.dart';
import '../../../core/widgets/glass_surface.dart';

class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.onShare,
  });
  final int selected;
  final ValueChanged<int> onChanged;
  final VoidCallback? onShare;
  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: 30,
    blur: 24,
    padding: const EdgeInsets.all(7),
    opacity: .65,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth / 5;
        const icons = [
          CupertinoIcons.heart,
          CupertinoIcons.photo_on_rectangle,
          CupertinoIcons.calendar,
          CupertinoIcons.location,
        ];
        const labels = ['Today', 'Moments', 'Dates', 'Places'];
        return SizedBox(
          height: 58,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 210),
                curve: Curves.easeOutCubic,
                left: width * (selected < 2 ? selected : selected + 1),
                top: 0,
                bottom: 0,
                width: width,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .92),
                    borderRadius: BorderRadius.circular(23),
                  ),
                ),
              ),
              Row(
                children: List.generate(5, (slot) {
                  if (slot == 2) {
                    return Expanded(
                      child: Center(
                        child: IconButton.filled(
                          tooltip: 'Share a moment',
                          onPressed: onShare,
                          style: IconButton.styleFrom(
                            backgroundColor: coral,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const Icon(CupertinoIcons.plus, size: 27),
                        ),
                      ),
                    );
                  }
                  final index = slot < 2 ? slot : slot - 1;
                  return Expanded(
                    child: Semantics(
                      selected: selected == index,
                      button: true,
                      label: labels[index],
                      child: InkWell(
                        key: ValueKey('tab-$index'),
                        borderRadius: BorderRadius.circular(23),
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () => onChanged(index),
                        child: ExcludeSemantics(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                icons[index],
                                size: 21,
                                color: selected == index ? plum : inkSoft,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                labels[index],
                                style: TextStyle(
                                  fontFamily: 'Sniglet',
                                  fontSize: 11,
                                  color: selected == index ? plum : inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    ),
  );
}
