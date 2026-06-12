import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:privatechat/models/room_info.dart';
import 'package:privatechat/services/lan_chat_controller.dart';
import 'package:privatechat/widgets/chat_input_bar.dart';
import 'package:privatechat/widgets/chat_message_list.dart';
import 'package:privatechat/widgets/room_manage_sheet.dart';

class RoomChatScreen extends StatefulWidget {
  const RoomChatScreen({super.key, required this.room});

  final String room;

  @override
  State<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends State<RoomChatScreen> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  LanChatController? _chat;
  int _lastLen = 0;
  bool _joined = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_joined && mounted) {
        _joined = true;
        final chat = context.read<LanChatController>();
        // Try to join; server will deny if not a member
        chat.joinRoom(widget.room);
        chat.requestRoomHistory(widget.room);
        chat.requestRoomMembers(widget.room);
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
      _lastLen = c.messagesForRoom(widget.room).length;
    }
  }

  void _onChat() {
    final c = _chat;
    if (c == null || !mounted) return;

    if (c.consumeDeletedRoom(widget.room) != null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phòng "${widget.room}" đã bị xóa.')),
      );
      return;
    }

    final newName = c.consumeRenamedRoom(widget.room);
    if (newName != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RoomChatScreen(room: newName),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phòng đã đổi tên thành "$newName".')),
      );
      return;
    }

    // Check for join_request_approved — auto join if we're waiting
    final approvedRoom = c.consumeJustApprovedRoom();
    if (approvedRoom == widget.room) {
      // Re-join now that we're a member
      c.joinRoom(widget.room);
      c.requestRoomHistory(widget.room);
      c.requestRoomMembers(widget.room);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Yêu cầu được duyệt! Bạn đã vào phòng.'),
          backgroundColor: Color(0xFF008848),
        ),
      );
    }

    final n = c.messagesForRoom(widget.room).length;
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
    context.read<LanChatController>().sendRoom(widget.room, t);
  }

  RoomInfo? _roomInfo(LanChatController c) => c.roomInfoFor(widget.room);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LanChatController>();
    final me = c.username;
    final msgs = c.messagesForRoom(widget.room);
    final roomInfo = _roomInfo(c);
    final isAdmin = roomInfo?.isAdmin(me) ?? false;
    final memberCount = c.membersForRoom(widget.room).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.room),
            Text(
              isAdmin
                  ? 'Admin · $memberCount thành viên'
                  : 'Phòng chat · $memberCount thành viên',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: 'Quản lý phòng',
              onPressed: () => showRoomManageSheet(context, room: widget.room),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: msgs.isEmpty
                ? const Center(child: Text('Chưa có tin trong phòng.'))
                : ChatMessageList(
                    messages: msgs,
                    me: me,
                    scrollController: _scroll,
                  ),
          ),
          const Divider(height: 1),
          ChatInputBar(
            controller: _input,
            hintText: 'Gửi tin vào phòng...',
            onSend: _send,
          ),
        ],
      ),
    );
  }
}
