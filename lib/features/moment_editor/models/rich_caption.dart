import 'package:flutter/material.dart';

@immutable
class CaptionMark {
  const CaptionMark({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.color = 0xffffffff,
  });
  final bool bold, italic, underline;
  final int color;
  CaptionMark copy({bool? bold, bool? italic, bool? underline, int? color}) =>
      CaptionMark(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        color: color ?? this.color,
      );
  Map<String, dynamic> toMap() => {
    'b': bold,
    'i': italic,
    'u': underline,
    'c': color,
  };
  factory CaptionMark.fromMap(Map<String, dynamic> map) => CaptionMark(
    bold: map['b'] == true,
    italic: map['i'] == true,
    underline: map['u'] == true,
    color: map['c'] as int? ?? 0xffffffff,
  );
  TextStyle get style => TextStyle(
    color: Color(color),
    fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    decoration: underline ? TextDecoration.underline : TextDecoration.none,
  );
  @override
  bool operator ==(Object other) =>
      other is CaptionMark &&
      bold == other.bold &&
      italic == other.italic &&
      underline == other.underline &&
      color == other.color;
  @override
  int get hashCode => Object.hash(bold, italic, underline, color);
}

class RichCaption {
  RichCaption({
    required this.text,
    required this.marks,
    this.font = 'Sniglet',
    this.size = 28,
    this.alignment = TextAlign.center,
    this.background = 1,
  });
  final String text, font;
  final List<CaptionMark> marks;
  final double size;
  final TextAlign alignment;
  final int background;
  Map<String, dynamic> toMap() => {
    'text': text,
    'marks': marks.map((m) => m.toMap()).toList(),
    'font': font,
    'size': size,
    'align': alignment.index,
    'background': background,
  };
  factory RichCaption.fromMap(Map<String, dynamic> map) => RichCaption(
    text: map['text'],
    marks: (map['marks'] as List)
        .map((v) => CaptionMark.fromMap(Map<String, dynamic>.from(v)))
        .toList(),
    font: map['font'],
    size: (map['size'] as num).toDouble(),
    alignment: TextAlign.values[map['align']],
    background: map['background'],
  );
  TextSpan get span => captionSpan(
    text,
    marks,
    TextStyle(fontFamily: font, fontSize: size, height: 1.2),
  );
  Widget render() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: background == 1
          ? const Color(0xb3000000)
          : background == 2
          ? const Color(0xe6ffffff)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text.rich(
      span,
      textAlign: alignment,
      textScaler: TextScaler.noScaling,
    ),
  );
}

TextSpan captionSpan(String text, List<CaptionMark> marks, TextStyle? base) {
  final spans = <TextSpan>[];
  var start = 0;
  while (start < text.length) {
    final mark = start < marks.length ? marks[start] : const CaptionMark();
    var end = start + 1;
    while (end < text.length &&
        end < marks.length &&
        (marks[end] == mark ||
            (text.codeUnitAt(end) >= 0xdc00 &&
                text.codeUnitAt(end) <= 0xdfff))) {
      end++;
    }
    spans.add(TextSpan(text: text.substring(start, end), style: mark.style));
    start = end;
  }
  return TextSpan(style: base, children: spans);
}
