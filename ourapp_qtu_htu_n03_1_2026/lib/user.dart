class User {
  final int id;
  final String username;
  final bool isOnline;
  final String? status;
  final String? avatar;

  const User({
    required this.id,
    required this.username,
    this.isOnline = false,
    this.status,
    this.avatar,
  });

  User copyWith({
    int? id,
    String? username,
    bool? isOnline,
    String? status,
    String? avatar,
  }) {
    return User(
      id: this.id,
      username: username ?? this.username,
      isOnline: isOnline ?? this.isOnline,
      status: status ?? this.status,
      avatar: avatar ?? this.avatar,
    );
  }
}