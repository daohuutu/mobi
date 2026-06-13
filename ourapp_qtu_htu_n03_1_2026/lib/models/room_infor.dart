class RoomInfo {
  const RoomInfo({
    required this.name,
    required this.createdBy,
    this.admins = const [],
    this.createdAt,
    this.members = const [],
  });

  final String name;
  final String createdBy;
  final List<String> admins;
  final DateTime? createdAt;
  final List<String> members;

  bool isAdmin(String username) =>
      admins.contains(username) || createdBy == username;

  RoomInfo copyWith({
    String? name,
    String? createdBy,
    List<String>? admins,
    DateTime? createdAt,
    List<String>? members,
  }) {
    return RoomInfo(
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      admins: admins ?? this.admins,
      createdAt: createdAt ?? this.createdAt,
      members: members ?? this.members,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'createdBy': createdBy,
    'admins': admins,
    'createdAt': createdAt?.toIso8601String(),
  };

  /// Parses server `rooms_list` items and `room_meta` payloads.
  static RoomInfo? fromJson(Map<String, dynamic> json) {
    try {
      final name = (json['name'] ?? json['room'])?.toString();
      if (name == null || name.isEmpty) return null;

      final adminsRaw = json['admins'];
      final admins = adminsRaw is List
          ? adminsRaw
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList()
          : <String>[];

      final membersRaw = json['members'];
      final members = membersRaw is List
          ? membersRaw
                .map((e) {
                  if (e is Map) {
                    return e['username']?.toString() ?? '';
                  }
                  return e.toString();
                })
                .where((e) => e.isNotEmpty)
                .toList()
          : <String>[];

      DateTime? createdAt;
      final createdAtRaw = json['createdAt'];
      if (createdAtRaw is String) {
        createdAt = DateTime.tryParse(createdAtRaw);
      } else if (createdAtRaw is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
      }

      return RoomInfo(
        name: name,
        createdBy: json['createdBy']?.toString() ?? '',
        admins: admins,
        createdAt: createdAt,
        members: members,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomInfo &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() =>
      'RoomInfo(name: $name, createdBy: $createdBy, admins: $admins)';
}
