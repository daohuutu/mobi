import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:privatechat/models/chat_message.dart';
import 'package:privatechat/models/join_request.dart';
import 'package:privatechat/models/room_info.dart';
import 'package:privatechat/models/room_member.dart';
import 'package:privatechat/models/user.dart';
import 'package:privatechat/services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class LanChatController extends ChangeNotifier {
  LanChatController() {
    _wireSocket();
  }

  final SocketService _socket = SocketService();
  static const _prefServer = 'lan_chat_server_url';
  static const _prefUser = 'lan_chat_username';
  static const _prefPass = 'lan_chat_password';
  static const _prefPublic = 'lan_chat_public_cache_v1';

  Completer<bool>? _connectCompleter;

  String _serverUrl = '';
  String _username = '';
  String _password = '';
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _lastError;

  final List<ChatMessage> _publicMessages = [];
  final Map<String, List<ChatMessage>> _privateByPeer = {};
  final Map<String, List<ChatMessage>> _roomMessages = {};
  final Map<String, RoomInfo> _roomsByName = {};
  final Map<String, List<RoomMember>> _roomMembersByRoom = {};
  List<String> _onlineUsers = [];
  List<User> _knownUsers = [];
  bool _publicHistoryLoaded = false;

  /// True after a successful [connect] until [logout]. Avoids kicking UI back to login on brief disconnects.
  bool _inAppSession = false;

  String? _pendingDeletedRoom;
  (String oldName, String newName)? _pendingRenamedRoom;

  /// Join requests pending for rooms I admin
  final Map<String, List<JoinRequest>> _pendingJoinRequests = {};

  /// Rooms where MY join request is pending (waiting for admin approval)
  final Set<String> _myPendingRooms = {};

  /// Rooms where I am a confirmed member
  final Set<String> _myMemberships = {};

  /// Rooms where I was just approved (consumed once by UI)
  String? _justApprovedRoom;

  String get serverUrl => _serverUrl;
  String get username => _username;
  String get password => _password;
  ConnectionStatus get status => _status;
  String? get lastError => _lastError;
  List<ChatMessage> get publicMessages => List.unmodifiable(_publicMessages);
  List<String> get onlineUsers => List.unmodifiable(_onlineUsers);
  List<User> get knownUsers => List.unmodifiable(_knownUsers);

  bool get isLoggedIn =>
      _inAppSession && _username.isNotEmpty && _serverUrl.isNotEmpty;

  List<ChatMessage> messagesForPeer(String peer) =>
      List.unmodifiable(_privateByPeer[peer] ?? const []);

  List<ChatMessage> messagesForRoom(String room) =>
      List.unmodifiable(_roomMessages[room] ?? const []);
  List<RoomMember> membersForRoom(String room) =>
      List.unmodifiable(_roomMembersByRoom[room] ?? const []);
  RoomInfo? roomInfoFor(String room) => _roomsByName[room];
  List<RoomInfo> get roomsCatalog {
    final list = _roomsByName.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(list);
  }

  /// Join requests (for admin) keyed by room name
  List<JoinRequest> joinRequestsFor(String room) =>
      List.unmodifiable(_pendingJoinRequests[room] ?? const []);

  /// Rooms where my join request is pending
  bool hasPendingRequest(String room) => _myPendingRooms.contains(room);

  /// Total count of pending join requests across all rooms I admin
  int get totalPendingJoinRequests =>
      _pendingJoinRequests.values.fold(0, (sum, list) => sum + list.length);

  /// True if current user is already a member of [room] or creator
  bool isMemberOf(String room) {
    if (_myMemberships.contains(room)) return true;
    final info = _roomsByName[room];
    if (info == null) return false;
    return info.createdBy == _username || info.members.contains(_username);
  }

  /// Consume the just-approved room notification (returns room name once then null)
  String? consumeJustApprovedRoom() {
    final r = _justApprovedRoom;
    _justApprovedRoom = null;
    return r;
  }

  Future<void> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _serverUrl = p.getString(_prefServer) ?? '';
    _username = p.getString(_prefUser) ?? '';
    _password = p.getString(_prefPass) ?? '';
    final raw = p.getString(_prefPublic);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _publicMessages.clear();
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            final m = ChatMessage.fromJson(e);
            if (m != null) _publicMessages.add(m);
          }
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefServer, _serverUrl);
    await p.setString(_prefUser, _username);
    await p.setString(_prefPass, _password);
  }

  Future<void> _persistPublicCache() async {
    final p = await SharedPreferences.getInstance();
    final slice = _publicMessages.length > 100
        ? _publicMessages.sublist(_publicMessages.length - 100)
        : List<ChatMessage>.from(_publicMessages);
    await p.setString(
      _prefPublic,
      jsonEncode(slice.map((m) => m.toJson()).toList()),
    );
  }

  void _wireSocket() {
    _socket.onConnected = () {
      _status = ConnectionStatus.connecting;
      notifyListeners();
    };
    _socket.onDisconnected = () {
      _status = ConnectionStatus.disconnected;
      notifyListeners();
    };
    _socket.onConnectError = (e) {
      _lastError = e?.toString() ?? 'Kết nối thất bại';
      _status = ConnectionStatus.disconnected;
      final c = _connectCompleter;
      if (c != null && !c.isCompleted) {
        c.complete(false);
        _connectCompleter = null;
      }
      notifyListeners();
    };
    _socket.onRegisterOk = (_) {
      _status = ConnectionStatus.connected;
      _lastError = null;
      final c = _connectCompleter;
      if (c != null && !c.isCompleted) {
        c.complete(true);
        _connectCompleter = null;
      }
      requestPublicHistory();
      requestRooms();
      requestAllUsers();
      notifyListeners();
    };
    _socket.onRegisterError = (data) {
      _lastError = data is Map && data['message'] != null
          ? data['message'].toString()
          : 'Đăng nhập thất bại';
      _status = ConnectionStatus.disconnected;
      final c = _connectCompleter;
      if (c != null && !c.isCompleted) {
        c.complete(false);
        _connectCompleter = null;
      }
      _socket.disconnect();
      notifyListeners();
    };
    _socket.onUserList = (data) {
      if (data is List) {
        _onlineUsers = data.map((e) => e.toString()).toList();
        _applyOnlineStatus();
        notifyListeners();
      }
    };
    _socket.onAllUsers = (data) {
      if (data is! Map) return;
      final raw = data['items'];
      if (raw is! List) return;
      _knownUsers = raw
          .whereType<Map>()
          .map((e) => User.fromJson(Map<String, dynamic>.from(e)))
          .whereType<User>()
          .where((u) => u.username != _username)
          .toList();
      _mergeChatPeersIntoKnownUsers();
      _applyOnlineStatus();
      notifyListeners();
    };
    _socket.onReceiveMessage = (data) {
      final m = _parsePublic(data);
      if (m != null) {
        _appendUnique(_publicMessages, m);
        notifyListeners();
        unawaited(_persistPublicCache());
      }
    };
    _socket.onReceivePrivateMessage = (data) {
      final m = _parsePrivate(data);
      if (m != null) {
        final peer = m.peer;
        if (peer == null) return;
        _appendUnique(_privateByPeer.putIfAbsent(peer, () => []), m);
        _mergeChatPeersIntoKnownUsers();
        _applyOnlineStatus();
        notifyListeners();
      }
    };
    _socket.onReceiveRoomMessage = (data) {
      final m = _parseRoom(data);
      if (m != null) {
        final room = m.room;
        if (room == null) return;
        _appendUnique(_roomMessages.putIfAbsent(room, () => []), m);
        notifyListeners();
      }
    };
    _socket.onPublicHistory = (data) {
      _mergePublicHistory(data);
    };
    _socket.onPrivateHistory = (data) {
      _mergePrivateHistory(data);
    };
    _socket.onRoomHistory = (data) {
      _mergeRoomHistory(data);
    };
    _socket.onRoomsList = (data) {
      _mergeRooms(data);
    };
    _socket.onCreateRoomError = (data) {
      _lastError = data is Map && data['message'] != null
          ? data['message'].toString()
          : 'Tạo phòng thất bại';
      notifyListeners();
    };
    _socket.onRoomMeta = (data) {
      _mergeRoomMeta(data);
    };
    _socket.onRoomMembers = (data) {
      _mergeRoomMembers(data);
    };
    _socket.onRoomActionError = (data) {
      _lastError = data is Map && data['message'] != null
          ? data['message'].toString()
          : 'Thao tac phong that bai';
      notifyListeners();
    };
    _socket.onRoomDeleted = (data) {
      _handleRoomDeleted(data);
    };
    _socket.onRoomRenamed = (data) {
      _handleRoomRenamed(data);
    };
    _socket.onRoomRemoved = (data) {
      final room = data is Map ? data['room']?.toString() : null;
      if (room != null && room.isNotEmpty) {
        _pendingDeletedRoom = room;
        _roomsByName.remove(room);
        _roomMessages.remove(room);
        _roomMembersByRoom.remove(room);
        _myPendingRooms.remove(room);
        _myMemberships.remove(room);
        _pendingJoinRequests.remove(room);
        notifyListeners();
      }
    };
    // ─── Join Request events ──────────────────────────────────────────────────
    _socket.onMyMemberships = (data) {
      if (data is List) {
        _myMemberships.clear();
        _myMemberships.addAll(data.map((e) => e.toString()));
        notifyListeners();
      }
    };
    _socket.onJoinRoomDenied = (data) {
      if (data is! Map) return;
      final room = data['room']?.toString();
      if (room != null && room.isNotEmpty) {
        _lastError = data['reason']?.toString() ?? 'Bạn chưa được mời vào phòng này.';
        notifyListeners();
      }
    };
    _socket.onJoinRequestPending = (data) {
      if (data is! Map) return;
      final room = data['room']?.toString();
      if (room != null && room.isNotEmpty) {
        _myPendingRooms.add(room);
        notifyListeners();
      }
    };
    _socket.onJoinRequestApproved = (data) {
      if (data is! Map) return;
      final room = data['room']?.toString();
      if (room != null && room.isNotEmpty) {
        _myPendingRooms.remove(room);
        _myMemberships.add(room);
        _justApprovedRoom = room;
        notifyListeners();
      }
    };
    _socket.onJoinRequestRejected = (data) {
      if (data is! Map) return;
      final room = data['room']?.toString();
      final reason = data['reason']?.toString();
      if (room != null && room.isNotEmpty) {
        _myPendingRooms.remove(room);
        _lastError = reason ?? 'Yêu cầu tham gia phòng đã bị từ chối.';
        notifyListeners();
      }
    };
    _socket.onJoinRequestError = (data) {
      if (data is! Map) return;
      _lastError = data['reason']?.toString() ?? 'Lỗi gửi yêu cầu tham gia phòng.';
      notifyListeners();
    };
    _socket.onJoinRequests = (data) {
      if (data is! Map) return;
      final room = data['room']?.toString();
      final raw = data['items'];
      if (room == null || room.isEmpty || raw is! List) return;
      _pendingJoinRequests[room] = raw
          .whereType<Map>()
          .map((e) => JoinRequest.fromJson(Map<String, dynamic>.from(e)))
          .whereType<JoinRequest>()
          .toList();
      notifyListeners();
    };
  }

  void _appendUnique(List<ChatMessage> list, ChatMessage message) {
    if (list.any((m) => m.id == message.id)) return;
    list.add(message);
  }

  DateTime _parseTimestamp(dynamic ts) {
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
    if (ts is String) {
      final asInt = int.tryParse(ts);
      if (asInt != null) {
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
      final dt = DateTime.tryParse(ts);
      if (dt != null) return dt;
    }
    return DateTime.now();
  }

  void _mergePublicHistory(dynamic data) {
    if (data is! Map) return;
    final rawItems = data['items'];
    if (rawItems is! List) return;
    _publicMessages
      ..clear()
      ..addAll(rawItems.map(_parsePublic).whereType<ChatMessage>());
    _publicHistoryLoaded = true;
    notifyListeners();
    unawaited(_persistPublicCache());
  }

  void _mergePrivateHistory(dynamic data) {
    if (data is! Map) return;
    final peer = data['peer']?.toString();
    final rawItems = data['items'];
    if (peer == null || rawItems is! List) return;
    _privateByPeer[peer] = rawItems
        .map(_parsePrivate)
        .whereType<ChatMessage>()
        .toList();
    notifyListeners();
  }

  void _mergeRoomHistory(dynamic data) {
    if (data is! Map) return;
    final room = data['room']?.toString();
    final rawItems = data['items'];
    if (room == null || rawItems is! List) return;
    _roomMessages[room] = rawItems
        .map(_parseRoom)
        .whereType<ChatMessage>()
        .toList();
    notifyListeners();
  }

  void _mergeRooms(dynamic data) {
    if (data is! Map) return;
    final items = data['items'];
    if (items is! List) return;
    _roomsByName.clear();
    for (final item in items) {
      if (item is! Map) continue;
      final room = RoomInfo.fromJson(Map<String, dynamic>.from(item));
      if (room != null) _roomsByName[room.name] = room;
    }
    notifyListeners();
  }

  void _mergeRoomMeta(dynamic data) {
    if (data is! Map) return;
    final room = data['room']?.toString();
    if (room == null || room.isEmpty) return;
    final previous = _roomsByName[room];
    final parsed = RoomInfo.fromJson(Map<String, dynamic>.from(data));
    if (parsed == null) return;
    _roomsByName[room] = parsed.copyWith(
      createdBy: parsed.createdBy.isNotEmpty
          ? parsed.createdBy
          : (previous?.createdBy ?? ''),
    );
    _mergeRoomMembers(data);
    notifyListeners();
  }

  void _mergeRoomMembers(dynamic data) {
    if (data is! Map) return;
    final room = data['room']?.toString();
    final raw = data['members'];
    if (room == null || room.isEmpty || raw is! List) return;
    _roomMembersByRoom[room] = raw
        .whereType<Map>()
        .map((e) => RoomMember.fromJson(Map<String, dynamic>.from(e)))
        .whereType<RoomMember>()
        .toList();
  }

  void _handleRoomDeleted(dynamic data) {
    if (data is! Map) return;
    final room = data['room']?.toString();
    if (room == null || room.isEmpty) return;
    _pendingDeletedRoom = room;
    _roomsByName.remove(room);
    _roomMessages.remove(room);
    _roomMembersByRoom.remove(room);
    notifyListeners();
  }

  void _handleRoomRenamed(dynamic data) {
    if (data is! Map) return;
    final oldName = data['oldName']?.toString();
    final newName = data['newName']?.toString();
    if (oldName == null ||
        newName == null ||
        oldName.isEmpty ||
        newName.isEmpty) {
      return;
    }

    final info = _roomsByName.remove(oldName);
    if (info != null) {
      _roomsByName[newName] = info.copyWith(name: newName);
    }

    final msgs = _roomMessages.remove(oldName);
    if (msgs != null) {
      _roomMessages[newName] = msgs;
    }

    final members = _roomMembersByRoom.remove(oldName);
    if (members != null) {
      _roomMembersByRoom[newName] = members;
    }

    _pendingRenamedRoom = (oldName, newName);
    notifyListeners();
  }

  String? consumeDeletedRoom(String room) {
    if (_pendingDeletedRoom != room) return null;
    _pendingDeletedRoom = null;
    return room;
  }

  String? consumeRenamedRoom(String currentRoom) {
    final pending = _pendingRenamedRoom;
    if (pending == null || pending.$1 != currentRoom) return null;
    _pendingRenamedRoom = null;
    return pending.$2;
  }

  ChatMessage? _parsePublic(dynamic data) {
    if (data is! Map) return null;
    final from = data['from']?.toString();
    final text = data['text']?.toString();
    if (from == null || text == null) return null;
    final ts = data['timestamp'];
    final t = _parseTimestamp(ts);
    return ChatMessage(
      id:
          data['id']?.toString() ??
          '${t.millisecondsSinceEpoch}_${from}_${text.hashCode}',
      from: from,
      text: text,
      timestamp: t,
      kind: MessageKind.public,
    );
  }

  ChatMessage? _parsePrivate(dynamic data) {
    if (data is! Map) return null;
    final from = data['from']?.toString();
    final to = data['to']?.toString();
    final text = data['text']?.toString();
    if (from == null || to == null || text == null) return null;
    final ts = data['timestamp'];
    final t = _parseTimestamp(ts);
    final peer = from == _username ? to : from;
    return ChatMessage(
      id:
          data['id']?.toString() ??
          '${t.millisecondsSinceEpoch}_${from}_${to}_${text.hashCode}',
      from: from,
      text: text,
      timestamp: t,
      kind: MessageKind.privateMessage,
      peer: peer,
      to: to,
    );
  }

  ChatMessage? _parseRoom(dynamic data) {
    if (data is! Map) return null;
    final from = data['from']?.toString();
    final room = data['room']?.toString();
    final text = data['text']?.toString();
    if (from == null || room == null || text == null) return null;
    final ts = data['timestamp'];
    final t = _parseTimestamp(ts);
    return ChatMessage(
      id:
          data['id']?.toString() ??
          '${t.millisecondsSinceEpoch}_${room}_${from}_${text.hashCode}',
      from: from,
      text: text,
      timestamp: t,
      kind: MessageKind.room,
      room: room,
    );
  }

  Future<bool> connect({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    _lastError = null;
    _publicHistoryLoaded = false;
    _serverUrl = serverUrl.trim();
    _username = username.trim();
    _password = password;
    if (_serverUrl.isEmpty || _username.isEmpty || _password.isEmpty) {
      _lastError = 'Nhập địa chỉ server, tên hiển thị và mật khẩu.';
      notifyListeners();
      return false;
    }
    if (_password.length < 4) {
      _lastError = 'Mật khẩu tối thiểu 4 ký tự.';
      notifyListeners();
      return false;
    }
    if (!_serverUrl.startsWith('http://') &&
        !_serverUrl.startsWith('https://')) {
      _lastError = 'URL phải bắt đầu bằng http:// hoặc https://';
      notifyListeners();
      return false;
    }

    _status = ConnectionStatus.connecting;
    notifyListeners();
    await _savePrefs();

    _connectCompleter = Completer<bool>();
    _socket.setCredentials(username: _username, password: _password);
    _socket.connect(_serverUrl);

    try {
      final ok = await _connectCompleter!.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          _lastError ??= 'Hết thời gian chờ server.';
          _status = ConnectionStatus.disconnected;
          _socket.disconnect();
          notifyListeners();
          return false;
        },
      );
      if (!ok) {
        _socket.disconnect();
      } else {
        _inAppSession = true;
      }
      return ok;
    } finally {
      _connectCompleter = null;
    }
  }

  void logout() {
    _inAppSession = false;
    _publicHistoryLoaded = false;
    _roomsByName.clear();
    _roomMembersByRoom.clear();
    _pendingJoinRequests.clear();
    _myPendingRooms.clear();
    _myMemberships.clear();
    _justApprovedRoom = null;
    _socket.clearSession();
    _status = ConnectionStatus.disconnected;
    _onlineUsers = [];
    _knownUsers = [];
    notifyListeners();
  }

  void sendPublic(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _socket.sendMessage(t);
  }

  void sendPrivateTo(String peer, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _socket.sendPrivateMessage(to: peer, text: t);
  }

  void joinRoom(String room) {
    final r = room.trim();
    if (r.isEmpty) return;
    _socket.joinRoom(r);
  }

  void createRoom(String room) {
    final r = room.trim();
    if (r.isEmpty) return;
    _socket.createRoom(r);
  }

  void requestRoomMembers(String room) {
    if (_status != ConnectionStatus.connected) return;
    final r = room.trim();
    if (r.isEmpty) return;
    _socket.fetchRoomMembers(r);
  }

  void deleteRoom(String room) {
    if (_status != ConnectionStatus.connected) return;
    final r = room.trim();
    if (r.isEmpty) return;
    _socket.deleteRoom(r);
  }

  void renameRoom(String room, String newName) {
    if (_status != ConnectionStatus.connected) return;
    final r = room.trim();
    final n = newName.trim();
    if (r.isEmpty || n.isEmpty) return;
    _socket.renameRoom(room: r, newName: n);
  }

  void addRoomMember(String room, String username) {
    if (_status != ConnectionStatus.connected) return;
    final r = room.trim();
    final u = username.trim();
    if (r.isEmpty || u.isEmpty) return;
    _socket.addRoomMember(room: r, username: u);
  }

  void removeRoomMember(String room, String username) {
    if (_status != ConnectionStatus.connected) return;
    final r = room.trim();
    final u = username.trim();
    if (r.isEmpty || u.isEmpty) return;
    _socket.removeRoomMember(room: r, username: u);
  }

  void sendRoom(String room, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _socket.sendRoomMessage(room: room, text: t);
  }

  void requestPublicHistory({int limit = 50}) {
    if (_status != ConnectionStatus.connected) return;
    if (_publicHistoryLoaded) return;
    _socket.fetchPublicHistory(limit: limit);
  }

  // ─── Join Request actions ──────────────────────────────────────────────────

  void requestJoinRoom(String room) {
    if (_status != ConnectionStatus.connected) return;
    final r = room.trim();
    if (r.isEmpty) return;
    _socket.requestJoinRoom(r);
  }

  void fetchJoinRequests(String room) {
    if (_status != ConnectionStatus.connected) return;
    final r = room.trim();
    if (r.isEmpty) return;
    _socket.fetchJoinRequests(r);
  }

  void approveJoinRequest(String room, String username) {
    if (_status != ConnectionStatus.connected) return;
    final r = room.trim();
    final u = username.trim();
    if (r.isEmpty || u.isEmpty) return;
    _socket.approveJoinRequest(room: r, username: u);
  }

  void rejectJoinRequest(String room, String username) {
    if (_status != ConnectionStatus.connected) return;
    final r = room.trim();
    final u = username.trim();
    if (r.isEmpty || u.isEmpty) return;
    _socket.rejectJoinRequest(room: r, username: u);
  }

  void requestPrivateHistory(String peer, {int limit = 50}) {
    if (_status != ConnectionStatus.connected) return;
    if (peer.trim().isEmpty) return;
    _socket.fetchPrivateHistory(peer: peer.trim(), limit: limit);
  }

  void requestRoomHistory(String room, {int limit = 50}) {
    if (_status != ConnectionStatus.connected) return;
    if (room.trim().isEmpty) return;
    _socket.fetchRoomHistory(room: room.trim(), limit: limit);
  }

  void requestRooms() {
    if (_status != ConnectionStatus.connected) return;
    _socket.fetchRooms();
  }

  void requestAllUsers() {
    if (_status != ConnectionStatus.connected) return;
    _socket.fetchAllUsers();
  }

  void _mergeChatPeersIntoKnownUsers() {
    final names = _knownUsers.map((u) => u.username).toSet();
    for (final peer in _privateByPeer.keys) {
      if (peer == _username || names.contains(peer)) continue;
      _knownUsers.add(User(username: peer));
      names.add(peer);
    }
  }

  void _applyOnlineStatus() {
    final online = _onlineUsers.toSet();
    _mergeChatPeersIntoKnownUsers();
    final byName = {for (final u in _knownUsers) u.username: u};
    for (final name in online) {
      if (name == _username) continue;
      if (!byName.containsKey(name)) {
        _knownUsers.add(User(username: name, isOnline: true));
        byName[name] = _knownUsers.last;
      }
    }
    _knownUsers = _knownUsers
        .map(
          (u) => u.copyWith(
            isOnline: online.contains(u.username) && u.username != _username,
          ),
        )
        .toList()
      ..sort((a, b) {
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        return a.username.compareTo(b.username);
      });
  }

  List<User> friendsForDisplay({String query = ''}) {
    final q = query.trim().toLowerCase();
    final list = q.isEmpty
        ? _knownUsers
        : _knownUsers
            .where((u) => u.username.toLowerCase().contains(q))
            .toList();
    return List.unmodifiable(list);
  }

  List<String> get roomNamesWithMessages {
    final k = {..._roomMessages.keys, ..._roomsByName.keys}.toList();
    k.sort();
    return List.unmodifiable(k);
  }

  List<String> peersForPrivate() {
    return friendsForDisplay().map((u) => u.username).toList();
  }
}
