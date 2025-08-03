// lib/widgets/flash_sale_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_timer_countdown/flutter_timer_countdown.dart';
import 'package:intl/intl.dart';
import 'package:doan_ltmobi/page/product_detail_screen.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class FlashSaleBanner extends StatelessWidget {
  final DateTime endTime;
  final List<Map<String, dynamic>> products;
  final Map<String, dynamic> userDocument;
  final VoidCallback onProductAdded;
  final String selectedAddress;
  final List<mongo.ObjectId> favoriteProductIds;
  final Function(mongo.ObjectId) onFavoriteToggle;

  const FlashSaleBanner({
    super.key,
    required this.endTime,
    required this.products,
    required this.userDocument,
    required this.onProductAdded,
    required this.selectedAddress,
    required this.favoriteProductIds,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.0),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF06292), // Hồng đậm
            Color(0xFFD81B60), // Hồng rực rỡ
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Giờ Vàng Sốc',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              TimerCountdown(
                endTime: endTime,
                onEnd: () {},
                timeTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, backgroundColor: Colors.black26),
                colonsTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                descriptionTextStyle: const TextStyle(color: Colors.white70, fontSize: 10),
                daysDescription: "ngày",
                hoursDescription: "giờ",
                minutesDescription: "phút",
                secondsDescription: "giây",
              ),
            ],
          ),
          const SizedBox(height: 12),
          products.isEmpty
              ? const Center(heightFactor: 3, child: Text("Chưa có sản phẩm nào cho đợt sale này.", style: TextStyle(color: Colors.white70)))
              : SizedBox(
                  height: 190,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: products.length,
                    itemBuilder: (context, index) => _buildFlashSaleProductCard(context, products[index]),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildFlashSaleProductCard(BuildContext context, Map<String, dynamic> product) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final double originalPrice = (product['price'] as num?)?.toDouble() ?? 0.0;
    final double salePrice = (product['salePrice'] as num?)?.toDouble() ?? originalPrice;
    final int discountPercent = originalPrice > 0 ? ((originalPrice - salePrice) / originalPrice * 100).round() : 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(
          product: product,
          userDocument: userDocument,
          onProductAdded: onProductAdded,
          selectedAddress: selectedAddress,
          isFavorite: favoriteProductIds.contains(product['_id']),
          onFavoriteToggle: () => onFavoriteToggle(product['_id']),
          salePrice: salePrice,
        )));
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Image.network(
                    product['imageUrl'] ?? 'https://via.placeholder.com/150',
                    height: 110, width: 120, fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey.shade300, height: 110, width: 120, child: const Icon(Icons.error, color: Colors.white)),
                  ),
                ),
                if (discountPercent > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.yellow.shade700, borderRadius: BorderRadius.circular(5)),
                      child: Text('-$discountPercent%', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(product['name'] ?? 'Tên sản phẩm', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            // --- THAY ĐỔI: Đổi màu giá sale thành vàng rực rỡ ---
            Text(currencyFormatter.format(salePrice), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.yellow)),
            if(salePrice < originalPrice)
              Text(currencyFormatter.format(originalPrice), style: const TextStyle(fontSize: 11, color: Colors.white70, decoration: TextDecoration.lineThrough)),
          ],
        ),
      ),
    );
  }
}