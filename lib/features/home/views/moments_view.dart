import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/jigu_controls.dart';
import '../widgets/moment_card.dart';

class MomentsView extends StatefulWidget {
  const MomentsView({
    super.key,
    required this.moments,
    required this.onRefresh,
    this.likedMoments = const [],
    this.onLike,
    this.onSave,
    this.onDelete,
  });
  final List<Map<String, dynamic>> moments, likedMoments;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Map<String, dynamic>)? onLike, onSave, onDelete;
  @override
  State<MomentsView> createState() => _MomentsViewState();
}

class _MomentsViewState extends State<MomentsView> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    final photos = selected == 0 ? widget.moments : widget.likedMoments;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        key: const PageStorageKey('moments'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 130),
        itemCount: photos.isEmpty ? 2 : photos.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeading(
                  eyebrow: 'OUR STORY',
                  title: 'Little things, kept.',
                  subtitle: 'Share a moment, or keep a favorite close.',
                ),
                CupertinoSlidingSegmentedControl<int>(
                  groupValue: selected,
                  children: const {
                    0: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      child: Text('Shared'),
                    ),
                    1: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      child: Text('Liked'),
                    ),
                  },
                  onValueChanged: (value) {
                    if (value != null) setState(() => selected = value);
                  },
                ),
                const SizedBox(height: 18),
              ],
            );
          }
          if (photos.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 36),
              child: Center(
                child: Text('Your favorite moments will bloom here.'),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: MomentCard(
              key: ValueKey(photos[index - 1]['id']),
              moment: photos[index - 1],
              galleryMoments: photos,
              galleryIndex: index - 1,
              height: 280,
              onLike: widget.onLike,
              onSave: widget.onSave,
              onDelete: selected == 0 ? widget.onDelete : null,
            ),
          );
        },
      ),
    );
  }
}
