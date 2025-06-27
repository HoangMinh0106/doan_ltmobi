// lib/page/product_detail_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'dart:ui'; // Import để dùng BackdropFilter

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final Map<String, dynamic> userDocument;
  final VoidCallback onProductAdded;

  const ProductDetailScreen({
    Key? key,
    required this.product,
    required this.userDocument,
    required this.onProductAdded,
  }) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  static const Color primaryColor = Color(0xFFE57373);
  static const Color secondaryTextColor = Colors.grey;

  void _handleAddToCart(BuildContext context) async {
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    final productName = widget.product['name'] ?? 'Sản phẩm';
    
    // Gọi hàm addToCart với số lượng đã chọn
    await MongoDatabase.addToCart(userId, widget.product, quantity: _quantity);
    
    widget.onProductAdded();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Đã thêm $_quantity '$productName' vào giỏ hàng!"),
        backgroundColor: primaryColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _incrementQuantity() {
    setState(() {
      _quantity++;
    });
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.product['name'] ?? 'Chưa có tên';
    final String imageUrl = widget.product['imageUrl'] ?? '';
    final double price = (widget.product['price'] as num?)?.toDouble() ?? 0.0;
    final String description = widget.product['description'] ?? 'Sản phẩm chưa có mô tả chi tiết.';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: CustomScrollView(
        slivers: [
          // App Bar với hình ảnh sản phẩm
          SliverAppBar(
            expandedHeight: 350.0,
            pinned: true,
            stretch: true,
            backgroundColor: primaryColor,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(56),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Hero(
                tag: widget.product['_id'],
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported, color: secondaryTextColor, size: 60),
                  ),
                ),
              ),
            ),
          ),
          // Phần nội dung chi tiết
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F8F8),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tên sản phẩm
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Merriweather', // Ví dụ một font đẹp
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Giá và bộ chọn số lượng
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${price.toStringAsFixed(0)} VNĐ',
                          style: const TextStyle(
                            color: primaryColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        _buildQuantitySelector(),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(thickness: 1),
                    const SizedBox(height: 24),
                    // Mô tả
                    const Text(
                      'Mô tả sản phẩm',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Nút thêm vào giỏ hàng
      bottomNavigationBar: _buildBottomAddToCartBar(context),
    );
  }

  // Widget cho bộ chọn số lượng
  Widget _buildQuantitySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove, color: Colors.black54),
            onPressed: _decrementQuantity,
          ),
          Text(
            '$_quantity',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: primaryColor),
            onPressed: _incrementQuantity,
          ),
        ],
      ),
    );
  }

  // Widget cho thanh "Add to Cart" ở dưới
  Widget _buildBottomAddToCartBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 5,
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: ElevatedButton.icon(
        onPressed: () => _handleAddToCart(context),
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text(
          'Thêm vào giỏ hàng',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 5,
          shadowColor: primaryColor.withOpacity(0.4),
        ),
      ),
    );
  }
}