import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:privatechat/models/chat_message.dart';
import 'package:privatechat/services/lan_chat_controller.dart';
import 'package:privatechat/widgets/app_header_bar.dart';
import 'package:privatechat/widgets/chat_input_bar.dart';
import 'package:privatechat/widgets/chat_message_list.dart';

class PublicChatScreen extends StatefulWidget {
  const PublicChatScreen({super.key});

  @override
  State<PublicChatScreen> createState() => _PublicChatScreenState();
}

class _PublicChatScreenState extends State<PublicChatScreen> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _search = TextEditingController();
  LanChatController? _chat;
  int _lastLen = 0;
  bool _historyRequested = false;
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = context.read<LanChatController>();
    if (!_historyRequested) {
      _historyRequested = true;
      c.requestPublicHistory();
    }
    if (_chat != c) {
      _chat?.removeListener(_onChat);
      _chat = c;
      c.addListener(_onChat);
      _lastLen = c.publicMessages.length;
    }
  }

  void _onChat() {
    final c = _chat;
    if (c == null) return;
    final n = c.publicMessages.length;
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
    _search.dispose();
    super.dispose();
  }

  void _send() {
    final t = _input.text;
    _input.clear();
    context.read<LanChatController>().sendPublic(t);
  }

  List<ChatMessage> _filteredMessages(List<ChatMessage> msgs) {
    if (_query.isEmpty) return msgs;
    final q = _query.toLowerCase();
    return msgs
        .where(
          (m) =>
              m.text.toLowerCase().contains(q) ||
              m.from.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LanChatController>();
    final me = c.username;
    final msgs = _filteredMessages(c.publicMessages);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppHeaderBar(
          search: _search,
          searchHint: 'Tìm tin nhắn hoặc người gửi',
          username: me,
          status: c.status,
          onSearchChanged: (v) => setState(() => _query = v.trim()),
          onRefresh: c.requestPublicHistory,
          onLogout: c.logout,
          leadingIcon: Icons.chat_bubble_rounded,
          leadingTooltip: 'Nhóm chung',
          onLeadingPressed: () {
            _search.clear();
            setState(() => _query = '');
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              const Text(
                'Nhóm chung',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Colors.grey.shade500,
              ),
              const Spacer(),
              if (_query.isNotEmpty)
                Text(
                  '${msgs.length} kết quả',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
        Expanded(
          child: msgs.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty
                        ? 'Chưa có tin nhắn công khai.'
                        : 'Không tìm thấy tin nhắn "$_query".',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ChatMessageList(
                  messages: msgs,
                  me: me,
                  scrollController: _scroll,
                ),
        ),
        const Divider(height: 1),
        ChatInputBar(
          controller: _input,
          hintText: 'Nhập tin nhắn...',
          onSend: _send,
        ),
      ],
    );
  }
}
