// lib/page/promotion_detail_screen.dart

import 'package:flutter/material.dart';

class PromotionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> promotion;

  const PromotionDetailScreen({super.key, required this.promotion});

  static const Color primaryColor = Color(0xFFE57373);

  @override
  Widget build(BuildContext context) {
    final String title = promotion['title'] ?? 'Chi tiết khuyến mãi';
    final String imageUrl = promotion['imageUrl'] ?? '';
    final String content = promotion['content'] ?? 'Nội dung chi tiết chưa được cập nhật.';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 250,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 60),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  const Text(
                    'Nội dung chương trình',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}