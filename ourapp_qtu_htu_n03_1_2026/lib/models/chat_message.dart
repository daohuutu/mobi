enum MessageKind { public, privateMessage, room }

class ChatMessage {
  final String id;
  final String from;
  final String text;
  final DateTime timestamp;
  final MessageKind kind;
  final String? room;
  final String? peer;
  final String? to;

  const ChatMessage({
    required this.id,
    required this.from,
    required this.text,
    required this.timestamp,
    required this.kind,
    this.room,
    this.peer,
    this.to,
  });

  bool isFrom(String username) => from == username;

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': from,
    'text': text,
    'ts': timestamp.toIso8601String(),
    'kind': kind.name,
    'room': room,
    'peer': peer,
    'to': to,
  };

  static ChatMessage? fromJson(Map<String, dynamic> json) {
    try {
      final kindName = json['kind'] as String?;
      final kind = MessageKind.values.firstWhere(
        (k) => k.name == kindName,
        orElse: () => MessageKind.public,
      );
      return ChatMessage(
        id: json['id'] as String,
        from: json['from'] as String,
        text: json['text'] as String,
        timestamp: DateTime.parse(json['ts'] as String),
        kind: kind,
        room: json['room'] as String?,
        peer: json['peer'] as String?,
        to: json['to'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
