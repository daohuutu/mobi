import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:privatechat/main.dart';
import 'package:privatechat/services/lan_chat_controller.dart';
import 'package:privatechat/services/theme_controller.dart';

void main() {
  testWidgets('Shows login when not connected', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final chat = LanChatController();
    await chat.loadPrefs();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanChatController>.value(value: chat),
          ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController()),
        ],
        child: const PrivateChatApp(),
      ),
    );

    await tester.pump();
    expect(find.textContaining('PrivateChat'), findsWidgets);
    expect(find.textContaining('Tham gia'), findsOneWidget);
  });
}
