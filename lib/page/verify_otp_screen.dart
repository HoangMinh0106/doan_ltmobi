import 'package:doan_ltmobi/page/reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
//import 'package:mongo_dart/mongo_dart.dart' as M;

class VerifyOtpScreen extends StatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;

  void _verifyOtp() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mã OTP gồm 6 chữ số.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    
    // Tìm người dùng với email tương ứng
    var userDocument = await MongoDatabase.userCollection.findOne({
      "email": widget.email,
      "resetToken": _otpController.text,
    });

    if (userDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã OTP không hợp lệ.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    // Kiểm tra thời gian hết hạn
    DateTime expiryTime = userDocument["resetTokenExpiry"];
    if (DateTime.now().isAfter(expiryTime)) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã OTP đã hết hạn. Vui lòng thử lại.')),
      );
       setState(() => _isLoading = false);
      return;
    }
    
    // Xác thực thành công, điều hướng đến màn hình đặt lại mật khẩu
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (context) => ResetPasswordScreen(email: widget.email))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xác thực OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Một mã OTP đã được gửi đến ${widget.email}. Vui lòng nhập mã vào bên dưới.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              decoration: const InputDecoration(labelText: 'Mã OTP'),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
  }
}