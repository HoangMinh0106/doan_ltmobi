// lib/page/product_detail_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:doan_ltmobi/page/checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Thêm import này
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final Map<String, dynamic> userDocument;
  final VoidCallback onProductAdded;
  final String selectedAddress;

  const ProductDetailScreen({
    Key? key,
    required this.product,
    required this.userDocument,
    required this.onProductAdded,
    required this.selectedAddress,
  }) : super(key: key);

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  final NumberFormat currencyFormatter =
      NumberFormat('#,##0', 'vi_VN'); // Thêm định dạng tiền tệ

  static const Color primaryColor = Color(0xFFF07167);
  static const Color secondaryColor = Color(0xFFFED9D9);
  static const Color textColor = Color(0xFF333333);
  static final Color secondaryTextColor = Colors.grey.shade600;
  static const Color scaffoldBackgroundColor = Colors.white;

  void _incrementQuantity() {
    setState(() {
      _quantity++;
    });
  }

  void _decrementQuantity() {
    setState(() {
      if (_quantity > 1) {
        _quantity--;
      }
    });
  }

  void _handleAddToCart() async {
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    final productName = widget.product['name'] ?? 'Sản phẩm';

    await MongoDatabase.addToCart(userId, widget.product, quantity: _quantity);

    widget.onProductAdded();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Đã thêm $productName (x$_quantity) vào giỏ hàng!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      );
    }
  }

  void _handleBuyNow() {
    final productPrice = (widget.product['price'] as num).toDouble();
    final totalPrice = productPrice * _quantity;

    final List<Map<String, dynamic>> buyNowItems = [
      {
        'productId': widget.product['_id'],
        'name': widget.product['name'],
        'imageUrl': widget.product['imageUrl'],
        'price': productPrice,
        'quantity': _quantity,
      }
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          userDocument: widget.userDocument,
          cartItems: buyNowItems,
          totalPrice: totalPrice,
          onOrderPlaced: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          shippingAddress: widget.selectedAddress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.product['name'] ?? 'Chưa có tên';
    final String imageUrl = widget.product['imageUrl'] ?? '';
    final double price = (widget.product['price'] as num?)?.toDouble() ?? 0.0;
    final String description =
        widget.product['description'] ?? 'Chưa có mô tả cho sản phẩm này.';
    final double rating = (widget.product['rating'] as num?)?.toDouble() ?? 4.5;
    final int reviewCount =
        (widget.product['reviewCount'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(imageUrl, name),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductHeader(name, rating, reviewCount),
                  const SizedBox(height: 24),
                  _buildQuantitySelector(price),
                  const SizedBox(height: 24),
                  _buildDivider(),
                  const SizedBox(height: 16),
                  _buildDescription(description),
                ],
              ),
            ),
          )
        ],
      ),
      bottomNavigationBar: _buildBottomActionButtons(),
    );
  }

  Widget _buildBottomActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 10,
          )
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: const Text("Thêm vào giỏ"),
              onPressed: _handleAddToCart,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: primaryColor,
                side: const BorderSide(color: primaryColor),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.flash_on, color: Colors.white),
              label: const Text(
                "Mua ngay",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: _handleBuyNow,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: primaryColor,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(String imageUrl, String name) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      stretch: true,
      backgroundColor: secondaryColor,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.8),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Hero(
          tag: widget.product['_id'],
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.image_not_supported, size: 60),
                )
              : const Icon(Icons.image_not_supported, size: 60),
        ),
      ),
    );
  }

  Widget _buildProductHeader(String name, double rating, int reviewCount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 4),
            Text(
              '$rating ($reviewCount)',
              style: TextStyle(fontSize: 16, color: secondaryTextColor),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildQuantitySelector(double price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _buildQuantityButton(
              icon: Icons.remove,
              onPressed: _decrementQuantity,
            ),
            SizedBox(
              width: 50,
              child: Text(
                '$_quantity',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            _buildQuantityButton(
              icon: Icons.add,
              onPressed: _incrementQuantity,
            ),
          ],
        ),
        Text(
          '${currencyFormatter.format(price * _quantity)} đ', // Sửa ở đây
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: textColor, size: 18),
        splashRadius: 20,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.grey.shade200, thickness: 1);
  }

  Widget _buildDescription(String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Mô tả sản phẩm",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            fontSize: 16,
            color: secondaryTextColor,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}