import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:privatechat/screens/login_screen.dart';
import 'package:privatechat/screens/main_screen.dart';
import 'package:privatechat/services/lan_chat_controller.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanChatController>(
      builder: (context, c, _) {
        if (c.isLoggedIn) {
          return const MainScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
