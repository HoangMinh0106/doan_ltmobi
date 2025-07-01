// lib/page/cart_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:doan_ltmobi/page/checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Thêm thư viện intl để định dạng
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class CartScreen extends StatefulWidget {
  final Map<String, dynamic> userDocument;
  final VoidCallback onCartUpdated;
  final String selectedAddress;
  final VoidCallback onCheckoutSuccess;

  const CartScreen({
    Key? key,
    required this.userDocument,
    required this.onCartUpdated,
    required this.selectedAddress,
    required this.onCheckoutSuccess,
  }) : super(key: key);

  @override
  CartScreenState createState() => CartScreenState();
}

class CartScreenState extends State<CartScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  double _totalPrice = 0.0;
  late AnimationController _listAnimationController;

  // Thêm định dạng tiền tệ
  final NumberFormat currencyFormatter = NumberFormat('#,##0', 'vi_VN');

  static const Color primaryColor = Color(0xFFE57373);
  static const Color secondaryTextColor = Colors.grey;
  static const Color backgroundColor = Color(0xFFF8F8F8);

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    fetchCartItems();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> fetchCartItems() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    final cartData = await MongoDatabase.getCart(userId);
    if (cartData != null && cartData['items'] != null) {
      final items = List<Map<String, dynamic>>.from(cartData['items']);
      _calculateTotal(items);
      if (mounted) {
        setState(() {
          _cartItems = items;
          _isLoading = false;
        });
        _listAnimationController.forward(from: 0.0);
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
    widget.onCartUpdated();
  }

  void _calculateTotal(List<Map<String, dynamic>> items) {
    double total = 0;
    for (var item in items) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      total += price * quantity;
    }
    _totalPrice = total;
  }

  void _updateQuantity(Map<String, dynamic> item, int newQuantity) async {
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    final productId = item['productId'] as mongo.ObjectId;
    if (newQuantity > 0) {
      await MongoDatabase.updateItemQuantity(userId, productId, newQuantity);
    } else {
      _deleteItem(item, skipConfirmation: true);
      return;
    }
    await fetchCartItems();
  }

  void _deleteItem(Map<String, dynamic> item, { bool skipConfirmation = false }) async {
    bool confirmDelete = skipConfirmation;
    if (!skipConfirmation) {
      confirmDelete = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('Xác nhận xóa'),
            content: Text('Bạn có chắc chắn muốn xóa "${item['name']}" khỏi giỏ hàng không?'),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
            ],
          );
        },
      ) ?? false;
    }
    if (confirmDelete == true) {
      final userId = widget.userDocument['_id'] as mongo.ObjectId;
      final productId = item['productId'] as mongo.ObjectId;
      await MongoDatabase.removeItemFromCart(userId, productId);
      await fetchCartItems();
    }
  }
  
  void _handleOrderPlaced() {
    fetchCartItems();
    widget.onCheckoutSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Giỏ hàng của bạn", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [ IconButton(icon: const Icon(Icons.refresh, color: Colors.black54), onPressed: fetchCartItems) ],
      ),
      body: _buildBodyContent(),
      bottomNavigationBar: _buildCheckoutSection(),
    );
  }

  Widget _buildCheckoutSection() {
    if (_cartItems.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        boxShadow: [ BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 5, blurRadius: 15) ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tạm tính', style: TextStyle(color: secondaryTextColor, fontSize: 16)),
              // Sửa đổi: Áp dụng định dạng tiền tệ
              Text('${currencyFormatter.format(_totalPrice)} VNĐ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Phí giao hàng', style: TextStyle(color: secondaryTextColor, fontSize: 16)),
              Text('Miễn phí', style: TextStyle(fontSize: 16, color: Colors.green.shade600, fontWeight: FontWeight.w500)),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng cộng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              // Sửa đổi: Áp dụng định dạng tiền tệ
              Text('${currencyFormatter.format(_totalPrice)} VNĐ', style: const TextStyle(color: primaryColor, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CheckoutScreen(
                    userDocument: widget.userDocument,
                    cartItems: _cartItems,
                    totalPrice: _totalPrice,
                    onOrderPlaced: _handleOrderPlaced,
                    shippingAddress: widget.selectedAddress,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 5,
              shadowColor: primaryColor.withOpacity(0.4),
            ),
            child: const Text('Thanh toán', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryColor));
    }
    if (_cartItems.isEmpty) {
      return _buildEmptyCart();
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _cartItems.length,
      itemBuilder: (context, index) {
        final item = _cartItems[index];
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _listAnimationController, curve: Interval((1 / _cartItems.length) * index, 1.0, curve: Curves.easeOut))),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _listAnimationController, curve: Interval((1 / _cartItems.length) * index, 1.0, curve: Curves.easeOut))),
            child: _buildCartItemCard(item),
          ),
        );
      },
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.remove_shopping_cart_outlined, size: 120, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          const Text("Giỏ hàng đang trống!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          const Text("Chọn bánh bạn thích và đưa nó vào đây nhé!", style: TextStyle(color: secondaryTextColor, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Dismissible(
        key: ValueKey(item['productId']),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _deleteItem(item, skipConfirmation: true),
        background: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: Colors.red.shade300, borderRadius: BorderRadius.circular(20)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [Icon(Icons.delete_sweep_outlined, color: Colors.white, size: 30)]),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), spreadRadius: 2, blurRadius: 10)]),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  item['imageUrl'] ?? '',
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(width: 90, height: 90, color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported, color: secondaryTextColor)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 90,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(item['name'] ?? 'Sản phẩm', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                      // Sửa đổi: Áp dụng định dạng tiền tệ
                      Text('${currencyFormatter.format((item['price'] as num?)?.toDouble() ?? 0.0)} VNĐ', style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
              ),
              _buildQuantityController(item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityController(Map<String, dynamic> item) {
    int quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    return Column(
      children: [
        _buildQuantityButton(icon: Icons.add, onPressed: () => _updateQuantity(item, quantity + 1)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text('$quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        _buildQuantityButton(icon: Icons.remove, onPressed: () => _updateQuantity(item, quantity - 1)),
      ],
    );
  }

  Widget _buildQuantityButton({ required IconData icon, required VoidCallback onPressed }) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: IconButton(padding: EdgeInsets.zero, icon: Icon(icon, size: 16), onPressed: onPressed),
    );
  }
}