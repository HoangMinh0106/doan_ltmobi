// lib/page/product_detail_screen.dart

import 'package:doan_ltmobi/page/cart_screen.dart';
import 'package:doan_ltmobi/page/checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:doan_ltmobi/dpHelper/mongodb.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final Map<String, dynamic> userDocument;
  final VoidCallback onProductAdded;
  final String selectedAddress;
  
  // *** KHÔI PHỤC LẠI: Thêm lại các tham số này để nhận dữ liệu ***
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.userDocument,
    required this.onProductAdded,
    required this.selectedAddress,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  int _cartTotalQuantity = 0;
  final NumberFormat currencyFormatter =
      NumberFormat('#,##0', 'vi_VN');

  static const Color primaryColor = Color(0xFFE57373);
  static const Color textColor = Color(0xFF333333);
  static final Color secondaryTextColor = Colors.grey.shade600;
  static const Color scaffoldBackgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _updateCartBadge();
  }

  Future<void> _updateCartBadge() async {
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    final count = await MongoDatabase.getCartTotalQuantity(userId);
    if (mounted) {
      setState(() {
        _cartTotalQuantity = count;
      });
    }
  }

  void _incrementQuantity() => setState(() => _quantity++);
  void _decrementQuantity() => setState(() {
    if (_quantity > 1) _quantity--;
  });

  void _handleAddToCart() async {
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    await MongoDatabase.addToCart(userId, widget.product, quantity: _quantity);
    widget.onProductAdded();
    _updateCartBadge();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Đã thêm '${widget.product['name']}' (x$_quantity) vào giỏ hàng!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _handleBuyNow() {
    final productPrice = (widget.product['price'] as num).toDouble();
    final totalPrice = productPrice * _quantity;
    final buyNowItems = [{
      'productId': widget.product['_id'],
      'name': widget.product['name'],
      'imageUrl': widget.product['imageUrl'],
      'price': productPrice,
      'quantity': _quantity,
    }];

    Navigator.push(context, MaterialPageRoute(
      builder: (context) => CheckoutScreen(
        userDocument: widget.userDocument,
        cartItems: buyNowItems,
        totalPrice: totalPrice,
        onOrderPlaced: () => Navigator.of(context).popUntil((route) => route.isFirst),
        shippingAddress: widget.selectedAddress,
      ),
    ));
  }

  void _navigateToCart() {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => CartScreen(
        userDocument: widget.userDocument,
        onCartUpdated: _updateCartBadge,
        selectedAddress: widget.selectedAddress,
        onCheckoutSuccess: () => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
    )).then((_) => _updateCartBadge());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(widget.product['imageUrl'] ?? ''),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductHeader(
                    widget.product['name'] ?? 'N/A',
                    (widget.product['rating'] as num?)?.toDouble() ?? 4.5,
                    (widget.product['reviewCount'] as num?)?.toInt() ?? 0,
                  ),
                  const SizedBox(height: 24),
                  _buildQuantitySelector((widget.product['price'] as num?)?.toDouble() ?? 0.0),
                  const SizedBox(height: 24),
                  _buildDivider(),
                  const SizedBox(height: 16),
                  _buildDescription(widget.product['description'] ?? 'Chưa có mô tả.'),
                ],
              ),
            ),
          )
        ],
      ),
      bottomNavigationBar: _buildBottomActionButtons(),
    );
  }

  SliverAppBar _buildSliverAppBar(String imageUrl) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.white,
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
      actions: [
        // *** KHÔI PHỤC LẠI ICON GIỎ HÀNG, XÓA ICON TRÁI TIM ***
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined, color: textColor),
                  onPressed: _navigateToCart,
                ),
                if (_cartTotalQuantity > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(10)),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$_cartTotalQuantity',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Hero(
          tag: widget.product['_id'],
          child: imageUrl.isNotEmpty
              ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.error))
              : const Icon(Icons.image_not_supported, size: 60),
        ),
      ),
    );
  }

  Widget _buildBottomActionButtons() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 15, 20, MediaQuery.of(context).padding.bottom + 15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 2, blurRadius: 10)],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.flash_on, color: Colors.white),
              label: const Text("Mua ngay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _handleBuyNow,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: primaryColor,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductHeader(String name, double rating, int reviewCount) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor))),
          const SizedBox(width: 16),
          Row(children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 4),
            Text('$rating ($reviewCount)', style: TextStyle(fontSize: 16, color: secondaryTextColor)),
          ])
        ],
      );

  Widget _buildQuantitySelector(double price) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            _buildQuantityButton(icon: Icons.remove, onPressed: _decrementQuantity),
            SizedBox(width: 50, child: Text('$_quantity', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor))),
            _buildQuantityButton(icon: Icons.add, onPressed: _incrementQuantity),
          ]),
          Text('${currencyFormatter.format(price * _quantity)} đ', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor)),
        ],
      );

  Widget _buildQuantityButton({required IconData icon, required VoidCallback onPressed}) => Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
        child: IconButton(onPressed: onPressed, icon: Icon(icon, color: textColor, size: 18), splashRadius: 20),
      );

  Widget _buildDivider() => Divider(color: Colors.grey.shade200, thickness: 1);

  Widget _buildDescription(String description) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Mô tả sản phẩm", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text(description, style: TextStyle(fontSize: 16, color: secondaryTextColor, height: 1.5)),
        ],
      );
}