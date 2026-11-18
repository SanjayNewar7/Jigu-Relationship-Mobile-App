import 'package:flutter/material.dart';
import '../../../models/chat_message.dart';
import '../../../services/chat_service.dart';
import 'chat_palette.dart';

class ReplyQuote extends StatelessWidget {
  const ReplyQuote({
    super.key,
    required this.message,
    this.parent,
    required this.mine,
    required this.palette,
    required this.name,
    required this.onTap,
  });
  final ChatMessage message;
  final ChatMessage? parent;
  final bool mine;
  final ChatPalette palette;
  final String name;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = mine ? Colors.white : palette.sent;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          border: Border(left: BorderSide(color: color, width: 3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!message.replyParentDeleted &&
                (message.replyKind ?? parent?.kind ?? 'text') != 'text') ...[
              ReplyThumbnail(
                parent: parent,
                kind: message.replyKind ?? parent?.kind ?? 'image',
                color: color,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    message.replyParentDeleted
                        ? 'Original message unavailable'
                        : message.replyPreview ?? 'A message',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: mine ? Colors.white70 : palette.ink,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReplyThumbnail extends StatefulWidget {
  const ReplyThumbnail({
    super.key,
    this.parent,
    required this.kind,
    required this.color,
  });
  final ChatMessage? parent;
  final String kind;
  final Color color;
  @override
  State<ReplyThumbnail> createState() => _ReplyThumbnailState();
}

class _ReplyThumbnailState extends State<ReplyThumbnail> {
  Future<String>? url;
  void resolve() {
    final parent = widget.parent;
    url =
        parent != null &&
            !parent.expired &&
            !parent.deleted &&
            ['image', 'gif'].contains(parent.kind)
        ? ChatService().mediaUrl(parent)
        : null;
  }

  @override
  void initState() {
    super.initState();
    resolve();
  }

  @override
  void didUpdateWidget(ReplyThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parent?.id != widget.parent?.id) resolve();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(switch (widget.kind) {
      'voice' => Icons.mic_rounded,
      'video' => Icons.videocam_rounded,
      'gif' => Icons.gif_rounded,
      _ => Icons.image_outlined,
    }, color: widget.color);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 36,
        height: 36,
        child: url == null
            ? fallback
            : FutureBuilder<String>(
                future: url,
                builder: (context, snapshot) => snapshot.hasData
                    ? Image.network(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => fallback,
                      )
                    : fallback,
              ),
      ),
    );
  }
}
