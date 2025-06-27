// lib/page/cart_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class CartScreen extends StatefulWidget {
  final Map<String, dynamic> userDocument;
  // THAY ĐỔI 1: Thêm callback để thông báo cho HomeScreen
  final VoidCallback onCartUpdated;

  const CartScreen({
    Key? key,
    required this.userDocument,
    required this.onCartUpdated, // Yêu cầu callback trong constructor
  }) : super(key: key);

  @override
  CartScreenState createState() => CartScreenState();
}

class CartScreenState extends State<CartScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  double _totalPrice = 0.0;
  
  static const Color primaryColor = Color(0xFFE57373);
  static const Color secondaryTextColor = Colors.grey;
  static const Color backgroundColor = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    fetchCartItems();
  }
  
  Future<void> fetchCartItems() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    final cartData = await MongoDatabase.getCart(userId);

    if (cartData != null && cartData['items'] != null) {
      final items = List<Map<String, dynamic>>.from(cartData['items']);
      double total = 0;
      for (var item in items) {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        total += price * quantity;
      }
      if (mounted) {
        setState(() {
          _cartItems = items;
          _totalPrice = total;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _cartItems = [];
          _totalPrice = 0.0;
          _isLoading = false;
        });
      }
    }
    // THAY ĐỔI 2: Gọi callback mỗi khi giỏ hàng được fetch xong
    widget.onCartUpdated();
  }

  void _updateQuantity(Map<String, dynamic> item, int newQuantity) async {
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    final productId = item['productId'] as mongo.ObjectId;

    if (newQuantity > 0) {
      await MongoDatabase.updateItemQuantity(userId, productId, newQuantity);
    } else {
      await MongoDatabase.removeItemFromCart(userId, productId);
    }
    await fetchCartItems(); // Fetch lại để cập nhật UI và gọi callback
  }
  
  void _deleteItem(Map<String, dynamic> item) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc chắn muốn xóa "${item['name']}" khỏi giỏ hàng không?'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
          ],
        );
      },
    ) ?? false;

    if (confirmDelete == true) {
      final userId = widget.userDocument['_id'] as mongo.ObjectId;
      final productId = item['productId'] as mongo.ObjectId;
      await MongoDatabase.removeItemFromCart(userId, productId);
      await fetchCartItems(); // Fetch lại để cập nhật UI và gọi callback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Giỏ hàng", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        actions: [ IconButton(icon: const Icon(Icons.refresh, color: Colors.black54), onPressed: fetchCartItems) ],
      ),
      body: _buildBodyContent(),
      bottomNavigationBar: _buildCheckoutSection(),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryColor));
    }
    if (_cartItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.remove_shopping_cart_outlined, size: 80, color: secondaryTextColor),
            SizedBox(height: 16),
            Text("Giỏ hàng của bạn đang trống.", style: TextStyle(color: secondaryTextColor, fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _cartItems.length,
      itemBuilder: (context, index) {
        final item = _cartItems[index];
        return _buildCartItemCard(item);
      },
    );
  }
  
  Widget _buildCartItemCard(Map<String, dynamic> item) {
    final String name = item['name'] ?? 'Sản phẩm';
    final String imageUrl = item['imageUrl'] ?? '';
    final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final int quantity = (item['quantity'] as num?)?.toInt() ?? 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      shadowColor: Colors.grey.withOpacity(0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                width: 80, height: 80, fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 80, height: 80, color: Colors.grey.shade200,
                  child: const Icon(Icons.image_not_supported, color: secondaryTextColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 80, 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text('${price.toStringAsFixed(0)} VNĐ', style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Row(
                  children: [
                    _buildQuantityButton(icon: Icons.remove, onPressed: () => _updateQuantity(item, quantity - 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('$quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    _buildQuantityButton(icon: Icons.add, onPressed: () => _updateQuantity(item, quantity + 1)),
                  ],
                ),
                SizedBox(
                  height: 36,
                  child: IconButton(
                    iconSize: 22,
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                    onPressed: () => _deleteItem(item),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuantityButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
      child: IconButton(padding: EdgeInsets.zero, icon: Icon(icon, size: 18), onPressed: onPressed),
    );
  }

  Widget _buildCheckoutSection() {
    if (_cartItems.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16).copyWith(bottom: MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [ BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, -5)) ],
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tổng cộng', style: TextStyle(color: secondaryTextColor, fontSize: 14)),
              const SizedBox(height: 4),
              Text('${_totalPrice.toStringAsFixed(0)} VNĐ', style: const TextStyle(color: primaryColor, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          ElevatedButton(
            onPressed: () { print("Thanh toán"); },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            child: const Text('Thanh toán', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}