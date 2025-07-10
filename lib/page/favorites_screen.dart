// lib/page/favorites_screen.dart

import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:intl/intl.dart';

class FavoritesScreen extends StatefulWidget {
  final Map<String, dynamic> userDocument;

  const FavoritesScreen({super.key, required this.userDocument});

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<Map<String, dynamic>>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _loadFavorites() {
    setState(() {
      _favoritesFuture = MongoDatabase.getFavoriteProducts(widget.userDocument['_id']);
    });
  }

  void _removeFromFavorites(mongo.ObjectId productId) async {
    await MongoDatabase.removeFromFavorites(widget.userDocument['_id'], productId);
    _loadFavorites(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sản phẩm yêu thích'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _favoritesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Chưa có sản phẩm yêu thích',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final favoriteProducts = snapshot.data!;

          return ListView.builder(
            itemCount: favoriteProducts.length,
            itemBuilder: (context, index) {
              final product = favoriteProducts[index];
              return _buildFavoriteItem(product);
            },
          );
        },
      ),
    );
  }

  Widget _buildFavoriteItem(Map<String, dynamic> product) {
    final String name = product['name'] ?? 'N/A';
    final double price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final String imageUrl = product['imageUrl'] ?? '';
    final productId = product['_id'] as mongo.ObjectId;
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis,),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormatter.format(price),
                    style: TextStyle(fontSize: 16, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.favorite, color: Colors.redAccent),
              onPressed: () => _removeFromFavorites(productId),
              tooltip: 'Xóa khỏi yêu thích',
            ),
          ],
        ),
      ),
    );
  }
}