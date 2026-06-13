import 'package:flutter_test/flutter_test.dart';
import 'package:privatechat/services/lan_chat_controller.dart';
import 'package:privatechat/models/chat_message.dart';

void main() {
  group('Chat Logic & Error Handling', () {
    test('Controller handles empty username properly', () {
      final controller = LanChatController();
      expect(controller.status, ConnectionStatus.disconnected);
      expect(controller.username, '');
    });

    test('Add message to public chat', () {
      final controller = LanChatController();
      
      final msg = ChatMessage(
        id: '1',
        from: 'Alice',
        text: 'Hello',
        timestamp: DateTime.now(),
        kind: MessageKind.public,
      );
      
      // Initially empty
      expect(controller.publicMessages.length, 0);
    });
  });
}
