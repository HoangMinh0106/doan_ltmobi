// lib/page/product_detail_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class ProductDetailScreen extends StatelessWidget {
  final Map<String, dynamic> product;
  final Map<String, dynamic> userDocument;
  final VoidCallback onProductAdded;

  const ProductDetailScreen({
    Key? key,
    required this.product,
    required this.userDocument,
    required this.onProductAdded,
  }) : super(key: key);

  static const Color primaryColor = Color(0xFFE57373);
  static const Color secondaryTextColor = Colors.grey;

  void _handleAddToCart(BuildContext context) async {
    final userId = userDocument['_id'] as mongo.ObjectId;
    final productName = product['name'] ?? 'Sản phẩm';
    await MongoDatabase.addToCart(userId, product);
    onProductAdded();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Đã thêm '$productName' vào giỏ hàng!"),
        backgroundColor: primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dòng print() để kiểm tra dữ liệu đã được truyền qua đúng chưa
    print("Dữ liệu sản phẩm nhận được tại ProductDetailScreen: $product");

    final String name = product['name'] ?? 'Chưa có tên';
    final String imageUrl = product['imageUrl'] ?? '';
    final double price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final String description = product['description'] ?? 'Sản phẩm chưa có mô tả chi tiết.';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: product['_id'],
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 300,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 300,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image_not_supported, color: secondaryTextColor, size: 60),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('${price.toStringAsFixed(0)} VNĐ', style: const TextStyle(color: primaryColor, fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 24),
                  const Text('Mô tả sản phẩm', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(description, style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15).copyWith(
          bottom: MediaQuery.of(context).padding.bottom + 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 3, blurRadius: 10)
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () => _handleAddToCart(context),
          icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
          label: const Text('Thêm vào giỏ hàng', style: TextStyle(color: Colors.white, fontSize: 18)),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}