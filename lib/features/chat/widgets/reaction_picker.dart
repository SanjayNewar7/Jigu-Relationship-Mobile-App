import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'chat_palette.dart';

Future<String?> pickReaction(BuildContext context, ChatPalette palette) =>
    showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: palette.received,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .55,
          width: double.infinity,
          child: EmojiPicker(
            onEmojiSelected: (_, emoji) => Navigator.pop(context, emoji.emoji),
            config: Config(
              checkPlatformCompatibility: false,
              emojiViewConfig: EmojiViewConfig(
                columns: 8,
                backgroundColor: palette.received,
              ),
              categoryViewConfig: CategoryViewConfig(
                initCategory: Category.SMILEYS,
                recentTabBehavior: RecentTabBehavior.RECENT,
                backgroundColor: palette.received,
                indicatorColor: palette.sent,
                iconColorSelected: palette.sent,
              ),
              bottomActionBarConfig: BottomActionBarConfig(
                backgroundColor: palette.received,
                buttonColor: palette.sent,
                showBackspaceButton: false,
              ),
            ),
          ),
        ),
      ),
    );

Future<String?> reactionMenu(
  BuildContext context,
  Rect anchor,
  List<String> emojis,
  String? selected,
  ChatPalette palette, {
  required bool mine,
  required bool text,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black38,
    builder: (context) => LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 24).clamp(0.0, 350.0);
        final top = (anchor.top - 70).clamp(
          24.0,
          (constraints.maxHeight - 340).clamp(24.0, double.infinity),
        );
        return Stack(
          children: [
            Positioned(
              top: top,
              left: ((constraints.maxWidth - width) / 2),
              width: width,
              child: Material(
                color: palette.received,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight - top - 16,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('React or reply'),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              for (final emoji in emojis)
                                Expanded(
                                  child: InkWell(
                                    onTap: () => Navigator.pop(context, emoji),
                                    child: Container(
                                      alignment: Alignment.center,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: selected == emoji
                                            ? palette.sent.withValues(
                                                alpha: .18,
                                              )
                                            : null,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontFamily: '',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Another reaction',
                                onPressed: () =>
                                    Navigator.pop(context, 'custom'),
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.reply_rounded),
                          title: const Text('Reply to this message'),
                          onTap: () => Navigator.pop(context, 'reply'),
                        ),
                        if (text)
                          ListTile(
                            leading: const Icon(Icons.copy_rounded),
                            title: const Text('Copy'),
                            onTap: () => Navigator.pop(context, 'copy'),
                          ),
                        ListTile(
                          leading: const Icon(Icons.tune_rounded),
                          title: const Text('Customize reactions'),
                          onTap: () => Navigator.pop(context, 'customize'),
                        ),
                        if (mine)
                          ListTile(
                            leading: const Icon(Icons.undo_rounded),
                            title: const Text('Unsend'),
                            onTap: () => Navigator.pop(context, 'unsend'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
