import 'dart:io';
import '../../../core/errors/app_error.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/config.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/lily_bloom.dart';
import '../../../services/moment_image_service.dart';
import '../views/moment_photo_view.dart';

class MomentCard extends StatefulWidget {
  const MomentCard({
    super.key,
    required this.moment,
    this.height = 320,
    this.onLike,
    this.onSave,
    this.onDelete,
    this.galleryMoments,
    this.galleryIndex = 0,
    this.onPrevious,
    this.onNext,
  });
  final Map<String, dynamic>? moment;
  final double height;
  final List<Map<String, dynamic>>? galleryMoments;
  final int galleryIndex;
  final VoidCallback? onPrevious, onNext;
  final Future<void> Function(Map<String, dynamic> moment)? onLike,
      onSave,
      onDelete;
  @override
  State<MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<MomentCard> {
  Future<File>? photo;
  bool working = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant MomentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moment?['storage_path'] != widget.moment?['storage_path']) {
      load();
    }
  }

  void load() {
    photo = widget.moment == null
        ? null
        : MomentImageService().localFile(widget.moment!);
  }

  Future<void> perform(
    Future<void> Function(Map<String, dynamic>)? callback, {
    String? success,
  }) async {
    if (callback == null || working || widget.moment == null) return;
    setState(() => working = true);
    try {
      await callback(widget.moment!);
      if (success != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppError.message(
                error,
                fallback: 'Could not update this moment. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> confirmDelete() async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this moment?'),
        content: const Text(
          'It will leave your shared moments. A photo your partner liked stays in their private gallery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (delete == true) await perform(widget.onDelete);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.moment == null) {
      return GlassSurface(
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LilyBloom(size: 105),
              SizedBox(height: 24),
              Text(
                'A memory will bloom here',
                style: TextStyle(fontSize: 21, color: plum),
              ),
              SizedBox(height: 8),
              Text('Your first photo is the beginning.'),
            ],
          ),
        ),
      );
    }
    final likes = widget.moment!['moment_likes'] as List? ?? const [];
    final liked = likes.any(
      (item) => item is Map && item['user_id'] == db.auth.currentUser?.id,
    );
    final own = widget.moment!['author_id'] == db.auth.currentUser?.id;
    final active =
        widget.moment!['deleted_at'] == null &&
        (DateTime.tryParse(
              widget.moment!['expires_at']?.toString() ?? '',
            )?.isAfter(DateTime.now()) ??
            false);
    final showActions =
        widget.onLike != null ||
        widget.onSave != null ||
        widget.onDelete != null;
    return GlassSurface(
      padding: const EdgeInsets.all(7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: widget.height,
              child: FutureBuilder<File>(
                future: photo,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return _error();
                  if (!snapshot.hasData) {
                    return const Center(child: CupertinoActivityIndicator());
                  }
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MomentPhotoView(
                          moments: widget.galleryMoments ?? [widget.moment!],
                          initialIndex: widget.galleryMoments == null
                              ? 0
                              : widget.galleryIndex,
                        ),
                      ),
                    ),
                    child: Image.file(
                      snapshot.data!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _error(),
                    ),
                  );
                },
              ),
            ),
          ),
          if (showActions)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  _CompactAction(
                    tooltip: liked ? 'Unlike moment' : 'Like moment',
                    onPressed: working || (!active && !liked)
                        ? null
                        : () => perform(widget.onLike),
                    icon: liked
                        ? CupertinoIcons.heart_fill
                        : CupertinoIcons.heart,
                    color: liked ? coral : plum,
                  ),
                  Text(
                    '${likes.length}',
                    style: const TextStyle(color: inkSoft),
                  ),
                  _CompactAction(
                    tooltip: 'Save to phone gallery',
                    onPressed: working
                        ? null
                        : () => perform(
                            widget.onSave,
                            success: 'Saved to your phone gallery',
                          ),
                    icon: CupertinoIcons.arrow_down_to_line,
                    color: plum,
                  ),
                  if (widget.galleryMoments != null &&
                      widget.galleryMoments!.length > 1 &&
                      (widget.onPrevious != null || widget.onNext != null)) ...[
                    const Spacer(),
                    _CompactAction(
                      tooltip: 'Previous moment',
                      width: 28,
                      size: 17,
                      onPressed: widget.onPrevious,
                      icon: CupertinoIcons.chevron_left,
                      color: plum,
                    ),
                    Text(
                      '${widget.galleryIndex + 1}/${widget.galleryMoments!.length}',
                      style: const TextStyle(fontSize: 12, color: inkSoft),
                    ),
                    _CompactAction(
                      tooltip: 'Next moment',
                      width: 28,
                      size: 17,
                      onPressed: widget.onNext,
                      icon: CupertinoIcons.chevron_right,
                      color: plum,
                    ),
                  ],
                  const Spacer(),
                  if (own && active && widget.onDelete != null)
                    _CompactAction(
                      tooltip: 'Remove shared moment',
                      onPressed: working ? null : confirmDelete,
                      icon: CupertinoIcons.trash,
                      color: inkSoft,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _error() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(CupertinoIcons.photo, color: inkSoft, size: 30),
        const SizedBox(height: 10),
        const Text('This moment could not load.'),
        TextButton(
          onPressed: () => setState(load),
          child: const Text('Try again'),
        ),
      ],
    ),
  );
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.width = 36,
    this.size = 21,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final double width, size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: width,
          height: 40,
          child: Center(
            child: Icon(
              icon,
              size: size,
              color: onPressed == null ? color.withValues(alpha: .35) : color,
            ),
          ),
        ),
      ),
    ),
  );
}
