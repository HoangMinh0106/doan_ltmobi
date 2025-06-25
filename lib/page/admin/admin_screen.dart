// file: admin_screen.dart

import 'package:doan_ltmobi/page/login_screen.dart'; // Import để có thể quay lại trang login
import 'package:flutter/material.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang quản trị Admin'),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Xử lý đăng xuất: quay về trang đăng nhập và xóa các màn hình cũ
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          )
        ],
      ),
      body: const Center(
        child: Text(
          'Chào mừng Admin!',
          style: TextStyle(fontSize: 24, color: Colors.red),
        ),
      ),
    );
  }
}