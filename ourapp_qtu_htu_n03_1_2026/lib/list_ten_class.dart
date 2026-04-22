import 'user.dart';

class Listtenclass {

  final List<User> _listTenclass = [];

  List<User> getAll() {
    return List.unmodifiable(_listTenclass);
  }

  void create(User user) {
    _listTenclass.add(user);
  }

  bool edit(int id, User newuser) {
    for (int i = 0; i < _listTenclass.length; i++) {
      if (_listTenclass[i].id == id) {
        _listTenclass[i] = newuser;
        return true;
      }
    }
    return false;
  }
}

void main() {
  final listManager = Listtenclass();

  listManager.create(const User(id: 1, username: 'Huu Tu', isOnline: true, status: 'Online', avatar: ''));
  listManager.create(const User(id: 2, username: 'Quang Tu', isOnline: false, status: 'Offline', avatar: ''));

  print('Danh sách ban đầu:');
  for (var item in listManager.getAll()) {
    print('${item.id} - ${item.username} - ${item.isOnline ? 'Online' : 'Offline'}');
  }

  listManager.edit(
    1,
    const User(id: 1, username: 'Tluss', isOnline: true, status: 'Online', avatar: ''),
  );
  listManager.edit(
    2,
    const User(id: 2, username: 'Tugran', isOnline: true, status: 'Online', avatar: ''),
  );

  print('\nDanh sách sau khi sửa:');
  for (var item in listManager.getAll()) {
    print('${item.id} - ${item.username} - ${item.isOnline ? 'Online' : 'Offline'}');
  }
}
