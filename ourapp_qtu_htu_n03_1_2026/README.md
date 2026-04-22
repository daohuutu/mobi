# PrivateChat App

    Ứng dụng nhắn tin nội bộ có thể nhắn tin qua mạng LAN (Hoặc thông qua các mạng LAN ảo)

# Thành viên
    Trần Quang Tú - 23017227 (Tugran2802).
    Đào Hữu Tú - 23017227 (daohuutu).

# Buổi thực hành số 2
1.  Xây dựng đối tượng:user, mesage, roomMessage

    Xây dựng các biến mô tả
    user: name, id
         String name;
        int id;
    
    message: content, id
        String content;
        int id;
    
    roomMessage: id, roomName, userId,messageId
        int id;
        String roomName;
        int userId;
        int messageId;
    
2. Thực hiện Collections

    var listUser = [user("Tu", 1), user("Tu2", 2)];

    var listMessage = [message("Hello", 1), message("Hi", 2)];
   
    var listRoomMessage = [roomMessage(1,"giai tri", 1, 1), roomMessage(2, "phong chat 2", 2, 2)];
   
4. Hiển thị dữ liệu

    Danh sách người dùng:
        ID: 1, Name: Tu ID: 2, Name: Tu2
   
    Danh sách tin nhắn:
        ID: 1, Content: Hello ID: 2, Content: Hi
# Buổi thực hành số 3
    
    Thêm class user, room_Infor, chat_message, list_ten_class(user)

