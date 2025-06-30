// lib/page/home_screen.dart

import 'package:doan_ltmobi/page/home_page_body.dart';
import 'package:doan_ltmobi/page/profile_screen.dart';
import 'package:doan_ltmobi/page/product_screen.dart';
import 'package:doan_ltmobi/page/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final GlobalKey<ProductScreenState> _productScreenKey =
      GlobalKey<ProductScreenState>();

  String _selectedAddress = 'Vui lòng chọn địa chỉ của bạn!';

  @override
  void initState() {
    super.initState();
    _currentUserDocument = widget.userDocument;
  }

  void _updateAddress(String newAddress) {
    setState(() {
      _selectedAddress = newAddress;
    });
  }

  void _updateUserDocument(Map<String, dynamic> newDocument) {
    setState(() {
      _currentUserDocument = newDocument;
    });
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      _cartKey.currentState?.fetchCartItems();
    }
    if (_selectedIndex == 1 && index != 1) {
       _productScreenKey.currentState?.filterByCategory(null);
    }
    _updateProductScreenBadge();
    setState(() {
      _selectedIndex = index;
    });
  }
  
  void _navigateToHome() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  void _updateAllCarts() {
    _cartKey.currentState?.fetchCartItems();
    _updateProductScreenBadge();
  }

  void _updateProductScreenBadge() {
    _productScreenKey.currentState?.updateCartBadge();
  }

  void _onSearchSubmitted(String query) {
    _onItemTapped(1);
    Future.delayed(const Duration(milliseconds: 50), () {
      _productScreenKey.currentState?.performSearch(query);
    });
  }
  
  void _onCategorySelected(String? categoryId) {
    setState(() {
      _selectedIndex = 1;
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      _productScreenKey.currentState?.filterByCategory(categoryId);
    });
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận thoát'),
        content: const Text('Bạn có chắc chắn muốn thoát ứng dụng không?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy',style: TextStyle(color: Color(0xFFE57373))),
          ),
          TextButton(
            onPressed: () {
              SystemNavigator.pop();
            },
            child: const Text('Thoát',style: TextStyle(color: Color(0xFFE57373))),
          ),
        ],
      ),
    ) ?? false; 
  }

  @override
  Widget build(BuildContext context) {
    final String email = _currentUserDocument["email"] ?? "User";
    final String userName = email.split('@').first;

    final List<Widget> widgetOptions = <Widget>[
      HomePageBody(
        userName: userName,
        userDocument: _currentUserDocument,
        onProductAdded: _updateAllCarts,
        profileImageBase64: _currentUserDocument["profile_image_base64"],
        onSearchSubmitted: _onSearchSubmitted,
        onCategorySelected: _onCategorySelected,
        initialAddress: _selectedAddress,
        onAddressChanged: _updateAddress,
      ),
      ProductScreen(
        key: _productScreenKey,
        userDocument: _currentUserDocument,
        onProductAdded: _updateAllCarts,
        onCartIconTapped: () => _onItemTapped(2),
        selectedAddress: _selectedAddress,
      ),
      CartScreen(
        key: _cartKey,
        userDocument: _currentUserDocument,
        onCartUpdated: _updateProductScreenBadge,
        selectedAddress: _selectedAddress,
        onCheckoutSuccess: _navigateToHome,
      ),
      ProfileScreen(
        userDocument: _currentUserDocument,
        onProfileUpdated: _updateUserDocument,
      ),
    ];

    return WillPopScope(
      onWillPop: _showExitConfirmationDialog,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: IndexedStack(
          index: _selectedIndex,
          children: widgetOptions,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F0),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 10)
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            child: BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Trang chủ'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.widgets_outlined),
                    activeIcon: Icon(Icons.widgets),
                    label: 'Sản Phẩm'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.shopping_cart_outlined),
                    activeIcon: Icon(Icons.shopping_cart),
                    label: 'Giỏ hàng'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Hồ sơ'),
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
      ),
    );
  }
}