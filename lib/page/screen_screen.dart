import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Sau khi hiển thị logo 2 giây, chuyển sang màn hình login
    Future.delayed(Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    });

    return Scaffold(
      backgroundColor: Color(0xFFFFCFCF),
      // Màu nền tùy chọn
      body: Center(
        child: Image.asset(
           "assets/logo-app.png",
          height: 100, // Kích thước logo
        ),
      ),
    );
  }
}


