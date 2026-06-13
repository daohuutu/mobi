import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:privatechat/screens/auth_gate.dart';
import 'package:privatechat/services/lan_chat_controller.dart';
import 'package:privatechat/services/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final chat = LanChatController();
  final theme = ThemeController();
  await Future.wait([chat.loadPrefs(), theme.loadPrefs()]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LanChatController>.value(value: chat),
        ChangeNotifierProvider<ThemeController>.value(value: theme),
      ],
      child: const PrivateChatApp(),
    ),
  );
}

class PrivateChatApp extends StatelessWidget {
  const PrivateChatApp({super.key});

  static ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0084FF),
        brightness: brightness,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF4F6FB)
          : const Color(0xFF121218),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();

    return MaterialApp(
      title: 'LAN Chat',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: theme.themeMode,
      home: const AuthGate(),
    );
  }
}
