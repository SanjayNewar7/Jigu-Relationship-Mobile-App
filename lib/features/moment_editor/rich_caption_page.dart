import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config.dart';
import 'models/rich_caption.dart';
import 'controllers/rich_caption_controller.dart';

class RichCaptionPage extends StatefulWidget {
  const RichCaptionPage({
    super.key,
    required this.path,
    this.initial,
    this.photo,
  });
  final String path;
  final Uint8List? photo;
  final RichCaption? initial;
  @override
  State<RichCaptionPage> createState() => _RichCaptionPageState();
}

class _RichCaptionPageState extends State<RichCaptionPage> {
  late final controller = RichCaptionController(initial: widget.initial);
  late String font = widget.initial?.font ?? 'Sniglet';
  late double size = widget.initial?.size ?? 28;
  late TextAlign alignment = widget.initial?.alignment ?? TextAlign.center;
  late int background = widget.initial?.background ?? 1;
  bool bold = false, italic = false, underline = false;
  double hue = 330;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void finish() {
    if (controller.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(
      context,
      RichCaption(
        text: controller.text,
        marks: List.of(controller.marks),
        font: font,
        size: size,
        alignment: alignment,
        background: background,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    resizeToAvoidBottomInset: true,
    body: Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: .5,
            child: widget.photo == null
                ? Image.file(File(widget.path), fit: BoxFit.contain)
                : Image.memory(widget.photo!, fit: BoxFit.contain),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Cancel caption',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'A little word from you',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: finish,
                    child: const Text(
                      'Done',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        maxLines: null,
                        maxLength: 300,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(300),
                        ],
                        textAlign: alignment,
                        style: TextStyle(
                          fontFamily: font,
                          fontSize: size,
                          height: 1.2,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Say something lovely...',
                          hintStyle: TextStyle(
                            color: Colors.white54,
                            fontSize: size,
                          ),
                          counterText: '',
                          fillColor: background == 1
                              ? Colors.black54
                              : background == 2
                              ? Colors.white
                              : Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                color: const Color(0xe6221820),
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _tool(
                            'Bold selected text',
                            Icons.format_bold,
                            bold,
                            () {
                              setState(() => bold = !bold);
                              controller.format(
                                (mark) => mark.copy(bold: bold),
                              );
                            },
                          ),
                          _tool(
                            'Italic selected text',
                            Icons.format_italic,
                            italic,
                            () {
                              setState(() => italic = !italic);
                              controller.format(
                                (mark) => mark.copy(italic: italic),
                              );
                            },
                          ),
                          _tool(
                            'Underline selected text',
                            Icons.format_underlined,
                            underline,
                            () {
                              setState(() => underline = !underline);
                              controller.format(
                                (mark) => mark.copy(underline: underline),
                              );
                            },
                          ),
                          _tool(
                            'Caption alignment',
                            alignment == TextAlign.center
                                ? Icons.format_align_center
                                : alignment == TextAlign.left
                                ? Icons.format_align_left
                                : Icons.format_align_right,
                            false,
                            () => setState(
                              () => alignment = alignment == TextAlign.center
                                  ? TextAlign.left
                                  : alignment == TextAlign.left
                                  ? TextAlign.right
                                  : TextAlign.center,
                            ),
                          ),
                          _tool(
                            'Caption background',
                            Icons.format_color_fill,
                            background != 0,
                            () => setState(
                              () => background = (background + 1) % 3,
                            ),
                          ),
                          for (final color in [
                            Colors.white,
                            Colors.black,
                            coral,
                            sage,
                          ])
                            IconButton(
                              tooltip: color == Colors.white
                                  ? 'White text'
                                  : color == Colors.black
                                  ? 'Black text'
                                  : color == coral
                                  ? 'Lily pink text'
                                  : 'Sage text',
                              onPressed: () => controller.format(
                                (mark) => mark.copy(color: color.toARGB32()),
                              ),
                              icon: CircleAvatar(
                                radius: 9,
                                backgroundColor: color,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.palette_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        Expanded(
                          child: Slider(
                            value: hue,
                            min: 0,
                            max: 360,
                            activeColor: HSVColor.fromAHSV(
                              1,
                              hue,
                              .8,
                              1,
                            ).toColor(),
                            onChanged: (value) {
                              setState(() => hue = value);
                              controller.format(
                                (mark) => mark.copy(
                                  color: HSVColor.fromAHSV(
                                    1,
                                    value,
                                    .8,
                                    1,
                                  ).toColor().toARGB32(),
                                ),
                              );
                            },
                          ),
                        ),
                        const Icon(
                          Icons.text_fields,
                          color: Colors.white,
                          size: 18,
                        ),
                        Expanded(
                          child: Slider(
                            value: size,
                            min: 16,
                            max: 52,
                            activeColor: coral,
                            onChanged: (value) => setState(() => size = value),
                          ),
                        ),
                      ],
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            {
                                  'Lily': 'Sniglet',
                                  'Classic': 'sans-serif',
                                  'Story': 'serif',
                                  'Typewriter': 'monospace',
                                }.entries
                                .map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontFamily: entry.value,
                                        ),
                                      ),
                                      selected: font == entry.value,
                                      onSelected: (_) =>
                                          setState(() => font = entry.value),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _tool(
    String label,
    IconData icon,
    bool selected,
    VoidCallback callback,
  ) => IconButton(
    tooltip: label,
    onPressed: callback,
    icon: Icon(icon, color: selected ? coral : Colors.white),
  );
}
