class RoomInfo {
  const RoomInfo({
    required this.name,
    required this.createdBy,
    this.admins = const [],
    this.createdAt,
  });

  final String name;
  final String createdBy;
  final List<String> admins;
  final DateTime? createdAt;

  bool isAdmin(String username) => admins.contains(username);

  RoomInfo copyWith({
    String? name,
    String? createdBy,
    List<String>? admins,
    DateTime? createdAt,
  }) {
    return RoomInfo(
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      admins: admins ?? this.admins,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}