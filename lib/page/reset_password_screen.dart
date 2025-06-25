import 'package:flutter/material.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:mongo_dart/mongo_dart.dart' as M;
import 'package:doan_ltmobi/page/login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  void _resetPassword() async {
    final newPassword = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu phải có ít nhất 6 ký tự.')),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu xác nhận không khớp.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    // Cập nhật mật khẩu mới và xóa token
    await MongoDatabase.userCollection.update(
      M.where.eq('email', widget.email),
      M.modify
        .set('password', newPassword)
        .unset('resetToken') // Xóa token để không thể sử dụng lại
        .unset('resetTokenExpiry'),
    );

     ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đặt lại mật khẩu thành công! Vui lòng đăng nhập.')),
      );

    // Điều hướng về màn hình đăng nhập
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo mật khẩu mới')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _resetPassword,
              child: _isLoading ? const CircularProgressIndicator() : const Text('Đặt lại mật khẩu'),
            ),
          ],
        ),
      ),
    );
  }
}