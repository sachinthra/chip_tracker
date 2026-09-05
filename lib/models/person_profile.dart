import 'package:uuid/uuid.dart';

/// A persistent person across games. Games store per-night [Player]s (by name);
/// a [PersonProfile] lets us treat several typed names as the same human for
/// the leaderboard and per-person history (e.g. "sachin" + "sachinthra").
class PersonProfile {
  final String id;
  final String displayName;

  /// Normalized (lowercase, trimmed) names that resolve to this person,
  /// including the display name itself.
  final List<String> aliases;

  final String colorHex;
  final String? photoPath;

  PersonProfile({
    String? id,
    required this.displayName,
    List<String>? aliases,
    this.colorHex = '#607D8B',
    this.photoPath,
  })  : id = id ?? const Uuid().v4(),
        aliases = aliases ?? [normalize(displayName)];

  static String normalize(String name) => name.trim().toLowerCase();

  bool matches(String rawName) => aliases.contains(normalize(rawName));

  PersonProfile copyWith({
    String? displayName,
    List<String>? aliases,
    String? colorHex,
    String? photoPath,
    bool clearPhoto = false,
  }) {
    return PersonProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      aliases: aliases ?? this.aliases,
      colorHex: colorHex ?? this.colorHex,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'aliases': aliases,
        'colorHex': colorHex,
        'photoPath': photoPath,
      };

  factory PersonProfile.fromJson(Map<String, dynamic> json) => PersonProfile(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        aliases: (json['aliases'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        colorHex: json['colorHex'] as String? ?? '#607D8B',
        photoPath: json['photoPath'] as String?,
      );
}
