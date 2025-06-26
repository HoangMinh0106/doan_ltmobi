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

  /* ------------- 🔥 NEW: CHỈNH SỬA USER ------------- */
  Future<void> _editUser(Map<String, dynamic> user) async {
    final emailC  = TextEditingController(text: user['email']);
    final phoneC  = TextEditingController(text: user['phone']);
    String gender = user['gender'] ?? 'Nam';

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: const Text('Chỉnh sửa thông tin'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Email')),
                  TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'Số điện thoại')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: gender,
                    decoration: const InputDecoration(labelText: 'Giới tính'),
                    items: const ['Nam', 'Nữ', 'Khác']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setSt(() => gender = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                child: const Text('Lưu'),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true) {
      await MongoDatabase.userCollection.updateOne(
        M.where.id(user['_id']),
        M.modify
          ..set('email', emailC.text.trim())
          ..set('phone', phoneC.text.trim())
          ..set('gender', gender),
      );
      if (mounted) {
        ElegantNotification.success(title: const Text('Thành công'), description: const Text('Đã cập nhật thông tin.')).show(context);
        setState(() {});
      }
    }
  }

  /* -------------------- UI LIST -------------------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý người dùng'), backgroundColor: Colors.redAccent),
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
                try { avatarBytes = base64Decode(u['profile_image_base64']); } catch (_) {}
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
                        onPressed: () => _editUser(u),
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
