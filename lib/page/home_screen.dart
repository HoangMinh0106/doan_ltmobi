// lib/page/home_screen.dart

import 'package:doan_ltmobi/page/home_page_body.dart';
import 'package:doan_ltmobi/page/profile_screen.dart';
import 'package:doan_ltmobi/page/product_screen.dart';
import 'package:doan_ltmobi/page/cart_screen.dart';
import 'package:flutter/material.dart';

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

  final GlobalKey<CartScreenState> _cartKey = GlobalKey<CartScreenState>();

  @override
  void initState() {
    super.initState();
    _currentUserDocument = widget.userDocument;
  }

  void _updateUserDocument(Map<String, dynamic> newDocument) {
    setState(() {
      _currentUserDocument = newDocument;
    });
  }

  void _onItemTapped(int index) {
    // Cập nhật giỏ hàng khi người dùng chủ động nhấn vào tab
    if (index == 2) {
      _cartKey.currentState?.fetchCartItems();
    }
    setState(() {
      _selectedIndex = index;
    });
  }
  
  // Hàm để điều hướng đến tab giỏ hàng
  void _navigateToCartTab() {
    _onItemTapped(2);
  }

  @override
  Widget build(BuildContext context) {
    final String email = _currentUserDocument["email"] ?? "User";
    final String userName = email.split('@').first;

    // Danh sách các trang tương ứng với các tab
    final List<Widget> widgetOptions = <Widget>[
      HomePageBody(
        userName: userName,
        profileImageBase64: _currentUserDocument["profile_image_base64"],
      ),
      // DÒNG BỊ LỖI CỦA BẠN ĐÃ ĐƯỢC SỬA Ở ĐÂY
      ProductScreen(
        userDocument: _currentUserDocument,
        onProductAdded: _navigateToCartTab,
        // Tham số onCartIconTapped đã được thêm vào đây
        onCartIconTapped: _navigateToCartTab,
      ),
      CartScreen(
        key: _cartKey,
        userDocument: _currentUserDocument
      ),
      ProfileScreen(
        userDocument: _currentUserDocument,
        onProfileUpdated: _updateUserDocument,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: widgetOptions,
      ),
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
              BottomNavigationBarItem(icon: Icon(Icons.widgets_outlined), activeIcon: Icon(Icons.widgets), label: 'Sản Phẩm'),
              BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), activeIcon: Icon(Icons.shopping_cart), label: 'Giỏ hàng'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Hồ sơ'),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: const Color(0xFFE57373),
            unselectedItemColor: Colors.grey,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            showUnselectedLabels: true,
          ),
        ),
      ),
    );
  }
}