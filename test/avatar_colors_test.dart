import 'package:flutter_test/flutter_test.dart';
import 'package:chip_tracker/core/utils/avatar_colors.dart';

void main() {
  group('AvatarColors', () {
    test('assigns distinct colors until the palette is exhausted', () {
      final used = <String>[];
      for (var i = 0; i < AvatarColors.palette.length; i++) {
        final color = AvatarColors.next(used);
        expect(used, isNot(contains(color)));
        used.add(color);
      }
      expect(used.toSet().length, AvatarColors.palette.length);
    });

    test('cycles once the palette is full', () {
      final all = List<String>.from(AvatarColors.palette);
      final next = AvatarColors.next(all);
      expect(AvatarColors.palette, contains(next));
    });

    test('parses hex into an opaque color', () {
      final color = AvatarColors.fromHex('#E53935');
      expect(color.a, 1.0);
    });
  });
}
