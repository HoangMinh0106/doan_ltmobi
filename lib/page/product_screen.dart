// lib/page/product_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:doan_ltmobi/page/product_detail_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class ProductScreen extends StatefulWidget {
  final Map<String, dynamic> userDocument;
  final VoidCallback onProductAdded;
  // THAY ĐỔI 1: Thêm callback mới cho việc nhấn vào icon
  final VoidCallback onCartIconTapped;

  const ProductScreen({
    Key? key,
    required this.userDocument,
    required this.onProductAdded,
    // THAY ĐỔI 2: Yêu cầu callback trong constructor
    required this.onCartIconTapped,
  }) : super(key: key);

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _cartTotalQuantity = 0;

  static const Color primaryColor = Color(0xFFE57373);
  static const Color secondaryTextColor = Colors.grey;
  static const Color backgroundColor = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterProducts);
    _fetchProducts();
    _updateCartBadge();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _fetchProducts() async {
    try {
      final products = await MongoDatabase.productCollection.find().toList();
      if (mounted) {
        setState(() {
          _allProducts = products;
          _filteredProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Lỗi khi lấy dữ liệu sản phẩm: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Không thể tải dữ liệu. Vui lòng thử lại.";
          _isLoading = false;
        });
      }
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final productName = (product['name'] as String? ?? '').toLowerCase();
        return productName.contains(query);
      }).toList();
    });
  }

  void _handleAddToCart(Map<String, dynamic> product) async {
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    final productName = product['name'] ?? 'Sản phẩm';
    await MongoDatabase.addToCart(userId, product);
    await _updateCartBadge();
    widget.onProductAdded();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Đã thêm '$productName' vào giỏ hàng!"),
          backgroundColor: primaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Sản phẩm", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.grey.withOpacity(0.2),
        centerTitle: true,
        actions: [
          _buildCartIcon()
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBodyContent()),
        ],
      ),
    );
  }
  
  Widget _buildCartIcon() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black54, size: 28),
            // THAY ĐỔI 3: Gọi callback khi nhấn vào icon
            onPressed: widget.onCartIconTapped,
          ),
          if (_cartTotalQuantity > 0)
            Positioned(
              right: 5,
              top: 5,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Color(0xFFE57373),
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  '$_cartTotalQuantity',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm sản phẩm...',
          prefixIcon: const Icon(Icons.search, color: secondaryTextColor),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0), borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryColor));
    }
    if (_errorMessage.isNotEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: secondaryTextColor, fontSize: 16))));
    }
    if (_filteredProducts.isEmpty) {
      return const Center(child: Text("Không tìm thấy sản phẩm nào.", style: TextStyle(color: secondaryTextColor, fontSize: 16)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.67, crossAxisSpacing: 16, mainAxisSpacing: 16),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 50 * (1 - value)),
                child: child,
              ),
            );
          },
          child: _buildProductCard(product),
        );
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final String name = product['name'] ?? 'Chưa có tên';
    final String imageUrl = product['imageUrl'] ?? '';
    final double price = (product['price'] as num?)?.toDouble() ?? 0.0;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18.0), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), spreadRadius: 2, blurRadius: 8, offset: const Offset(0, 4))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(
                    product: product,
                    userDocument: widget.userDocument,
                    onProductAdded: widget.onProductAdded,
                  ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: Hero(
                      tag: product['_id'],
                      child: imageUrl.isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(primaryColor)));
                              },
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline, color: secondaryTextColor, size: 40))
                          : const Icon(Icons.image_not_supported, color: secondaryTextColor, size: 40),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('${price.toStringAsFixed(0)} VNĐ', style: const TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.w900)),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(10)),
                              child: IconButton(
                                onPressed: () => _handleAddToCart(product),
                                icon: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}