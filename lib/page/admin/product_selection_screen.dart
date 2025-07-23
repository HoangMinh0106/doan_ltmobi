// lib/page/admin/product_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:intl/intl.dart';

class ProductSelectionScreen extends StatefulWidget {
  // Nhận vào một Map chứa ID và giá sale ban đầu
  final Map<mongo.ObjectId, double> initialSelections;

  const ProductSelectionScreen({
    super.key,
    required this.initialSelections,
  });

  @override
  _ProductSelectionScreenState createState() => _ProductSelectionScreenState();
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  // Sử dụng Map để lưu cả ID và giá sale
  late Map<mongo.ObjectId, double> _selectedProducts; 
  final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _productsFuture = MongoDatabase.productCollection.find().toList();
    _selectedProducts = Map.from(widget.initialSelections);
  }

  void _onProductSelected(bool? selected, Map<String, dynamic> product) {
    final productId = product['_id'] as mongo.ObjectId;
    setState(() {
      if (selected == true) {
        // Khi chọn, mặc định giá sale bằng giá gốc
        _selectedProducts[productId] = (product['price'] as num).toDouble();
      } else {
        _selectedProducts.remove(productId);
      }
    });
  }

  void _updateSalePrice(mongo.ObjectId productId, String value) {
    final price = double.tryParse(value);
    if (price != null) {
      setState(() {
        _selectedProducts[productId] = price;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chọn sản phẩm (${_selectedProducts.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, _selectedProducts);
            },
          )
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Không có sản phẩm nào.'));
          }

          final products = snapshot.data!;

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final productId = product['_id'] as mongo.ObjectId;
              final isSelected = _selectedProducts.containsKey(productId);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: isSelected,
                      onChanged: (bool? selected) => _onProductSelected(selected, product),
                      secondary: Image.network(
                        product['imageUrl'] ?? 'https://via.placeholder.com/150',
                        width: 50, height: 50, fit: BoxFit.cover,
                      ),
                      title: Text(product['name'] ?? 'N/A'),
                      subtitle: Text("Giá gốc: ${currencyFormatter.format(product['price'] ?? 0)}"),
                      activeColor: Theme.of(context).primaryColor,
                    ),
                    // Hiển thị ô nhập giá sale nếu sản phẩm được chọn
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: TextFormField(
                          initialValue: _selectedProducts[productId]?.toStringAsFixed(0) ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Nhập giá Flash Sale (VNĐ)',
                            prefixIcon: Icon(Icons.sell_outlined),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _updateSalePrice(productId, value),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pop(context, _selectedProducts);
        },
        label: const Text('Xác nhận'),
        icon: const Icon(Icons.check),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
}