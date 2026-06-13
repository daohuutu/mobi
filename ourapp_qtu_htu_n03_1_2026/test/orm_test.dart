import 'package:flutter_test/flutter_test.dart';
import 'package:privatechat/models/chat_message.dart';
import 'package:privatechat/models/user.dart';

void main() {
  group('ORM / JSON Serialization Tests', () {
    test('ChatMessage.fromJson should map JSON data correctly', () {
      final json = {
        'id': 'msg123',
        'from': 'userA',
        'text': 'Hello world',
        'ts': '2023-01-01T12:00:00.000Z',
        'kind': 'public'
      };

      final msg = ChatMessage.fromJson(json);
      
      expect(msg, isNotNull);
      expect(msg!.id, 'msg123');
      expect(msg.from, 'userA');
      expect(msg.text, 'Hello world');
      expect(msg.kind, MessageKind.public);
    });

    test('ChatMessage.fromJson should return null on invalid date format', () {
      final json = {
        'id': 'msg123',
        'from': 'userA',
        'text': 'Hello world',
        'ts': 'invalid-date', // Invalid format
        'kind': 'public'
      };

      final msg = ChatMessage.fromJson(json);
      
      // Due to the try-catch in fromJson, it should return null
      expect(msg, isNull);
    });

    test('User.fromJson should map data correctly', () {
      final json = {
        'username': 'Alice',
        'isOnline': true
      };

      final user = User.fromJson(json);
      expect(user!.username, 'Alice');
      expect(user.isOnline, true);
    });
    
    test('ChatMessage.toJson should format object back to Map', () {
      final msg = ChatMessage(
        id: '1',
        from: 'Alice',
        text: 'Hi',
        timestamp: DateTime.utc(2023, 1, 1),
        kind: MessageKind.privateMessage,
        peer: 'Bob',
        to: 'Bob',
      );
      
      final map = msg.toJson();
      expect(map['id'], '1');
      expect(map['from'], 'Alice');
      expect(map['text'], 'Hi');
      expect(map['kind'], 'privateMessage');
      expect(map['peer'], 'Bob');
      expect(map['to'], 'Bob');
    });
  });
}
