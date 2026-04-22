class MessageKind {
  static const String public = "public";
  static const String privateMessage = "privateMessage";
  static const String room = "room";

  static get values => null;
}

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
}
