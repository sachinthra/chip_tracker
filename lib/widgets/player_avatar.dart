import 'package:flutter/material.dart';

import '../core/utils/avatar_colors.dart';
import '../models/player.dart';

/// Circular avatar showing a player's initials on their assigned color.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.player, this.radius = 20});

  final Player player;
  final double radius;

  String get _initials {
    final parts = player.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = AvatarColors.fromHex(player.avatarColorHex);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}
