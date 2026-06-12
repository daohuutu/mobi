import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:privatechat/models/room_info.dart';
import 'package:privatechat/screens/room_chat_screen.dart';
import 'package:privatechat/services/lan_chat_controller.dart';
import 'package:privatechat/widgets/app_header_bar.dart';

enum RoomFilter { all, myRooms, pending }

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final _search = TextEditingController();
  bool _requested = false;
  String _query = '';
  RoomFilter _filter = RoomFilter.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requested) {
      _requested = true;
      context.read<LanChatController>().requestRooms();
    }
  }

  @override
  void didUpdateWidget(covariant RoomsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkApprovedRoom();
  }

  void _checkApprovedRoom() {
    final c = context.read<LanChatController>();
    final approved = c.consumeJustApprovedRoom();
    if (approved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Yêu cầu tham gia "$approved" đã được duyệt!'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _openRoom(context, approved);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openRoom(BuildContext context, String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => RoomChatScreen(room: n)));
  }

  void _createRoom(BuildContext context) {
    final room = _search.text.trim();
    if (room.isEmpty) return;
    final c = context.read<LanChatController>();
    c.createRoom(room);
    c.requestRooms();
    _openRoom(context, room);
    _search.clear();
    setState(() => _query = '');
  }

  /// Xử lý khi user bấm vào một phòng
  void _handleRoomTap(BuildContext context, LanChatController c, RoomInfo room) {
    // Admin (người tạo phòng) luôn được vào
    if (room.isAdmin(c.username)) {
      _openRoom(context, room.name);
      return;
    }

    // Đã là thành viên → vào ngay
    if (c.isMemberOf(room.name)) {
      _openRoom(context, room.name);
      return;
    }

    // Đang chờ duyệt
    if (c.hasPendingRequest(room.name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⏳ Yêu cầu tham gia đang chờ admin duyệt...'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    // Chưa phải member → hỏi xác nhận rồi gửi request
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tham gia phòng "${room.name}"?'),
        content: const Text(
          'Bạn chưa được mời vào phòng này.\n'
          'Gửi yêu cầu tham gia để admin xem xét và chấp nhận.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    ).then((ok) {
      if (ok == true && context.mounted) {
        context.read<LanChatController>().requestJoinRoom(room.name);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📨 Đã gửi yêu cầu tham gia "${room.name}". Chờ admin duyệt.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  List<RoomInfo> _filteredRooms(LanChatController c) {
    List<RoomInfo> list;
    if (c.roomsCatalog.isNotEmpty) {
      list = c.roomsCatalog;
    } else {
      final keys = c.roomNamesWithMessages;
      list = keys.map((n) => RoomInfo(name: n, createdBy: '')).toList();
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((r) => r.name.toLowerCase().contains(q)).toList();
    }

    final me = c.username;
    if (_filter == RoomFilter.myRooms) {
      list = list.where((r) => r.isAdmin(me)).toList();
    } else if (_filter == RoomFilter.pending) {
      list = list.where((r) => c.hasPendingRequest(r.name)).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LanChatController>();
    final me = c.username;
    final rooms = _filteredRooms(c);

    // Check for newly approved room
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final approved = c.consumeJustApprovedRoom();
      if (approved != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Yêu cầu tham gia "$approved" đã được duyệt!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _openRoom(context, approved);
      }
    });

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppHeaderBar(
            search: _search,
            searchHint: 'Tìm hoặc nhập tên phòng',
            username: me,
            status: c.status,
            onSearchChanged: (v) => setState(() => _query = v.trim()),
            onSearchSubmitted: (v) => _openRoom(context, v),
            leadingIcon: Icons.add_rounded,
            leadingTooltip: 'Tạo phòng',
            onLeadingPressed: () => _createRoom(context),
            onRefresh: c.requestRooms,
            onLogout: c.logout,
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _FilterCard(
                            title: 'Tất cả',
                            icon: Icons.all_inclusive_rounded,
                            color: const Color(0xFF0084FF),
                            isSelected: _filter == RoomFilter.all,
                            onTap: () => setState(() => _filter = RoomFilter.all),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FilterCard(
                            title: 'Quản lý',
                            icon: Icons.shield_rounded,
                            color: const Color(0xFF008848),
                            isSelected: _filter == RoomFilter.myRooms,
                            onTap: () => setState(() => _filter = RoomFilter.myRooms),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FilterCard(
                            title: 'Chờ duyệt',
                            icon: Icons.hourglass_top_rounded,
                            color: Colors.orange.shade700,
                            isSelected: _filter == RoomFilter.pending,
                            onTap: () => setState(() => _filter = RoomFilter.pending),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text(
                          'Danh sách phòng',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: Colors.grey.shade500,
                        ),
                        const Spacer(),
                        if (rooms.isNotEmpty)
                          Text(
                            '${rooms.length} phòng',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: rooms.isEmpty
                        ? Center(
                            child: Text(
                              _query.isEmpty
                                  ? 'Chưa có phòng nào.'
                                  : 'Không tìm thấy phòng "$_query".',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: rooms.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, i) {
                              final room = rooms[i];
                              final isPending = c.hasPendingRequest(room.name);
                              final pendingRequestCount = c.roomInfoFor(room.name)?.isAdmin(me) == true
                                  ? c.joinRequestsFor(room.name).length
                                  : 0;
                              return _RoomSlideCard(
                                room: room,
                                me: me,
                                isPending: isPending,
                                pendingRequestCount: pendingRequestCount,
                                onTap: () => _handleRoomTap(context, c, room),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomSlideCard extends StatelessWidget {
  const _RoomSlideCard({
    required this.room,
    required this.me,
    required this.onTap,
    this.isPending = false,
    this.pendingRequestCount = 0,
  });

  final RoomInfo room;
  final String me;
  final VoidCallback onTap;
  final bool isPending;
  final int pendingRequestCount;

  @override
  Widget build(BuildContext context) {
    final isAdmin = room.isAdmin(me);
    final Color accent;
    if (isPending) {
      accent = Colors.orange.shade700;
    } else if (isAdmin) {
      accent = const Color(0xFF008848);
    } else {
      accent = const Color(0xFF0084FF);
    }

    final surface = Theme.of(context).colorScheme.surface;

    return SizedBox(
      width: 200,
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.15),
                          accent.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          isPending
                              ? Icons.hourglass_top_rounded
                              : isAdmin
                                  ? Icons.shield_rounded
                                  : Icons.meeting_room_rounded,
                          size: 34,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPending
                              ? '⏳ Đang chờ admin duyệt'
                              : room.createdBy.isEmpty
                                  ? 'Phòng đã tồn tại'
                                  : 'Admin: ${room.createdBy}${room.createdBy == me ? ' (bạn)' : ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isPending
                                ? Colors.orange.shade700
                                : Colors.grey.shade600,
                            height: 1.3,
                            fontWeight: isPending ? FontWeight.w600 : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Badge số yêu cầu join (chỉ admin thấy)
              if (pendingRequestCount > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person_add_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$pendingRequestCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Material(
      color: isSelected ? color.withValues(alpha: 0.15) : surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey.shade500, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
