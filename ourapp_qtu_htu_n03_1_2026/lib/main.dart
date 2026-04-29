import 'package:flutter/material.dart';
import 'screens/group_chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/user_screen.dart';

class user {
  String name;
  int id;
  user(this.name, this.id);
}

class message {
  String content;
  int id;
  message(this.content, this.id);
}

class roomMessage {
  int id;
  String roomName;
  int userId;
  int messageId;
  roomMessage(this.id, this.roomName, this.userId, this.messageId);
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const BottomNavigationScreen(),
    );
  }
}

/*class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var listUser = [user("Tu", 1), user("Tu2", 2)];
  var listMessage = [message("Hello", 1), message("Hi", 2)];
  var listRoomMessage = [
    roomMessage(1, "giai tri", 1, 1),
    roomMessage(2, "phong chat 2", 2, 2),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            const Text('Danh sách người dùng:'),
            Row(
              children: listUser
                  .map((user) => Text('ID: ${user.id}, Name: ${user.name}'))
                  .toList(),
            ),
            const Text('Danh sách tin nhắn:'),
            Row(
              children: listMessage
                  .map(
                    (message) =>
                        Text('ID: ${message.id}, Content: ${message.content}'),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}  */

class BottomNavigationScreen extends StatefulWidget {
  const BottomNavigationScreen({super.key});

  @override
  State<BottomNavigationScreen> createState() => _BottomNavigationScreenState();
}

class _BottomNavigationScreenState extends State<BottomNavigationScreen> {
  @override
  Widget build(BuildContext context) {
    return const MainNavigationScreen();
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    HomeScreen(),
    GroupScreen(),
    UserScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Content'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'About'),
        ],
      ),
    );
  }
}
