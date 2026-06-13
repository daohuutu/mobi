import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:privatechat/services/lan_chat_controller.dart';
import 'package:privatechat/widgets/chat_input_bar.dart';
import 'package:privatechat/widgets/chat_message_list.dart';

class PrivateChatScreen extends StatefulWidget {
  const PrivateChatScreen({super.key, required this.peer});

  final String peer;

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  LanChatController? _chat;
  int _lastLen = 0;
  bool _historyRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_historyRequested && mounted) {
        _historyRequested = true;
        context.read<LanChatController>().requestPrivateHistory(widget.peer);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = context.read<LanChatController>();
    if (_chat != c) {
      _chat?.removeListener(_onChat);
      _chat = c;
      c.addListener(_onChat);
      _lastLen = c.messagesForPeer(widget.peer).length;
    }
  }

  void _onChat() {
    final c = _chat;
    if (c == null) return;
    final n = c.messagesForPeer(widget.peer).length;
    if (n != _lastLen) {
      _lastLen = n;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _chat?.removeListener(_onChat);
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final t = _input.text;
    _input.clear();
    context.read<LanChatController>().sendPrivateTo(widget.peer, t);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LanChatController>();
    final me = c.username;
    final msgs = c.messagesForPeer(widget.peer);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              child: Text(
                widget.peer.isEmpty ? '?' : widget.peer[0].toUpperCase(),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.peer, style: const TextStyle(fontSize: 16)),
                Text(
                  'Cuộc trò chuyện riêng',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: msgs.isEmpty
                ? const Center(child: Text('Chưa có tin nhắn.'))
                : ChatMessageList(
                    messages: msgs,
                    me: me,
                    scrollController: _scroll,
                  ),
          ),
          const Divider(height: 1),
          ChatInputBar(
            controller: _input,
            hintText: 'Nhắn tin cho ${widget.peer}...',
            onSend: _send,
          ),
        ],
      ),
    );
  }
}
