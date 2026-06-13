import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:privatechat/main.dart';
import 'package:privatechat/services/lan_chat_controller.dart';
import 'package:privatechat/services/theme_controller.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanChatController()),
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: const PrivateChatApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
