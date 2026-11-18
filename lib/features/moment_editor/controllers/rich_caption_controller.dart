import 'package:flutter/material.dart';
import '../models/rich_caption.dart';

/// Preserve per-character formatting across insertions, deletions and paste.
class RichCaptionController extends TextEditingController {
  RichCaptionController({RichCaption? initial})
    : marks = List.of(initial?.marks ?? []),
      super(text: initial?.text ?? '');
  List<CaptionMark> marks;
  CaptionMark typing = const CaptionMark();
  @override
  set value(TextEditingValue next) {
    final before = text;
    if (before != next.text) {
      var prefix = 0;
      while (prefix < before.length &&
          prefix < next.text.length &&
          before.codeUnitAt(prefix) == next.text.codeUnitAt(prefix)) {
        prefix++;
      }
      var suffix = 0;
      while (suffix < before.length - prefix &&
          suffix < next.text.length - prefix &&
          before.codeUnitAt(before.length - 1 - suffix) ==
              next.text.codeUnitAt(next.text.length - 1 - suffix)) {
        suffix++;
      }
      marks = [
        ...marks.take(prefix),
        ...List.filled(next.text.length - prefix - suffix, typing),
        ...marks.skip(before.length - suffix),
      ];
    }
    super.value = next;
  }

  void format(CaptionMark Function(CaptionMark) change) {
    typing = change(typing);
    final selection = value.selection;
    final start = selection.isValid && !selection.isCollapsed
        ? selection.start
        : 0;
    final end = selection.isValid && !selection.isCollapsed
        ? selection.end
        : text.length;
    for (var i = start; i < end && i < marks.length; i++) {
      marks[i] = change(marks[i]);
    }
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) => captionSpan(text, marks, style);
}
