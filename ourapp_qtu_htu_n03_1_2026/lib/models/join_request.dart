class JoinRequest {
  const JoinRequest({
    required this.room,
    required this.username,
    required this.createdAt,
  });

  final String room;
  final String username;
  final DateTime createdAt;

  static JoinRequest? fromJson(Map<String, dynamic> json) {
    try {
      final room = json['room']?.toString();
      final username = json['username']?.toString();
      if (room == null ||
          room.isEmpty ||
          username == null ||
          username.isEmpty) {
        return null;
      }
      final tsRaw = json['createdAt'];
      final DateTime createdAt;
      if (tsRaw is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(tsRaw);
      } else if (tsRaw is String) {
        createdAt = DateTime.tryParse(tsRaw) ?? DateTime.now();
      } else {
        createdAt = DateTime.now();
      }
      return JoinRequest(room: room, username: username, createdAt: createdAt);
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JoinRequest &&
          runtimeType == other.runtimeType &&
          room == other.room &&
          username == other.username;

  @override
  int get hashCode => Object.hash(room, username);

  @override
  String toString() => 'JoinRequest(room: $room, username: $username)';
}
