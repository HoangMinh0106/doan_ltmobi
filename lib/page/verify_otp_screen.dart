// lib/page/verify_otp_screen.dart 

import 'package:doan_ltmobi/page/reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:pinput/pinput.dart'; 

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
    // --- Phần logic không thay đổi ---
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ 6 chữ số OTP.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    var userDocument = await MongoDatabase.userCollection.findOne({
      "email": widget.email,
      "resetToken": _otpController.text,
    });

    if (userDocument == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mã OTP không hợp lệ.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    DateTime expiryTime = userDocument["resetTokenExpiry"];
    if (DateTime.now().isAfter(expiryTime)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mã OTP đã hết hạn. Vui lòng thử lại.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(email: widget.email)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Giao diện được thiết kế lại hoàn toàn ---

    // Định dạng cho ô nhập OTP (trạng thái bình thường)
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(fontSize: 22, color: Colors.black),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
    );

    // Định dạng cho ô nhập OTP (khi được focus)
    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: const Color(0xFFE57373)),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Xác thực OTP'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Xác thực Email',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Text(
                'Nhập mã xác thực gồm 6 chữ số đã được gửi đến email:\n${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 40),

              // Widget Pinput để nhập OTP
              Pinput(
                length: 6,
                controller: _otpController,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                onCompleted: (pin) => _verifyOtp(), // Tự động xác thực khi nhập đủ
              ),

              const SizedBox(height: 40),
              
              // Nút xác nhận được làm cho đẹp hơn
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDE0E0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      )
                    : const Text(
                        'Xác nhận',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Không nhận được mã?"),
                  TextButton(
                    onPressed: () {
                      // TODO: Thêm logic gửi lại mã ở đây
                      // Bạn có thể gọi lại hàm _sendOtpCode từ màn hình trước
                       ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chức năng gửi lại mã đang được phát triển.')),
                        );
                    },
                    child: const Text(
                      'Gửi lại mã',
                      style: TextStyle(
                        color: Color(0xFFE57373),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}