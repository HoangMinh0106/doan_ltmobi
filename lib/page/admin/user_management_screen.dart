import 'dart:convert';
import 'dart:typed_data';

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as M;

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  /* ---------------- XÓA USER (đã có) ---------------- */
  Future<void> _deleteUser(M.ObjectId userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa người dùng này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await MongoDatabase.userCollection.remove(M.where.id(userId));
      if (mounted) {
        ElegantNotification.success(title: const Text('Thành công'), description: const Text('Đã xóa người dùng.')).show(context);
        setState(() {});
      }
    }
  }

  /* ------------- 🔥 NEW: THÊM VÀ CHỈNH SỬA USER ------------- */
  Future<void> _addOrEditUser({Map<String, dynamic>? user}) async {
    final bool isEditMode = user != null;
    final emailC = TextEditingController(text: isEditMode ? user['email'] : '');
    final phoneC = TextEditingController(text: isEditMode ? user['phone'] : '');
    // Thêm controller cho mật khẩu, chỉ yêu cầu khi thêm mới
    final passwordC = TextEditingController();
    String gender = isEditMode ? (user['gender'] ?? 'Nam') : 'Nam';

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: Text(isEditMode ? 'Chỉnh sửa thông tin' : 'Thêm người dùng mới'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Email')),
                  // Chỉ hiển thị trường mật khẩu khi thêm mới
                  if (!isEditMode)
                    TextField(controller: passwordC, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu')),
                  TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'Số điện thoại')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: gender,
                    decoration: const InputDecoration(labelText: 'Giới tính'),
                    items: const ['Nam', 'Nữ', 'Khác'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setSt(() => gender = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () {
                  // Kiểm tra trường bắt buộc khi thêm mới
                  if (!isEditMode && (emailC.text.isEmpty || passwordC.text.isEmpty)) {
                     ElegantNotification.error(title: const Text('Lỗi'), description: const Text('Email và mật khẩu là bắt buộc.')).show(context);
                     return;
                  }
                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                child: Text(isEditMode ? 'Lưu' : 'Thêm'),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true) {
      if (isEditMode) {
        // Chế độ chỉnh sửa
        await MongoDatabase.userCollection.updateOne(
          M.where.id(user['_id']),
          M.modify
            ..set('email', emailC.text.trim())
            ..set('phone', phoneC.text.trim())
            ..set('gender', gender),
        );
      } else {
        // Chế độ thêm mới
        await MongoDatabase.userCollection.insertOne({
          '_id': M.ObjectId(),
          'email': emailC.text.trim(),
          'password': passwordC.text.trim(), // Lưu ý: nên mã hóa mật khẩu trong ứng dụng thực tế
          'phone': phoneC.text.trim(),
          'gender': gender,
          'profile_image_base64': '', // Giá trị mặc định
        });
      }

      if (mounted) {
        ElegantNotification.success(
          title: const Text('Thành công'),
          description: Text(isEditMode ? 'Đã cập nhật thông tin.' : 'Đã thêm người dùng mới.'),
        ).show(context);
        setState(() {});
      }
    }
  }

  /* -------------------- UI LIST -------------------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý người dùng'), backgroundColor: Colors.redAccent),
      // *** BẮT ĐẦU THAY ĐỔI ***
      // Thêm nút Floating Action Button để thêm người dùng
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditUser(), // Gọi hàm ở chế độ "thêm mới"
        backgroundColor: Colors.redAccent,
        tooltip: 'Thêm người dùng mới',
        child: const Icon(Icons.add),
      ),
      // *** KẾT THÚC THAY ĐỔI ***
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: MongoDatabase.userCollection.find().toList(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Lỗi: ${snap.error}'));
          if (!snap.hasData || snap.data!.isEmpty) return const Center(child: Text('Không có người dùng nào.'));

          final users = snap.data!;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (ctx, i) {
              final u = users[i];
              Uint8List? avatarBytes;
              if (u['profile_image_base64'] != null && (u['profile_image_base64'] as String).isNotEmpty) {
                try {
                  avatarBytes = base64Decode(u['profile_image_base64']);
                } catch (_) {}
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: avatarBytes != null
                      ? CircleAvatar(backgroundImage: MemoryImage(avatarBytes))
                      : const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(u['email'] ?? 'Không có email', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(u['phone'] ?? 'Không có SĐT'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /* nút sửa */
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        // *** BẮT ĐẦU THAY ĐỔI ***
                        onPressed: () => _addOrEditUser(user: u), // Gọi hàm ở chế độ "chỉnh sửa"
                        // *** KẾT THÚC THAY ĐỔI ***
                      ),
                      /* nút xóa */
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteUser(u['_id']),
                      ),
                    ],
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