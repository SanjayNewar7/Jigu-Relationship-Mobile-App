import 'package:flutter/material.dart';

class BotanicalFilter {
  const BotanicalFilter(this.name, this.subtitle, this.color);
  final String name, subtitle;
  final Color color;

  // Order is also the shader's preset ID. Keep Original at zero.
  static const presets = [
    BotanicalFilter('Original', 'Just as you captured it', Color(0xFFE8DDE2)),
    BotanicalFilter('Lily', 'Soft morning luminosity', Color(0xFFE6DFD5)),
    BotanicalFilter('Rose', 'Warm romantic blush', Color(0xFFD98A96)),
    BotanicalFilter('Peony', 'Crisp floral vibrancy', Color(0xFFC94A6A)),
    BotanicalFilter('Honey', 'Golden afternoon light', Color(0xFFF3C16E)),
    BotanicalFilter('Sunset', 'A little dusk nostalgia', Color(0xFFE87A4D)),
    BotanicalFilter('Cocoa', 'Warm espresso editorial', Color(0xFF8C624A)),
    BotanicalFilter('Sage', 'Calm botanical matte', Color(0xFFA3B8AA)),
    BotanicalFilter('Fern', 'Deep woodland richness', Color(0xFF4D8565)),
    BotanicalFilter('Ocean', 'Crisp coastal clarity', Color(0xFF63B3C9)),
    BotanicalFilter('Mist', 'Clean silver minimalism', Color(0xFFCBD3DA)),
    BotanicalFilter('Lavender', 'Dreamy pastel haze', Color(0xFFD4C2F0)),
    BotanicalFilter('Midnight', 'Deep nocturnal drama', Color(0xFF2A4066)),
  ];
}
