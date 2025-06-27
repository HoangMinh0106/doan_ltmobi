// lib/page/product_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:doan_ltmobi/page/product_detail_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class ProductScreen extends StatefulWidget {
  final Map<String, dynamic> userDocument;
  final VoidCallback onProductAdded;
  final VoidCallback onCartIconTapped;

  const ProductScreen({
    Key? key,
    required this.userDocument,
    required this.onProductAdded,
    required this.onCartIconTapped,
  }) : super(key: key);

  @override
  ProductScreenState createState() => ProductScreenState();
}

class ProductScreenState extends State<ProductScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _cartTotalQuantity = 0;

  // --- BẢNG MÀU ĐƯỢC CẢI THIỆN ---
  static const Color primaryColor = Color(0xFFF07167); // Màu san hô hiện đại
  static const Color scaffoldBackgroundColor = Color(0xFFF9F9F9); // Màu nền trắng ngà
  static const Color textColor = Color(0xFF333333); // Màu chữ chính (xám đậm)
  static final Color secondaryTextColor = Colors.grey.shade600; // Màu chữ phụ
  static const Color cardBackgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterProducts);
    _fetchProducts();
    updateCartBadge();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void performSearch(String query) {
    _searchController.text = query;
  }

  Future<void> updateCartBadge() async {
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
    await updateCartBadge();
    widget.onProductAdded();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Đã thêm '$productName' vào giỏ hàng!"),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Sản phẩm",
          style: TextStyle(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [_buildCartIcon()],
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
      padding: const EdgeInsets.only(right: 12.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.shopping_cart_outlined,
                color: Colors.grey.shade700, size: 28),
            onPressed: widget.onCartIconTapped,
          ),
          if (_cartTotalQuantity > 0)
            Positioned(
              right: 6,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  '$_cartTotalQuantity',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm sản phẩm...',
            hintStyle: TextStyle(color: secondaryTextColor),
            prefixIcon:
                Icon(Icons.search, color: secondaryTextColor, size: 22),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryColor));
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(_errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: secondaryTextColor, fontSize: 16)),
      ));
    }
    if (_filteredProducts.isEmpty) {
      return Center(
          child: Text(
              _searchController.text.isNotEmpty
                  ? "Không tìm thấy sản phẩm."
                  : "Chưa có sản phẩm nào.",
              style: TextStyle(color: secondaryTextColor, fontSize: 16)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7, // Tinh chỉnh tỉ lệ thẻ
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final String name = product['name'] ?? 'Chưa có tên';
    final String imageUrl = product['imageUrl'] ?? '';
    final double price = (product['price'] as num?)?.toDouble() ?? 0.0;
    return Container(
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(16.0), // Bo góc mềm mại hơn
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // Bóng đổ tinh tế
            spreadRadius: 1,
            blurRadius: 12,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
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
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: Hero(
                      tag: product['_id'],
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        primaryColor),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.error_outline,
                                      color: secondaryTextColor, size: 40),
                            )
                          : Icon(Icons.image_not_supported,
                              color: secondaryTextColor, size: 40),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600, // Giảm độ đậm một chút
                            fontSize: 14,
                            color: textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '${price.toStringAsFixed(0)} VNĐ',
                              style: const TextStyle(
                                color: primaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold, // Giảm độ đậm
                              ),
                            ),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                onPressed: () => _handleAddToCart(product),
                                icon: const Icon(Icons.add_shopping_cart,
                                    color: Colors.white, size: 18),
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