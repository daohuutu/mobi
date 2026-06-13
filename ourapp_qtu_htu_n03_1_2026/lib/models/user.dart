class User {
  final String username;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? status;
  final String? avatar;

  const User({
    required this.username,
    this.isOnline = false,
    this.lastSeen,
    this.status,
    this.avatar,
  });

  User copyWith({
    String? username,
    bool? isOnline,
    DateTime? lastSeen,
    String? status,
    String? avatar,
  }) {
    return User(
      username: username ?? this.username,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      status: status ?? this.status,
      avatar: avatar ?? this.avatar,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
      'status': status,
      'avatar': avatar,
    };
  }

  static User? fromJson(Map<String, dynamic> json) {
    try {
      final username = json['username']?.toString() ?? '';
      if (username.isEmpty) return null;

      DateTime? lastSeen;
      final lastSeenRaw = json['lastSeen'] ?? json['lastSeenAt'];
      if (lastSeenRaw is String) {
        lastSeen = DateTime.tryParse(lastSeenRaw);
      } else if (lastSeenRaw is int) {
        lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenRaw);
      }

      return User(
        username: username,
        isOnline: json['isOnline'] == true,
        lastSeen: lastSeen,
        status: json['status']?.toString(),
        avatar: json['avatar']?.toString(),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          username == other.username;

  @override
  int get hashCode => username.hashCode;

  @override
  String toString() =>
      'User(username: $username, isOnline: $isOnline, lastSeen: $lastSeen, status: $status)';
}
