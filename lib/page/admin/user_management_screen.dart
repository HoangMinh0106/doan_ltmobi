import 'dart:convert';
import 'dart:typed_data';

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as M;

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  // Hàm để xóa người dùng
  Future<void> _deleteUser(M.ObjectId userId) async {
    // Hiển thị hộp thoại xác nhận
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: const Text('Bạn có chắc chắn muốn xóa người dùng này không?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    // Nếu người dùng xác nhận xóa
    if (confirmDelete == true) {
      await MongoDatabase.userCollection.remove(M.where.id(userId));
      if (mounted) {
        ElegantNotification.success(
          title: const Text("Thành công"),
          description: const Text("Đã xóa người dùng thành công."),
        ).show(context);
      }
      // Tải lại danh sách người dùng
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý người dùng'),
        backgroundColor: Colors.redAccent,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // Lấy danh sách tất cả người dùng có vai trò là 'user'
        future: MongoDatabase.userCollection.find(M.where.eq('role', 'user')).toList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Không có người dùng nào.'));
          }

          var users = snapshot.data!;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final email = user['email'] ?? 'Không có email';
              final phone = user['phone'] ?? 'Không có SĐT';
              final imageBase64 = user['profile_image_base64'];
              
              Widget avatar;
              if (imageBase64 != null && imageBase64.isNotEmpty) {
                  try {
                    final Uint8List imageBytes = base64Decode(imageBase64);
                    avatar = CircleAvatar(backgroundImage: MemoryImage(imageBytes));
                  } catch(e) {
                    avatar = const CircleAvatar(child: Icon(Icons.person));
                  }
              } else {
                avatar = const CircleAvatar(child: Icon(Icons.person));
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: avatar,
                  title: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(phone),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteUser(user['_id']),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
