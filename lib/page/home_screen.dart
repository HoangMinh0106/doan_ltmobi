import 'package:doan_ltmobi/page/home_page_body.dart';
import 'package:doan_ltmobi/page/profile_screen.dart';
//import 'package:doan_ltmobi/page/login_screen.dart'; 
import 'package:flutter/material.dart';

// MÀN HÌNH CHÍNH (FRAME)
class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> userDocument;

  const HomeScreen({
    Key? key,
    required this.userDocument,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late Map<String, dynamic> _currentUserDocument;

  @override
  void initState() {
    super.initState();
    _currentUserDocument = widget.userDocument;
  }

  // Callback function để cập nhật dữ liệu người dùng từ ProfileScreen
  void _updateUserDocument(Map<String, dynamic> newDocument) {
    setState(() {
      _currentUserDocument = newDocument;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String email = _currentUserDocument["email"] ?? "User";
    final String userName = email.split('@').first;

    // Danh sách các trang tương ứng với các tab
    final List<Widget> widgetOptions = <Widget>[
      // Tab 0: Trang chủ
      HomePageBody(
        userName: userName,
        profileImageBase64: _currentUserDocument["profile_image_base64"],
      ),
      // Tab 1: Giỏ hàng (Placeholder)
      const Center(child: Text('Trang Giỏ hàng')),
      // Tab 2: Yêu thích (Placeholder)
      const Center(child: Text('Trang Yêu thích')),
      // Tab 3: Hồ sơ
      ProfileScreen(
        userDocument: _currentUserDocument,
        onProfileUpdated: _updateUserDocument,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Trang chủ'),
              BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), activeIcon: Icon(Icons.shopping_cart), label: 'Giỏ hàng'),
              BottomNavigationBarItem(icon: Icon(Icons.favorite_border), activeIcon: Icon(Icons.favorite), label: 'Yêu thích'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Hồ sơ'),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: const Color(0xFFE57373),
            unselectedItemColor: Colors.grey,
            // *** BẮT ĐẦU THAY ĐỔI ***
            // Khôi phục lại logic chuyển tab như bình thường
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            // *** KẾT THÚC THAY ĐỔI ***
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            showUnselectedLabels: true,
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: widgetOptions,
      ),
    );
  }
}
