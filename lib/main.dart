import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:flutter/material.dart';
import 'page/screen_screen.dart'; 

void main() async {
  // Đảm bảo các binding của Flutter đã được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();
  
  // Gọi kết nối đến database khi ứng dụng bắt đầu
  await MongoDatabase.connect();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  // Thêm const vào constructor
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Popelini Barkery',
      debugShowCheckedModeBanner: false,

      // Trỏ trực tiếp đến màn hình bắt đầu của bạn
      home: SplashScreen(), 
    );
  }
}