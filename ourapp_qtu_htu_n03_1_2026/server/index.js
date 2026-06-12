const http = require("http");
const express = require("express");
const crypto = require("crypto");
const { MongoClient } = require("mongodb");
const { Server } = require("socket.io");

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: { origin: "*", methods: ["GET", "POST"] },
});

const socketToUser = new Map();
const userToSocket = new Map();
const joinedRoomsBySocket = new Map();

const MONGO_URL = process.env.MONGO_URL || "mongodb://127.0.0.1:27017/privatechat";
const DB_NAME = process.env.MONGO_DB || "privatechat";
const HISTORY_LIMIT_MAX = 200;

let mongoDb = null;
let usersCol = null;
let roomsCol = null;
let roomMembersCol = null;
let messagesCol = null;
let joinRequestsCol = null;

function hashPassword(raw) {
  return crypto.createHash("sha256").update(String(raw)).digest("hex");
}

async function initMongo() {
  const client = new MongoClient(MONGO_URL);
  await client.connect();
  mongoDb = client.db(DB_NAME);
  usersCol = mongoDb.collection("users");
  roomsCol = mongoDb.collection("rooms");
  roomMembersCol = mongoDb.collection("room_members");
  messagesCol = mongoDb.collection("messages");

  joinRequestsCol = mongoDb.collection("join_requests");

  await Promise.all([
    usersCol.createIndex({ username: 1 }, { unique: true }),
    roomsCol.createIndex({ name: 1 }, { unique: true }),
    roomMembersCol.createIndex({ room: 1, username: 1 }, { unique: true }),
    messagesCol.createIndex({ scope: 1, createdAt: -1 }),
    messagesCol.createIndex({ scope: 1, room: 1, createdAt: -1 }),
    messagesCol.createIndex({ scope: 1, participants: 1, createdAt: -1 }),
    joinRequestsCol.createIndex({ room: 1, username: 1 }, { unique: true }),
    joinRequestsCol.createIndex({ room: 1, status: 1 }),
  ]);
}

function messageToPayload(doc) {
  return {
    id: doc._id.toString(),
    from: doc.from,
    to: doc.to || undefined,
    room: doc.room || undefined,
    text: doc.text,
    timestamp: doc.createdAt.getTime(),
  };
}

function normalizeLimit(raw, fallback = 50) {
  const n = Number(raw);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(1, Math.min(HISTORY_LIMIT_MAX, Math.floor(n)));
}

async function saveUser(username) {
  await usersCol.updateOne(
    { username },
    { $set: { lastSeenAt: new Date() }, $setOnInsert: { createdAt: new Date() } },
    { upsert: true },
  );
}

async function authenticateUser(username, password) {
  const passwordHash = hashPassword(password);
  const now = new Date();
  const user = await usersCol.findOne({ username });
  if (!user) {
    await usersCol.insertOne({
      username,
      passwordHash,
      createdAt: now,
      lastSeenAt: now,
    });
    return { ok: true, created: true };
  }
  if (!user.passwordHash) {
    await usersCol.updateOne(
      { username },
      { $set: { passwordHash, lastSeenAt: now } },
    );
    return { ok: true, created: false };
  }
  if (user.passwordHash !== passwordHash) {
    return { ok: false, reason: "Sai mat khau." };
  }
  await usersCol.updateOne({ username }, { $set: { lastSeenAt: now } });
  return { ok: true, created: false };
}

async function savePublicMessage({ from, text }) {
  const doc = {
    scope: "public",
    from,
    text,
    createdAt: new Date(),
  };
  const result = await messagesCol.insertOne(doc);
  return { ...doc, _id: result.insertedId };
}

async function savePrivateMessage({ from, to, text }) {
  const participants = [from, to].sort().join("|");
  const doc = {
    scope: "private",
    from,
    to,
    participants,
    text,
    createdAt: new Date(),
  };
  const result = await messagesCol.insertOne(doc);
  return { ...doc, _id: result.insertedId };
}

async function saveRoomMessage({ from, room, text }) {
  const doc = {
    scope: "room",
    from,
    room,
    text,
    createdAt: new Date(),
  };
  const result = await messagesCol.insertOne(doc);
  return { ...doc, _id: result.insertedId };
}

async function ensureRoomMembership(room, username) {
  const now = new Date();
  await Promise.all([
    roomsCol.updateOne(
      { name: room },
      { $setOnInsert: { name: room, createdAt: now, createdBy: username } },
      { upsert: true },
    ),
    roomMembersCol.updateOne(
      { room, username },
      { $set: { lastJoinedAt: now }, $setOnInsert: { joinedAt: now } },
      { upsert: true },
    ),
  ]);
}

async function createRoom(room, username) {
  const now = new Date();
  const exists = await roomsCol.findOne({ name: room }, { projection: { _id: 1 } });
  if (exists) return { ok: false, reason: "Phong da ton tai." };
  await Promise.all([
    roomsCol.insertOne({
      name: room,
      createdAt: now,
      createdBy: username,
      admins: [username],
    }),
    roomMembersCol.updateOne(
      { room, username },
      { $set: { role: "admin", lastJoinedAt: now }, $setOnInsert: { joinedAt: now } },
      { upsert: true },
    ),
  ]);
  return { ok: true };
}

async function listRooms() {
  const rooms = await roomsCol
    .find(
      {},
      { projection: { _id: 0, name: 1, createdBy: 1, createdAt: 1, admins: 1 } },
    )
    .sort({ name: 1 })
    .toArray();
  return rooms;
}

async function getRoomDoc(room) {
  return roomsCol.findOne({ name: room });
}

function isRoomAdmin(roomDoc, username) {
  if (!roomDoc || !username) return false;
  const admins = Array.isArray(roomDoc.admins) ? roomDoc.admins : [];
  return admins.includes(username) || roomDoc.createdBy === username;
}

async function listRoomMembers(room) {
  const rows = await roomMembersCol.find({ room }).sort({ username: 1 }).toArray();
  return rows.map((row) => ({
    username: row.username,
    role: row.role || "member",
    joinedAt: row.joinedAt ? row.joinedAt.getTime() : null,
  }));
}

async function buildRoomMeta(room) {
  const roomDoc = await getRoomDoc(room);
  const members = await listRoomMembers(room);
  return {
    room,
    name: room,
    createdBy: roomDoc?.createdBy || "",
    admins: Array.isArray(roomDoc?.admins) ? roomDoc.admins : [],
    members,
  };
}

async function broadcastRoomMeta(room) {
  try {
    const payload = await buildRoomMeta(room);
    io.to(room).emit("room_meta", payload);
    await broadcastRoomsList();
  } catch (err) {
    console.error("broadcast room meta error", err);
  }
}

async function deleteRoom(room, username) {
  const roomDoc = await getRoomDoc(room);
  if (!isRoomAdmin(roomDoc, username)) {
    return { ok: false, reason: "Ban khong co quyen xoa phong." };
  }
  await Promise.all([
    roomsCol.deleteOne({ name: room }),
    roomMembersCol.deleteMany({ room }),
    messagesCol.deleteMany({ scope: "room", room }),
  ]);
  const sockets = await io.in(room).fetchSockets();
  for (const s of sockets) {
    s.leave(room);
    const joined = joinedRoomsBySocket.get(s.id);
    if (joined) joined.delete(room);
  }
  io.emit("room_deleted", { room });
  await broadcastRoomsList();
  return { ok: true };
}

async function renameRoom(oldName, newName, username) {
  const roomDoc = await getRoomDoc(oldName);
  if (!isRoomAdmin(roomDoc, username)) {
    return { ok: false, reason: "Ban khong co quyen doi ten phong." };
  }
  if (!newName || newName === oldName) {
    return { ok: false, reason: "Ten phong khong hop le." };
  }
  const exists = await roomsCol.findOne({ name: newName }, { projection: { _id: 1 } });
  if (exists) return { ok: false, reason: "Phong da ton tai." };

  await roomsCol.updateOne({ name: oldName }, { $set: { name: newName } });
  await roomMembersCol.updateMany({ room: oldName }, { $set: { room: newName } });
  await messagesCol.updateMany({ scope: "room", room: oldName }, { $set: { room: newName } });

  const sockets = await io.in(oldName).fetchSockets();
  for (const s of sockets) {
    s.leave(oldName);
    s.join(newName);
    const joined = joinedRoomsBySocket.get(s.id);
    if (joined) {
      joined.delete(oldName);
      joined.add(newName);
    }
  }

  io.emit("room_renamed", { oldName, newName });
  await broadcastRoomMeta(newName);
  return { ok: true, newName };
}

async function addRoomMember(room, targetUsername, byUsername) {
  const roomDoc = await getRoomDoc(room);
  if (!isRoomAdmin(roomDoc, byUsername)) {
    return { ok: false, reason: "Ban khong co quyen them thanh vien." };
  }
  if (!targetUsername || targetUsername === byUsername) {
    return { ok: false, reason: "Ten thanh vien khong hop le." };
  }
  const user = await usersCol.findOne({ username: targetUsername }, { projection: { _id: 1 } });
  if (!user) return { ok: false, reason: "Nguoi dung khong ton tai." };

  const now = new Date();
  await roomMembersCol.updateOne(
    { room, username: targetUsername },
    { $set: { lastJoinedAt: now }, $setOnInsert: { joinedAt: now, role: "member" } },
    { upsert: true },
  );
  await broadcastRoomMeta(room);
  return { ok: true };
}

async function removeRoomMember(room, targetUsername, byUsername) {
  const roomDoc = await getRoomDoc(room);
  if (!roomDoc) return { ok: false, reason: "Phong khong ton tai." };

  const isAdmin = isRoomAdmin(roomDoc, byUsername);
  if (!isAdmin && byUsername !== targetUsername) {
    return { ok: false, reason: "Ban khong co quyen xoa thanh vien." };
  }

  const admins = Array.isArray(roomDoc.admins) ? roomDoc.admins : [];
  if (admins.includes(targetUsername) && admins.length <= 1) {
    return { ok: false, reason: "Khong the xoa admin cuoi cung." };
  }

  await roomMembersCol.deleteOne({ room, username: targetUsername });
  if (admins.includes(targetUsername)) {
    await roomsCol.updateOne({ name: room }, { $pull: { admins: targetUsername } });
  }

  const targetSocketId = userToSocket.get(targetUsername);
  if (targetSocketId) {
    const targetSocket = io.sockets.sockets.get(targetSocketId);
    targetSocket?.leave(room);
    const joined = joinedRoomsBySocket.get(targetSocketId);
    if (joined) joined.delete(room);
    targetSocket?.emit("room_removed", { room });
  }

  await broadcastRoomMeta(room);
  return { ok: true };
}

async function broadcastRoomsList() {
  try {
    const rooms = await listRooms();
    io.emit("rooms_list", { items: rooms });
  } catch (err) {
    console.error("broadcast rooms list error", err);
  }
}

// ─── Join Request helpers ──────────────────────────────────────────────────

async function isMember(room, username) {
  const doc = await roomMembersCol.findOne(
    { room, username },
    { projection: { _id: 1 } },
  );
  return !!doc;
}

async function getPendingRequest(room, username) {
  return joinRequestsCol.findOne({ room, username, status: "pending" });
}

async function listPendingRequests(room) {
  const rows = await joinRequestsCol
    .find({ room, status: "pending" })
    .sort({ createdAt: 1 })
    .toArray();
  return rows.map((r) => ({
    room: r.room,
    username: r.username,
    createdAt: r.createdAt.getTime(),
  }));
}

async function notifyAdminsOfRequest(room, requester) {
  try {
    const roomDoc = await getRoomDoc(room);
    if (!roomDoc) return;
    const admins = Array.isArray(roomDoc.admins) ? roomDoc.admins : [];
    const adminSet = new Set([...admins, roomDoc.createdBy]);
    for (const adminName of adminSet) {
      const socketId = userToSocket.get(adminName);
      if (socketId) {
        const pending = await listPendingRequests(room);
        io.to(socketId).emit("join_requests", { room, items: pending });
      }
    }
  } catch (err) {
    console.error("notifyAdminsOfRequest error", err);
  }
}

async function fetchPublicHistory(limit) {
  const rows = await messagesCol
    .find({ scope: "public" })
    .sort({ createdAt: -1 })
    .limit(limit)
    .toArray();
  rows.reverse();
  return rows.map(messageToPayload);
}

async function fetchRoomHistory(room, limit) {
  const rows = await messagesCol
    .find({ scope: "room", room })
    .sort({ createdAt: -1 })
    .limit(limit)
    .toArray();
  rows.reverse();
  return rows.map(messageToPayload);
}

async function fetchPrivateHistory(userA, userB, limit) {
  const participants = [userA, userB].sort().join("|");
  const rows = await messagesCol
    .find({ scope: "private", participants })
    .sort({ createdAt: -1 })
    .limit(limit)
    .toArray();
  rows.reverse();
  return rows.map(messageToPayload);
}

function broadcastUserList() {
  const users = Array.from(userToSocket.keys()).sort();
  io.emit("user_list", users);
}

async function listAllUsers() {
  const online = new Set(userToSocket.keys());
  const rows = await usersCol
    .find({}, { projection: { username: 1, lastSeenAt: 1 } })
    .sort({ username: 1 })
    .toArray();
  return rows.map((row) => ({
    username: row.username,
    lastSeenAt: row.lastSeenAt ? row.lastSeenAt.getTime() : null,
    isOnline: online.has(row.username),
  }));
}

app.get("/", (_req, res) => {
  res.type("text/plain").send("LAN Chat Socket.IO server OK");
});

io.on("connection", (socket) => {
  socket.on("register", async (payload) => {
    const raw =
      payload && typeof payload.username === "string" ? payload.username : "";
    const password =
      payload && typeof payload.password === "string" ? payload.password : "";
    const username = raw.trim().slice(0, 32);
    if (!username || password.trim().length < 4) {
      socket.emit("register_error", { message: "Ten hoac mat khau khong hop le." });
      return;
    }

    const auth = await authenticateUser(username, password.trim());
    if (!auth.ok) {
      socket.emit("register_error", { message: auth.reason || "Dang nhap that bai." });
      return;
    }

    const prevUser = socketToUser.get(socket.id);
    if (prevUser && userToSocket.get(prevUser) === socket.id) {
      userToSocket.delete(prevUser);
    }

    socketToUser.set(socket.id, username);
    userToSocket.set(username, socket.id);
    broadcastUserList();
    
    // Fetch memberships
    try {
      const myMemberships = await roomMembersCol
        .find({ username })
        .toArray();
      const myRoomNames = myMemberships.map((m) => m.room);
      socket.emit("my_memberships", myRoomNames);
    } catch (err) {
      console.error("fetch my memberships error", err);
    }

    socket.emit("register_ok", { username, created: Boolean(auth.created) });
    fetchPublicHistory(50)
      .then((items) => {
        socket.emit("public_history", { items });
      })
      .catch((err) => {
        console.error("public history on register error", err);
      });
    broadcastRoomsList();
  });

  socket.on("fetch_rooms", () => {
    listRooms()
      .then((items) => socket.emit("rooms_list", { items }))
      .catch((err) => console.error("fetch rooms error", err));
  });

  socket.on("fetch_all_users", () => {
    listAllUsers()
      .then((items) => socket.emit("all_users", { items }))
      .catch((err) => console.error("fetch all users error", err));
  });

  socket.on("create_room", async (payload) => {
    const username = socketToUser.get(socket.id);
    const room =
      payload && typeof payload.room === "string"
        ? payload.room.trim().slice(0, 64)
        : "";
    if (!username || !room) return;
    const created = await createRoom(room, username);
    if (!created.ok) {
      socket.emit("create_room_error", { room, message: created.reason });
      return;
    }
    socket.join(room);
    socket.emit("room_created", { room, admin: username });
    await broadcastRoomsList();
  });

  socket.on("fetch_public_history", (payload) => {
    const limit = normalizeLimit(payload && payload.limit, 50);
    fetchPublicHistory(limit)
      .then((items) => {
        socket.emit("public_history", { items });
      })
      .catch((err) => {
        console.error("fetch_public_history error", err);
      });
  });

  socket.on("send_message", async (payload) => {
    const from = socketToUser.get(socket.id);
    const text = payload && payload.text != null ? String(payload.text) : "";
    if (!from || !text.trim()) return;
    try {
      const doc = await savePublicMessage({ from, text: text.slice(0, 2000) });
      io.emit("receive_message", messageToPayload(doc));
    } catch (err) {
      console.error("save public message error", err);
    }
  });

  socket.on("fetch_private_history", (payload) => {
    const from = socketToUser.get(socket.id);
    const to = payload && typeof payload.peer === "string" ? payload.peer.trim() : "";
    if (!from || !to) return;
    const limit = normalizeLimit(payload && payload.limit, 50);
    fetchPrivateHistory(from, to, limit)
      .then((items) => {
        socket.emit("private_history", { peer: to, items });
      })
      .catch((err) => {
        console.error("fetch_private_history error", err);
      });
  });

  socket.on("private_message", async (payload) => {
    const from = socketToUser.get(socket.id);
    const to = payload && typeof payload.to === "string" ? payload.to.trim() : "";
    const text = payload && payload.text != null ? String(payload.text) : "";
    if (!from || !to || !text.trim()) return;

    let payloadOut;
    try {
      const doc = await savePrivateMessage({ from, to, text: text.slice(0, 2000) });
      payloadOut = messageToPayload(doc);
    } catch (err) {
      console.error("save private message error", err);
      return;
    }

    const targetId = userToSocket.get(to);
    if (targetId && targetId !== socket.id) {
      io.to(targetId).emit("receive_private_message", payloadOut);
    }
    socket.emit("receive_private_message", payloadOut);
  });

  socket.on("join_room", async (payload) => {
    const username = socketToUser.get(socket.id);
    const room = payload && typeof payload.room === "string" ? payload.room.trim().slice(0, 64) : "";
    if (!room || !username) return;

    try {
      // Check membership — only existing members (or room admins) can join directly
      const member = await isMember(room, username);
      if (!member) {
        // Check if the room even exists
        const roomDoc = await getRoomDoc(room);
        if (roomDoc) {
          // Room exists but user is not a member → deny
          socket.emit("join_room_denied", { room, reason: "Bạn chưa được mời vào phòng này." });
          return;
        }
        // Room doesn't exist yet — allow creator flow (create_room handles this)
        socket.emit("join_room_denied", { room, reason: "Phòng không tồn tại." });
        return;
      }

      socket.join(room);
      joinedRoomsBySocket.set(
        socket.id,
        (joinedRoomsBySocket.get(socket.id) || new Set()).add(room),
      );
      const items = await fetchRoomHistory(room, 50);
      socket.emit("room_history", { room, items });
      const meta = await buildRoomMeta(room);
      socket.emit("room_meta", meta);
    } catch (err) {
      console.error("join_room error", err);
    }
  });

  socket.on("request_join_room", async (payload) => {
    const username = socketToUser.get(socket.id);
    const room = payload && typeof payload.room === "string" ? payload.room.trim().slice(0, 64) : "";
    if (!room || !username) return;

    try {
      // Already a member?
      const member = await isMember(room, username);
      if (member) {
        socket.emit("join_request_approved", { room });
        return;
      }

      // Room exists?
      const roomDoc = await getRoomDoc(room);
      if (!roomDoc) {
        socket.emit("join_request_error", { room, reason: "Phòng không tồn tại." });
        return;
      }

      // Already has a pending request?
      const existing = await getPendingRequest(room, username);
      if (existing) {
        socket.emit("join_request_pending", { room });
        return;
      }

      // Save the request
      await joinRequestsCol.updateOne(
        { room, username },
        { $set: { status: "pending", createdAt: new Date() } },
        { upsert: true },
      );

      socket.emit("join_request_pending", { room });
      await notifyAdminsOfRequest(room, username);
    } catch (err) {
      console.error("request_join_room error", err);
    }
  });

  socket.on("fetch_join_requests", async (payload) => {
    const username = socketToUser.get(socket.id);
    const room = payload && typeof payload.room === "string" ? payload.room.trim().slice(0, 64) : "";
    if (!room || !username) return;

    try {
      const roomDoc = await getRoomDoc(room);
      if (!isRoomAdmin(roomDoc, username)) {
        socket.emit("room_action_error", { room, action: "fetch_join_requests", message: "Bạn không có quyền xem yêu cầu." });
        return;
      }
      const items = await listPendingRequests(room);
      socket.emit("join_requests", { room, items });
    } catch (err) {
      console.error("fetch_join_requests error", err);
    }
  });

  socket.on("approve_join_request", async (payload) => {
    const adminUsername = socketToUser.get(socket.id);
    const room = payload && typeof payload.room === "string" ? payload.room.trim().slice(0, 64) : "";
    const targetUsername = payload && typeof payload.username === "string" ? payload.username.trim().slice(0, 32) : "";
    if (!adminUsername || !room || !targetUsername) return;

    try {
      const roomDoc = await getRoomDoc(room);
      if (!isRoomAdmin(roomDoc, adminUsername)) {
        socket.emit("room_action_error", { room, action: "approve_join_request", message: "Bạn không có quyền duyệt yêu cầu." });
        return;
      }

      // Add as member
      const now = new Date();
      await roomMembersCol.updateOne(
        { room, username: targetUsername },
        { $set: { lastJoinedAt: now, role: "member" }, $setOnInsert: { joinedAt: now } },
        { upsert: true },
      );

      // Mark request approved
      await joinRequestsCol.updateOne(
        { room, username: targetUsername },
        { $set: { status: "approved", resolvedAt: now, resolvedBy: adminUsername } },
      );

      // Notify the requester
      const targetSocketId = userToSocket.get(targetUsername);
      if (targetSocketId) {
        io.to(targetSocketId).emit("join_request_approved", { room });
      }

      // Notify remaining admins with updated list
      await notifyAdminsOfRequest(room, targetUsername);
      await broadcastRoomMeta(room);
    } catch (err) {
      console.error("approve_join_request error", err);
      socket.emit("room_action_error", { room, action: "approve_join_request", message: "Lỗi duyệt yêu cầu." });
    }
  });

  socket.on("reject_join_request", async (payload) => {
    const adminUsername = socketToUser.get(socket.id);
    const room = payload && typeof payload.room === "string" ? payload.room.trim().slice(0, 64) : "";
    const targetUsername = payload && typeof payload.username === "string" ? payload.username.trim().slice(0, 32) : "";
    if (!adminUsername || !room || !targetUsername) return;

    try {
      const roomDoc = await getRoomDoc(room);
      if (!isRoomAdmin(roomDoc, adminUsername)) {
        socket.emit("room_action_error", { room, action: "reject_join_request", message: "Bạn không có quyền từ chối yêu cầu." });
        return;
      }

      const now = new Date();
      await joinRequestsCol.updateOne(
        { room, username: targetUsername },
        { $set: { status: "rejected", resolvedAt: now, resolvedBy: adminUsername } },
      );

      // Notify the requester
      const targetSocketId = userToSocket.get(targetUsername);
      if (targetSocketId) {
        io.to(targetSocketId).emit("join_request_rejected", { room, reason: "Yêu cầu tham gia phòng đã bị từ chối." });
      }

      // Notify remaining admins with updated list
      await notifyAdminsOfRequest(room, targetUsername);
    } catch (err) {
      console.error("reject_join_request error", err);
      socket.emit("room_action_error", { room, action: "reject_join_request", message: "Lỗi từ chối yêu cầu." });
    }
  });

  socket.on("fetch_room_members", async (payload) => {
    const room =
      payload && typeof payload.room === "string"
        ? payload.room.trim().slice(0, 64)
        : "";
    if (!room) return;
    try {
      const members = await listRoomMembers(room);
      socket.emit("room_members", { room, members });
    } catch (err) {
      console.error("fetch_room_members error", err);
    }
  });

  socket.on("delete_room", async (payload) => {
    const username = socketToUser.get(socket.id);
    const room =
      payload && typeof payload.room === "string"
        ? payload.room.trim().slice(0, 64)
        : "";
    if (!username || !room) return;
    try {
      const result = await deleteRoom(room, username);
      if (!result.ok) {
        socket.emit("room_action_error", { room, action: "delete", message: result.reason });
      }
    } catch (err) {
      console.error("delete_room error", err);
      socket.emit("room_action_error", { room, action: "delete", message: "Loi xoa phong." });
    }
  });

  socket.on("rename_room", async (payload) => {
    const username = socketToUser.get(socket.id);
    const oldName =
      payload && typeof payload.room === "string"
        ? payload.room.trim().slice(0, 64)
        : "";
    const newName =
      payload && typeof payload.newName === "string"
        ? payload.newName.trim().slice(0, 64)
        : "";
    if (!username || !oldName || !newName) return;
    try {
      const result = await renameRoom(oldName, newName, username);
      if (!result.ok) {
        socket.emit("room_action_error", {
          room: oldName,
          action: "rename",
          message: result.reason,
        });
      }
    } catch (err) {
      console.error("rename_room error", err);
      socket.emit("room_action_error", { room: oldName, action: "rename", message: "Loi doi ten phong." });
    }
  });

  socket.on("add_room_member", async (payload) => {
    const username = socketToUser.get(socket.id);
    const room =
      payload && typeof payload.room === "string"
        ? payload.room.trim().slice(0, 64)
        : "";
    const member =
      payload && typeof payload.username === "string"
        ? payload.username.trim().slice(0, 32)
        : "";
    if (!username || !room || !member) return;
    try {
      const result = await addRoomMember(room, member, username);
      if (!result.ok) {
        socket.emit("room_action_error", {
          room,
          action: "add_member",
          message: result.reason,
        });
      }
    } catch (err) {
      console.error("add_room_member error", err);
      socket.emit("room_action_error", {
        room,
        action: "add_member",
        message: "Loi them thanh vien.",
      });
    }
  });

  socket.on("remove_room_member", async (payload) => {
    const username = socketToUser.get(socket.id);
    const room =
      payload && typeof payload.room === "string"
        ? payload.room.trim().slice(0, 64)
        : "";
    const member =
      payload && typeof payload.username === "string"
        ? payload.username.trim().slice(0, 32)
        : "";
    if (!username || !room || !member) return;
    try {
      const result = await removeRoomMember(room, member, username);
      if (!result.ok) {
        socket.emit("room_action_error", {
          room,
          action: "remove_member",
          message: result.reason,
        });
      }
    } catch (err) {
      console.error("remove_room_member error", err);
      socket.emit("room_action_error", {
        room,
        action: "remove_member",
        message: "Loi xoa thanh vien.",
      });
    }
  });

  socket.on("fetch_room_history", (payload) => {
    const room =
      payload && typeof payload.room === "string"
        ? payload.room.trim().slice(0, 64)
        : "";
    if (!room) return;
    const limit = normalizeLimit(payload && payload.limit, 50);
    fetchRoomHistory(room, limit)
      .then((items) => {
        socket.emit("room_history", { room, items });
      })
      .catch((err) => {
        console.error("fetch_room_history error", err);
      });
  });

  socket.on("send_room_message", async (payload) => {
    const from = socketToUser.get(socket.id);
    const room = payload && typeof payload.room === "string" ? payload.room.trim().slice(0, 64) : "";
    const text = payload && payload.text != null ? String(payload.text) : "";
    if (!from || !room || !text.trim()) return;

    try {
      const doc = await saveRoomMessage({ from, room, text: text.slice(0, 2000) });
      io.to(room).emit("receive_room_message", messageToPayload(doc));
    } catch (err) {
      console.error("save room message error", err);
    }
  });

  socket.on("disconnect", () => {
    const u = socketToUser.get(socket.id);
    socketToUser.delete(socket.id);
    if (u && userToSocket.get(u) === socket.id) {
      userToSocket.delete(u);
    }
    joinedRoomsBySocket.delete(socket.id);
    broadcastUserList();
  });
});

const PORT = Number(process.env.PORT) || 3000;
const HOST = process.env.HOST || "0.0.0.0";

initMongo()
  .then(() => {
    console.log(`MongoDB connected: ${MONGO_URL} (db: ${DB_NAME})`);
    server.listen(PORT, HOST, () => {
      console.log(`LAN Chat server listening on http://${HOST}:${PORT}`);
    });
  })
  .catch((err) => {
    console.error("MongoDB init failed:", err);
    process.exit(1);
  });
