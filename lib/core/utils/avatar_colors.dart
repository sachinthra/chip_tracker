import 'package:flutter/material.dart';

/// A fixed palette of distinct avatar colors and helpers to assign/parse them.
class AvatarColors {
  AvatarColors._();

  static const List<String> palette = [
    '#E53935', // red
    '#8E24AA', // purple
    '#3949AB', // indigo
    '#039BE5', // blue
    '#00897B', // teal
    '#7CB342', // light green
    '#FDD835', // yellow
    '#FB8C00', // orange
    '#6D4C41', // brown
    '#546E7A', // blue grey
    '#D81B60', // pink
    '#00ACC1', // cyan
  ];

  /// Picks the first palette color not already in [used]; cycles once full.
  static String next(Iterable<String> used) {
    final usedSet = used.toSet();
    for (final color in palette) {
      if (!usedSet.contains(color)) return color;
    }
    return palette[usedSet.length % palette.length];
  }

  static Color fromHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16) ?? 0x607D8B;
    return Color(0xFF000000 | value);
  }
}
