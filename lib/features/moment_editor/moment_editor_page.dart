import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'controllers/caption_gesture_gate.dart';
import 'models/rich_caption.dart';
import 'rich_caption_page.dart';
import 'widgets/snap_editor_toolbar.dart';
import 'botanical_filter_page.dart';
import 'widgets/discard_moment_dialog.dart';

/// Local, non-destructive editing. Nothing uploads until the user confirms.
class MomentEditorPage extends StatefulWidget {
  const MomentEditorPage({super.key, required this.path});
  final String path;

  @override
  State<MomentEditorPage> createState() => _MomentEditorPageState();
}

class _MomentEditorPageState extends State<MomentEditorPage> {
  final editorKey = GlobalKey<ProImageEditorState>();
  final captionGesture = CaptionGestureGate();
  Uint8List? result;
  Uint8List? filteredPhoto;
  bool editingCaption = false;
  Future<void> caption(
    ProImageEditorState editor, [
    WidgetLayer? existing,
  ]) async {
    if (editingCaption) return;
    editingCaption = true;
    try {
      final metadata = existing?.meta?['jigu_caption'];
      final document = await Navigator.of(context).push<RichCaption>(
        MaterialPageRoute(
          builder: (_) => RichCaptionPage(
            path: widget.path,
            photo: filteredPhoto,
            initial: metadata is Map
                ? RichCaption.fromMap(Map<String, dynamic>.from(metadata))
                : null,
          ),
        ),
      );
      if (document == null || !mounted || !editor.mounted) return;
      final meta = {'jigu_caption': document.toMap()};
      if (existing == null) {
        editor.addLayer(
          WidgetLayer(
            widget: document.render(),
            width: (MediaQuery.sizeOf(context).width - 70)
                .clamp(180, 320)
                .toDouble(),
            meta: meta,
          ),
        );
      } else {
        final index = editor.activeLayers.indexWhere(
          (layer) => layer.id == existing.id,
        );
        if (index >= 0) {
          editor.replaceLayer(
            index: index,
            layer: existing.copyWith(widget: document.render(), meta: meta),
          );
        }
      }
    } finally {
      editingCaption = false;
    }
  }

  @override
  Widget build(BuildContext context) => filteredPhoto == null
      ? BotanicalFilterPage(
          path: widget.path,
          onContinue: (bytes) => setState(() => filteredPhoto = bytes),
        )
      : ProImageEditor.memory(
          filteredPhoto!,
          key: editorKey,
          callbacks: ProImageEditorCallbacks(
            mainEditorCallbacks: MainEditorCallbacks(
              onLayerTapDown: (layer) {
                captionGesture.begin(
                  layer.id,
                  layer.offset,
                  layer.scale,
                  layer.rotation,
                );
              },
              onScaleUpdate: captionGesture.update,
              onLayerTapUp: (layer) {
                final editor = editorKey.currentState;
                final wasTap = captionGesture.end(
                  layer.id,
                  layer.offset,
                  layer.scale,
                  layer.rotation,
                );
                if (wasTap &&
                    layer is WidgetLayer &&
                    layer.meta?['jigu_caption'] != null &&
                    editor != null) {
                  caption(editor, layer);
                }
              },
            ),
            onImageEditingComplete: (Uint8List bytes) async {
              result = bytes;
            },
            onCloseEditor: (_) {
              if (mounted) Navigator.pop(context, result);
            },
          ),
          configs: ProImageEditorConfigs(
            designMode: ImageEditorDesignMode.cupertino,
            mainEditor: MainEditorConfigs(
              tools: [
                SubEditorMode.text,
                SubEditorMode.emoji,
                SubEditorMode.paint,
                SubEditorMode.cropRotate,
              ],
              widgets: MainEditorWidgets(
                closeWarningDialog: (_) => confirmDiscardMoment(context),
                appBar: (editor, stream) => null,
                bottomBar: (editor, stream, key) => null,
                bodyItems: (editor, stream) => [
                  ReactiveWidget(
                    stream: stream,
                    builder: (_) => SnapEditorToolbar(
                      editor: editor,
                      onCaption: () => caption(editor),
                    ),
                  ),
                ],
              ),
            ),
            layerInteraction: const LayerInteractionConfigs(
              enableMobilePinchScale: true,
              enableMobilePinchRotate: true,
            ),
            textEditor: const TextEditorConfigs(
              customTextStyles: [
                TextStyle(fontFamily: 'Sniglet'),
                TextStyle(
                  fontFamily: 'sans-serif',
                  fontWeight: FontWeight.w700,
                ),
                TextStyle(fontFamily: 'serif', fontStyle: FontStyle.italic),
              ],
            ),
            imageGeneration: const ImageGenerationConfigs(
              outputFormat: OutputFormat.jpg,
              maxOutputSize: Size(2560, 2560),
              jpegQuality: 95,
            ),
          ),
        );
}
