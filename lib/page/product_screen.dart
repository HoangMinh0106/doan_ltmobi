// lib/page/product_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:flutter/material.dart';
import 'dart:async'; // Import a async

class ProductScreen extends StatefulWidget {
  const ProductScreen({Key? key}) : super(key: key);

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  // Controller cho thanh tìm kiếm
  final TextEditingController _searchController = TextEditingController();

  // Danh sách lưu tất cả sản phẩm từ DB
  List<Map<String, dynamic>> _allProducts = [];

  // Danh sách hiển thị sản phẩm sau khi lọc
  List<Map<String, dynamic>> _filteredProducts = [];

  // Trạng thái tải dữ liệu
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Lắng nghe sự thay đổi trong thanh tìm kiếm
    _searchController.addListener(_filterProducts);
    // Tải dữ liệu sản phẩm khi widget được khởi tạo
    _fetchProducts();
  }

  @override
  void dispose() {
    // Hủy controller khi widget bị hủy để tránh rò rỉ bộ nhớ
    _searchController.dispose();
    super.dispose();
  }

  // Hàm để lấy dữ liệu sản phẩm từ MongoDB
  Future<void> _fetchProducts() async {
    try {
      final products = await MongoDatabase.productCollection.find().toList();
      setState(() {
        _allProducts = products;
        _filteredProducts = products; // Ban đầu, hiển thị tất cả sản phẩm
        _isLoading = false;
      });
    } catch (e) {
      print("Lỗi khi lấy dữ liệu sản phẩm: $e");
      setState(() {
        _errorMessage = "Không thể tải dữ liệu sản phẩm. Vui lòng thử lại.";
        _isLoading = false;
      });
    }
  }

  // Hàm để lọc sản phẩm dựa trên từ khóa tìm kiếm
  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final productName = (product['name'] as String? ?? '').toLowerCase();
        return productName.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Sản phẩm",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey.withOpacity(0.2),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm sản phẩm...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: const BorderSide(color: Color(0xFFE57373)),
                ),
              ),
            ),
          ),
          // Nội dung chính
          Expanded(
            child: _buildBodyContent(),
          ),
        ],
      ),
    );
  }

  // Widget để hiển thị nội dung chính (loading, error, grid view)
  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE57373)));
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage));
    }

    if (_filteredProducts.isEmpty) {
      return const Center(child: Text("Không tìm thấy sản phẩm nào."));
    }

    // Lưới hiển thị sản phẩm đã lọc
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10.0, 0, 10.0, 10.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return _buildProductCard(product);
      },
    );
  }

  // Widget để hiển thị một thẻ sản phẩm
  Widget _buildProductCard(Map<String, dynamic> product) {
    final String name = product['name'] ?? 'Chưa có tên';
    final String imageUrl = product['imageUrl'] ?? '';
    final double price = (product['price'] as num?)?.toDouble() ?? 0.0;

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  )
                : Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${price.toStringAsFixed(0)} VNĐ',
                  style: const TextStyle(color: Color(0xFFE57373), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
