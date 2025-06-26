// lib/page/product_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:flutter/material.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({Key? key}) : super(key: key);

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  // Biến để lưu trữ kết quả truy vấn sản phẩm, tương tự _bannersFuture
  late Future<List<Map<String, dynamic>>> _productsFuture;

  @override
  void initState() {
    super.initState();
    // Gọi hàm lấy dữ liệu khi widget được khởi tạo
    _productsFuture = _fetchProducts();
  }

  // Hàm để lấy dữ liệu sản phẩm từ MongoDB, tương tự _fetchBanners
  Future<List<Map<String, dynamic>>> _fetchProducts() async {
    try {
      // Sử dụng productCollection đã định nghĩa trong file mongodb.dart
      final products = await MongoDatabase.productCollection.find().toList();
      return products;
    } catch (e) {
      print("Lỗi khi lấy dữ liệu sản phẩm: $e");
      return [];
    }
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
      // Sử dụng FutureBuilder để xử lý trạng thái bất đồng bộ
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          // Khi đang chờ dữ liệu
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE57373)));
          }

          // Khi có lỗi hoặc không có dữ liệu
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Không thể tải hoặc không có sản phẩm nào."));
          }

          // Khi có dữ liệu thành công
          final products = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(10.0),
            // Cấu hình layout dạng lưới
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,        // 2 sản phẩm trên một hàng
              childAspectRatio: 0.75,     // Tỷ lệ chiều rộng/cao của mỗi item
              crossAxisSpacing: 10,     // Khoảng cách ngang
              mainAxisSpacing: 10,      // Khoảng cách dọc
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductCard(product); // Gọi widget thẻ sản phẩm
            },
          );
        },
      ),
    );
  }

  // Widget để hiển thị một thẻ sản phẩm, giúp code gọn gàng hơn
  Widget _buildProductCard(Map<String, dynamic> product) {
    // Lấy dữ liệu từ map, cung cấp giá trị mặc định nếu null
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
          // Hình ảnh sản phẩm
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
          // Thông tin tên và giá
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