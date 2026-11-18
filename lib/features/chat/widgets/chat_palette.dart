import 'package:flutter/material.dart';

class ChatPalette {
  const ChatPalette(
    this.background,
    this.sent,
    this.received,
    this.ink,
    this.muted,
  );
  final Color background, sent, received, ink, muted;
  static const names = [
    'lily',
    'sage',
    'midnight',
    'rose',
    'ocean',
    'lavender',
    'sunset',
    'cocoa',
  ];
  static ChatPalette forName(String name) => switch (name) {
    'sage' => const ChatPalette(
      Color(0xFFF2F5EF),
      Color(0xFF587158),
      Colors.white,
      Color(0xFF243C2B),
      Color(0xFF667466),
    ),
    'midnight' => const ChatPalette(
      Color(0xFF211D29),
      Color(0xFF805C81),
      Color(0xFF36303F),
      Color(0xFFF9EDF6),
      Color(0xFFC5B5C8),
    ),
    'rose' => const ChatPalette(
      Color(0xFFFFE9EE),
      Color(0xFF983F58),
      Color(0xFFFFF9FA),
      Color(0xFF582735),
      Color(0xFF875B67),
    ),
    'ocean' => const ChatPalette(
      Color(0xFFEAF5F7),
      Color(0xFF246A80),
      Colors.white,
      Color(0xFF234754),
      Color(0xFF597780),
    ),
    'lavender' => const ChatPalette(
      Color(0xFFF2ECFA),
      Color(0xFF7854A1),
      Colors.white,
      Color(0xFF47335D),
      Color(0xFF79658F),
    ),
    'sunset' => const ChatPalette(
      Color(0xFFFFF0E5),
      Color(0xFFAA5139),
      Color(0xFFFFFAF5),
      Color(0xFF623928),
      Color(0xFF896957),
    ),
    'cocoa' => const ChatPalette(
      Color(0xFF2B221F),
      Color(0xFF846051),
      Color(0xFF40332D),
      Color(0xFFFFF0E7),
      Color(0xFFD0B9AA),
    ),
    _ => const ChatPalette(
      Color(0xFFFFF6F8),
      Color(0xFFAB5277),
      Colors.white,
      Color(0xFF613348),
      Color(0xFF806674),
    ),
  };
}
