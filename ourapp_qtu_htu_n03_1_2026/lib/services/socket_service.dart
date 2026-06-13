import 'package:socket_io_client/socket_io_client.dart' as io;

/// Socket.IO client: [setUsername] then [connect]. Re-register runs on reconnect.
class SocketService {
  io.Socket? _socket;
  String? _username;
  String? _password;

  void Function()? onConnected;
  void Function()? onDisconnected;
  void Function(Object? error)? onConnectError;
  void Function(dynamic data)? onRegisterOk;
  void Function(dynamic data)? onRegisterError;
  void Function(dynamic data)? onUserList;
  void Function(dynamic data)? onAllUsers;
  void Function(dynamic data)? onReceiveMessage;
  void Function(dynamic data)? onReceivePrivateMessage;
  void Function(dynamic data)? onReceiveRoomMessage;
  void Function(dynamic data)? onPublicHistory;
  void Function(dynamic data)? onPrivateHistory;
  void Function(dynamic data)? onRoomHistory;
  void Function(dynamic data)? onRoomsList;
  void Function(dynamic data)? onCreateRoomError;
  void Function(dynamic data)? onRoomMeta;
  void Function(dynamic data)? onRoomMembers;
  void Function(dynamic data)? onRoomActionError;
  void Function(dynamic data)? onRoomDeleted;
  void Function(dynamic data)? onRoomRenamed;
  void Function(dynamic data)? onRoomRemoved;
  // Join request callbacks
  void Function(dynamic data)? onJoinRoomDenied;
  void Function(dynamic data)? onJoinRequestPending;
  void Function(dynamic data)? onJoinRequestApproved;
  void Function(dynamic data)? onJoinRequestRejected;
  void Function(dynamic data)? onJoinRequestError;
  void Function(dynamic data)? onJoinRequests;
  void Function(dynamic data)? onMyMemberships;

  bool get isConnected => _socket?.connected ?? false;

  void setCredentials({required String username, required String password}) {
    _username = username.trim();
    _password = password;
  }

  void _emitRegister() {
    final u = _username;
    final p = _password;
    if (u != null && u.isNotEmpty && p != null && p.isNotEmpty) {
      _socket?.emit('register', {'username': u, 'password': p});
    }
  }

  void connect(String baseUrl) {
    disconnect();
    var url = baseUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    final socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      _emitRegister();
      onConnected?.call();
    });
    socket.onDisconnect((_) => onDisconnected?.call());
    socket.onConnectError((e) => onConnectError?.call(e));
    socket.on('register_ok', (d) => onRegisterOk?.call(d));
    socket.on('register_error', (d) => onRegisterError?.call(d));
    socket.on('user_list', (d) => onUserList?.call(d));
    socket.on('all_users', (d) => onAllUsers?.call(d));
    socket.on('receive_message', (d) => onReceiveMessage?.call(d));
    socket.on(
      'receive_private_message',
      (d) => onReceivePrivateMessage?.call(d),
    );
    socket.on('receive_room_message', (d) => onReceiveRoomMessage?.call(d));
    socket.on('public_history', (d) => onPublicHistory?.call(d));
    socket.on('private_history', (d) => onPrivateHistory?.call(d));
    socket.on('room_history', (d) => onRoomHistory?.call(d));
    socket.on('rooms_list', (d) => onRoomsList?.call(d));
    socket.on('create_room_error', (d) => onCreateRoomError?.call(d));
    socket.on('room_meta', (d) => onRoomMeta?.call(d));
    socket.on('room_members', (d) => onRoomMembers?.call(d));
    socket.on('room_action_error', (d) => onRoomActionError?.call(d));
    socket.on('room_deleted', (d) => onRoomDeleted?.call(d));
    socket.on('room_renamed', (d) => onRoomRenamed?.call(d));
    socket.on('room_removed', (d) => onRoomRemoved?.call(d));
    // Join request events
    socket.on('join_room_denied', (d) => onJoinRoomDenied?.call(d));
    socket.on('join_request_pending', (d) => onJoinRequestPending?.call(d));
    socket.on('join_request_approved', (d) => onJoinRequestApproved?.call(d));
    socket.on('join_request_rejected', (d) => onJoinRequestRejected?.call(d));
    socket.on('join_request_error', (d) => onJoinRequestError?.call(d));
    socket.on('join_requests', (d) => onJoinRequests?.call(d));
    socket.on('my_memberships', (d) => onMyMemberships?.call(d));
    socket.onReconnect((_) => _emitRegister());

    socket.connect();
  }

  void sendMessage(String text) {
    _socket?.emit('send_message', {'text': text});
  }

  void sendPrivateMessage({required String to, required String text}) {
    _socket?.emit('private_message', {'to': to, 'text': text});
  }

  void joinRoom(String room) {
    _socket?.emit('join_room', {'room': room});
  }

  void sendRoomMessage({required String room, required String text}) {
    _socket?.emit('send_room_message', {'room': room, 'text': text});
  }

  void fetchPublicHistory({int limit = 50}) {
    _socket?.emit('fetch_public_history', {'limit': limit});
  }

  void fetchPrivateHistory({required String peer, int limit = 50}) {
    _socket?.emit('fetch_private_history', {'peer': peer, 'limit': limit});
  }

  void fetchRoomHistory({required String room, int limit = 50}) {
    _socket?.emit('fetch_room_history', {'room': room, 'limit': limit});
  }

  void fetchRooms() {
    _socket?.emit('fetch_rooms');
  }

  void fetchAllUsers() {
    _socket?.emit('fetch_all_users');
  }

  void createRoom(String room) {
    _socket?.emit('create_room', {'room': room});
  }

  void fetchRoomMembers(String room) {
    _socket?.emit('fetch_room_members', {'room': room});
  }

  void deleteRoom(String room) {
    _socket?.emit('delete_room', {'room': room});
  }

  void renameRoom({required String room, required String newName}) {
    _socket?.emit('rename_room', {'room': room, 'newName': newName});
  }

  void addRoomMember({required String room, required String username}) {
    _socket?.emit('add_room_member', {'room': room, 'username': username});
  }

  void removeRoomMember({required String room, required String username}) {
    _socket?.emit('remove_room_member', {'room': room, 'username': username});
  }

  // ─── Join Request emits ────────────────────────────────────────────────────

  void requestJoinRoom(String room) {
    _socket?.emit('request_join_room', {'room': room});
  }

  void fetchJoinRequests(String room) {
    _socket?.emit('fetch_join_requests', {'room': room});
  }

  void approveJoinRequest({required String room, required String username}) {
    _socket?.emit('approve_join_request', {'room': room, 'username': username});
  }

  void rejectJoinRequest({required String room, required String username}) {
    _socket?.emit('reject_join_request', {'room': room, 'username': username});
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void clearSession() {
    _username = null;
    _password = null;
    disconnect();
  }
}
