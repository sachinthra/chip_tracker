import 'package:uuid/uuid.dart';

/// Where a player "came from" — a real Splitwise contact or a local-only guest.
enum PlayerSource { splitwise, ghost }

/// A seat at the table. Either a linked Splitwise friend or a "Ghost" player
/// who only exists inside this app (no Splitwise account required).
class Player {
  final String id;
  final String name;
  final PlayerSource source;

  /// Splitwise's user id for this friend. Null for ghost players.
  final String? splitwiseUserId;

  /// Hex color (e.g. '#FF5722') used to render the avatar consistently.
  final String avatarColorHex;

  Player({
    String? id,
    required this.name,
    this.source = PlayerSource.ghost,
    this.splitwiseUserId,
    this.avatarColorHex = '#607D8B',
  }) : id = id ?? const Uuid().v4();

  bool get isGhost => source == PlayerSource.ghost;

  Player copyWith({
    String? name,
    PlayerSource? source,
    String? splitwiseUserId,
    String? avatarColorHex,
  }) {
    return Player(
      id: id,
      name: name ?? this.name,
      source: source ?? this.source,
      splitwiseUserId: splitwiseUserId ?? this.splitwiseUserId,
      avatarColorHex: avatarColorHex ?? this.avatarColorHex,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.name,
        'splitwiseUserId': splitwiseUserId,
        'avatarColorHex': avatarColorHex,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['name'] as String,
        source: PlayerSource.values.byName(
          json['source'] as String? ?? 'ghost',
        ),
        splitwiseUserId: json['splitwiseUserId'] as String?,
        avatarColorHex: json['avatarColorHex'] as String? ?? '#607D8B',
      );

  @override
  bool operator ==(Object other) => other is Player && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
