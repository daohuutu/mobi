class RoomMember {
  const RoomMember({
    required this.username,
    this.role = 'member',
    this.joinedAt,
  });

  final String username;
  final String role;
  final DateTime? joinedAt;

  bool get isAdminRole => role == 'admin';

  static RoomMember? fromJson(Map<String, dynamic> json) {
    try {
      final username = json['username']?.toString() ?? '';
      if (username.isEmpty) return null;

      DateTime? joinedAt;
      final raw = json['joinedAt'];
      if (raw is int) {
        joinedAt = DateTime.fromMillisecondsSinceEpoch(raw);
      } else if (raw is String) {
        joinedAt = DateTime.tryParse(raw);
      }

      return RoomMember(
        username: username,
        role: json['role']?.toString() ?? 'member',
        joinedAt: joinedAt,
      );
    } catch (_) {
      return null;
    }
  }
}
