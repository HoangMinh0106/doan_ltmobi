import 'package:doan_ltmobi/page/verify_otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as M;
import 'package:random_string/random_string.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  // --- CẤU HÌNH GỬI EMAIL ---
  // THAY THẾ bằng email và mật khẩu ứng dụng của bạn
  // LƯU Ý: Đây là mật khẩu ứng dụng, không phải mật khẩu email thông thường.
  final String username = 'nguyenminh01060210@gmail.com'; //  <-- THAY THẾ EMAIL CỦA BẠN
  final String appPassword = 'ddhandbrzdlnonbf'; //  <-- THAY THẾ MẬT KHẨU ỨNG DỤNG

  Future<void> _sendOtpCode() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập email của bạn.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    final email = _emailController.text;
    var userDocument = await MongoDatabase.userCollection.findOne({"email": email});

    if (userDocument == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email không tồn tại trong hệ thống.')),
        );
      }
      return;
    }

    // 1. Tạo mã OTP và thời gian hết hạn
    String otp = randomNumeric(6); // Tạo mã OTP 6 chữ số
    DateTime expiryTime = DateTime.now().add(const Duration(minutes: 10));

    // 2. Gửi mã OTP qua email
    final smtpServer = gmail(username, appPassword);
    final message = Message()
      ..from = Address(username, 'Hỗ trợ ứng dụng')
      ..recipients.add(email)
      ..subject = 'Mã xác thực đặt lại mật khẩu của bạn'
      ..html = "<h3>Xin chào,</h3>"
          "<p>Mã OTP để đặt lại mật khẩu của bạn là: <strong>$otp</strong></p>"
          "<p>Mã này sẽ hết hạn trong 10 phút. Vui lòng không chia sẻ mã này với bất kỳ ai.</p>";

    try {
      await send(message, smtpServer);

      // 3. Cập nhật mã OTP và thời gian hết hạn vào MongoDB
      await MongoDatabase.userCollection.update(
        M.where.eq('email', email),
        M.modify.set('resetToken', otp).set('resetTokenExpiry', expiryTime),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mã OTP đã được gửi đến email của bạn.')),
        );
      
        // 4. Điều hướng đến màn hình xác thực OTP
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyOtpScreen(email: email), // Truyền email qua
          ),
        );
      }
    } on MailerException catch (e) {
      print('Message not sent. \n${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể gửi email. Vui lòng kiểm tra lại cấu hình.')),
        );
      }
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quên mật khẩu'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 50),
                Image.asset('assets/logo-app.png', height: 90),
                const SizedBox(height: 40),
                const Text(
                  'Nhập email của bạn để nhận mã xác thực',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    floatingLabelStyle: const TextStyle(color: Colors.black),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 0, 0, 0)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 0, 0, 0), width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),

                // --- ĐÂY LÀ PHẦN ĐÃ SỬA LẠI ĐÚNG ---
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtpCode,
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
                          'Gửi mã xác thực',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}