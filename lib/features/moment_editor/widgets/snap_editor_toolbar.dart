import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import '../../../core/config.dart';

class SnapEditorToolbar extends StatelessWidget {
  const SnapEditorToolbar({
    super.key,
    required this.editor,
    required this.onCaption,
  });
  final ProImageEditorState editor;
  final VoidCallback onCaption;
  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _button(
                  'Discard edits',
                  CupertinoIcons.xmark,
                  editor.closeEditor,
                ),
                const Spacer(),
                _button(
                  'Undo',
                  CupertinoIcons.arrow_uturn_left,
                  editor.canUndo ? editor.undoAction : null,
                ),
                const SizedBox(width: 8),
                _button(
                  'Redo',
                  CupertinoIcons.arrow_uturn_right,
                  editor.canRedo ? editor.redoAction : null,
                ),
              ],
            ),
          ),
          Positioned(
            top: 78,
            right: 12,
            child: Column(
              children: [
                _button('Add rich text', CupertinoIcons.textformat, onCaption),
                const SizedBox(height: 10),
                _button(
                  'Add emoji',
                  CupertinoIcons.smiley,
                  editor.openEmojiEditor,
                ),
                const SizedBox(height: 10),
                _button('Draw', CupertinoIcons.pencil, editor.openPaintEditor),
                const SizedBox(height: 10),
                _button(
                  'Crop and rotate',
                  CupertinoIcons.crop_rotate,
                  editor.openCropRotateEditor,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 14,
            left: 20,
            right: 20,
            child: Column(
              children: [
                const IgnorePointer(
                  child: Text(
                    'Drag to move. Pinch to resize or rotate. Tap to edit.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: coral,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: editor.doneEditing,
                    icon: const Icon(CupertinoIcons.heart_fill, size: 18),
                    label: const Text('Use photo'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _button(String label, IconData icon, VoidCallback? onTap) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
        ),
        child: IconButton(
          tooltip: label,
          onPressed: onTap,
          icon: Icon(
            icon,
            color: onTap == null ? Colors.white30 : Colors.white,
            size: 23,
          ),
        ),
      );
}
