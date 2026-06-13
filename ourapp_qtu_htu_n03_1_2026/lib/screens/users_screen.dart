import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:privatechat/models/user.dart';
import 'package:privatechat/screens/private_chat_screen.dart';
import 'package:privatechat/services/lan_chat_controller.dart';
import 'package:privatechat/utils/message_date_utils.dart';
import 'package:privatechat/widgets/app_header_bar.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _search = TextEditingController();
  bool _requested = false;
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requested) {
      _requested = true;
      context.read<LanChatController>().requestAllUsers();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _statusLabel(User user) {
    if (user.isOnline) return 'Đang online';
    final lastSeen = user.lastSeen;
    if (lastSeen == null) return 'Offline';
    final now = DateTime.now();
    if (isSameCalendarDay(lastSeen, now)) {
      return 'Offline · ${DateFormat.Hm().format(lastSeen)}';
    }
    if (lastSeen.year == now.year) {
      return 'Offline · ${DateFormat('dd/MM HH:mm').format(lastSeen)}';
    }
    return 'Offline · ${DateFormat('dd/MM/yyyy HH:mm').format(lastSeen)}';
  }

  void _openChat(BuildContext context, String name) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrivateChatScreen(peer: name),
      ),
    );
  }

  Widget _userTile(BuildContext context, User user) {
    final theme = Theme.of(context);
    final statusColor =
        user.isOnline ? const Color(0xFF008848) : Colors.grey.shade500;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                user.username.isEmpty ? '?' : user.username[0].toUpperCase(),
              ),
            ),
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(user.username),
        subtitle: Text(
          _statusLabel(user),
          style: TextStyle(
            color: user.isOnline ? const Color(0xFF008848) : null,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openChat(context, user.username),
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LanChatController>();
    final friends = c.friendsForDisplay(query: _query);
    final online = friends.where((u) => u.isOnline).toList();
    final offline = friends.where((u) => !u.isOnline).toList();

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppHeaderBar(
            search: _search,
            searchHint: 'Tìm bạn bè',
            username: c.username,
            status: c.status,
            onSearchChanged: (v) => setState(() => _query = v.trim()),
            onRefresh: c.requestAllUsers,
            onLogout: c.logout,
            leadingIcon: Icons.group_rounded,
            leadingTooltip: 'Bạn bè',
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
                  'Danh sách bạn bè',
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
                    '${friends.length} kết quả',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  )
                else if (friends.isNotEmpty)
                  Text(
                    '${online.length} online · ${offline.length} offline',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          Expanded(
            child: friends.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'Chưa có bạn bè nào. Tài khoản đã đăng ký sẽ hiển thị ở đây.'
                          : 'Không tìm thấy "$_query".',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      if (online.isNotEmpty) ...[
                        _sectionHeader('Đang online', online.length),
                        ...online.map((u) => _userTile(context, u)),
                      ],
                      if (offline.isNotEmpty) ...[
                        _sectionHeader('Offline', offline.length),
                        ...offline.map((u) => _userTile(context, u)),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
