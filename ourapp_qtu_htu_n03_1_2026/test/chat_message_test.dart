import 'package:flutter_test/flutter_test.dart';
import 'package:privatechat/models/chat_message.dart';

void main() {
  group('ChatMessage Unit Tests', () {
    test('toJson() serializes ChatMessage correctly', () {
      final now = DateTime.now();
      final message = ChatMessage(
        id: 'msg-123',
        from: 'alice',
        text: 'Hello world',
        timestamp: now,
        kind: MessageKind.public,
      );

      final json = message.toJson();

      expect(json['id'], 'msg-123');
      expect(json['from'], 'alice');
      expect(json['text'], 'Hello world');
      expect(json['ts'], now.toIso8601String());
      expect(json['kind'], 'public');
      expect(json['room'], isNull);
    });

    test('fromJson() deserializes valid JSON into ChatMessage', () {
      final now = DateTime.now();
      final json = {
        'id': 'msg-456',
        'from': 'bob',
        'text': 'Hello Alice',
        'ts': now.toIso8601String(),
        'kind': 'privateMessage',
        'to': 'alice',
        'peer': 'alice'
      };

      final message = ChatMessage.fromJson(json);

      expect(message, isNotNull);
      expect(message!.id, 'msg-456');
      expect(message.from, 'bob');
      expect(message.text, 'Hello Alice');
      expect(message.kind, MessageKind.privateMessage);
      expect(message.to, 'alice');
      expect(message.peer, 'alice');
    });

    test('isFrom() returns correct boolean based on username', () {
      final message = ChatMessage(
        id: 'msg-789',
        from: 'charlie',
        text: 'Test',
        timestamp: DateTime.now(),
        kind: MessageKind.public,
      );

      expect(message.isFrom('charlie'), isTrue);
      expect(message.isFrom('alice'), isFalse);
    });
  });
}
