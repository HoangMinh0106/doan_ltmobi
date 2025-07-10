// lib/page/change_password_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class ChangePasswordScreen extends StatefulWidget {
  final mongo.ObjectId userId;

  const ChangePasswordScreen({super.key, required this.userId});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isOldPasswordObscure = true;
  bool _isNewPasswordObscure = true;
  bool _isConfirmPasswordObscure = true;

  static const Color primaryColor = Color(0xFFE57373);

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;

    final success = await MongoDatabase.changePassword(widget.userId, oldPassword, newPassword);

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        // *** BẮT ĐẦU SỬA LỖI ***
        ElegantNotification.success(
          title: const Text("Thành công"),
          description: const Text("Mật khẩu của bạn đã được thay đổi."),
        ).show(context);
        
        // Đợi 2 giây để người dùng đọc thông báo rồi mới quay lại
        await Future.delayed(const Duration(seconds: 2));
        
        if (mounted) {
          Navigator.pop(context);
        }
        // *** KẾT THÚC SỬA LỖI ***
      } else {
        ElegantNotification.error(
          title: const Text("Thất bại"),
          description: const Text("Mật khẩu cũ không chính xác. Vui lòng thử lại."),
        ).show(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Đổi mật khẩu"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Icon(Icons.lock_person_outlined, size: 80, color: primaryColor),
              ),
              const SizedBox(height: 32),
              
              _buildPasswordTextField(
                controller: _oldPasswordController,
                label: "Mật khẩu cũ",
                isObscure: _isOldPasswordObscure,
                toggleObscure: () => setState(() => _isOldPasswordObscure = !_isOldPasswordObscure),
              ),
              const SizedBox(height: 20),
              
              _buildPasswordTextField(
                controller: _newPasswordController,
                label: "Mật khẩu mới",
                isObscure: _isNewPasswordObscure,
                toggleObscure: () => setState(() => _isNewPasswordObscure = !_isNewPasswordObscure),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mật khẩu mới';
                  }
                  if (value.length < 6) {
                    return 'Mật khẩu phải có ít nhất 6 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              _buildPasswordTextField(
                controller: _confirmPasswordController,
                label: "Xác nhận mật khẩu mới",
                isObscure: _isConfirmPasswordObscure,
                toggleObscure: () => setState(() => _isConfirmPasswordObscure = !_isConfirmPasswordObscure),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng xác nhận mật khẩu';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Mật khẩu không khớp';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _handleChangePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text('Lưu thay đổi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordTextField({
    required TextEditingController controller,
    required String label,
    required bool isObscure,
    required VoidCallback toggleObscure,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) {
          return 'Vui lòng không để trống';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
        suffixIcon: IconButton(
          icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
          onPressed: toggleObscure,
        ),
      ),
    );
  }
}