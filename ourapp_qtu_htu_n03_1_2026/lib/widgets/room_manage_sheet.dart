import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:privatechat/models/join_request.dart';
import 'package:privatechat/models/room_member.dart';
import 'package:privatechat/services/lan_chat_controller.dart';

Future<void> showRoomManageSheet(
  BuildContext context, {
  required String room,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _RoomManageSheet(room: room),
  );
}

class _RoomManageSheet extends StatefulWidget {
  const _RoomManageSheet({required this.room});

  final String room;

  @override
  State<_RoomManageSheet> createState() => _RoomManageSheetState();
}

class _RoomManageSheetState extends State<_RoomManageSheet> {
  final _rename = TextEditingController();
  final _addMember = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rename.text = widget.room;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final c = context.read<LanChatController>();
        c.requestRoomMembers(widget.room);
        c.fetchJoinRequests(widget.room);
      }
    });
  }

  @override
  void dispose() {
    _rename.dispose();
    _addMember.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(LanChatController c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa phòng?'),
        content: Text(
          'Phòng "${widget.room}" và toàn bộ tin nhắn sẽ bị xóa vĩnh viễn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      c.deleteRoom(widget.room);
      Navigator.pop(context);
    }
  }

  void _renameRoom(LanChatController c) {
    final name = _rename.text.trim();
    if (name.isEmpty || name == widget.room) return;
    c.renameRoom(widget.room, name);
    Navigator.pop(context);
  }

  void _addMemberToRoom(LanChatController c) {
    final name = _addMember.text.trim();
    if (name.isEmpty) return;
    c.addRoomMember(widget.room, name);
    _addMember.clear();
  }

  Future<void> _removeMember(LanChatController c, RoomMember member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa thành viên?'),
        content: Text('Xóa ${member.username} khỏi phòng "${widget.room}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok == true) {
      c.removeRoomMember(widget.room, member.username);
    }
  }

  Future<void> _approveRequest(LanChatController c, JoinRequest req) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chấp nhận yêu cầu?'),
        content: Text(
          'Cho phép "${req.username}" tham gia phòng "${widget.room}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Chấp nhận'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      c.approveJoinRequest(widget.room, req.username);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã chấp nhận "${req.username}"'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _rejectRequest(LanChatController c, JoinRequest req) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Từ chối yêu cầu?'),
        content: Text(
          'Từ chối "${req.username}" tham gia phòng "${widget.room}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      c.rejectJoinRequest(widget.room, req.username);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Đã từ chối "${req.username}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LanChatController>();
    final me = c.username;
    final members = c.membersForRoom(widget.room);
    final joinRequests = c.joinRequestsFor(widget.room);
    final memberNames = members.map((m) => m.username).toSet();
    final candidates = c
        .friendsForDisplay()
        .where((u) => !memberNames.contains(u.username))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Quản lý phòng',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // ─── Yêu cầu tham gia ─────────────────────────────────────────
            if (joinRequests.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.person_add_rounded,
                    size: 18,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Yêu cầu tham gia (${joinRequests.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.red.shade700,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => c.fetchJoinRequests(widget.room),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    tooltip: 'Làm mới',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...joinRequests.map(
                (req) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.red.shade100,
                          child: Text(
                            req.username.isEmpty
                                ? '?'
                                : req.username[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Xin tham gia ${_formatTime(req.createdAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Reject button
                        IconButton(
                          onPressed: () => _rejectRequest(c, req),
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.red.shade600,
                          tooltip: 'Từ chối',
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 4),
                        // Approve button
                        FilledButton.icon(
                          onPressed: () => _approveRequest(c, req),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Duyệt'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 24),
            ],

            // ─── Đổi tên phòng ────────────────────────────────────────────
            Text(
              'Đổi tên phòng',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rename,
                    decoration: const InputDecoration(
                      hintText: 'Tên phòng mới',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _renameRoom(c),
                  child: const Text('Lưu'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ─── Thành viên ───────────────────────────────────────────────
            Row(
              children: [
                Text(
                  'Thành viên (${members.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => c.requestRoomMembers(widget.room),
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Làm mới',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (members.isEmpty)
              Text(
                'Chưa có thành viên.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              ...members.map(
                (m) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        m.username.isEmpty ? '?' : m.username[0].toUpperCase(),
                      ),
                    ),
                    title: Text(m.username),
                    subtitle: Text(
                      m.isAdminRole ||
                              c.roomInfoFor(widget.room)?.isAdmin(m.username) ==
                                  true
                          ? 'Admin'
                          : 'Thành viên',
                    ),
                    trailing: m.username != me
                        ? IconButton(
                            icon: const Icon(Icons.person_remove_outlined),
                            onPressed: () => _removeMember(c, m),
                          )
                        : null,
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // ─── Thêm thành viên ──────────────────────────────────────────
            Text(
              'Thêm thành viên',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addMember,
                    decoration: const InputDecoration(
                      hintText: 'Tên tài khoản',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addMemberToRoom(c),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _addMemberToRoom(c),
                  child: const Text('Thêm'),
                ),
              ],
            ),
            if (candidates.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: candidates.take(8).map((u) {
                  return ActionChip(
                    label: Text(u.username),
                    onPressed: () => c.addRoomMember(widget.room, u.username),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),

            // ─── Xóa phòng ────────────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: () => _confirmDelete(c),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Xóa phòng'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }
}
