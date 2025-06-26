// lib/page/admin/product_management_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as M;

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({Key? key}) : super(key: key);

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  // Hàm xử lý cho cả việc Thêm và Sửa sản phẩm
  Future<void> _addOrEditProduct({Map<String, dynamic>? product}) async {
    final bool isEditMode = product != null;
    final nameController =
        TextEditingController(text: isEditMode ? product['name'] : '');
    final priceController = TextEditingController(
        text: isEditMode ? product['price']?.toString() : '');
    final descriptionController =
        TextEditingController(text: isEditMode ? product['description'] : '');
    final imageUrlController =
        TextEditingController(text: isEditMode ? product['imageUrl'] : '');
    final categoryIdController =
        TextEditingController(text: isEditMode ? product['categoryId'] : '');

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEditMode ? 'Chỉnh sửa Sản phẩm' : 'Thêm Sản phẩm mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Tên sản phẩm')),
                const SizedBox(height: 8),
                TextField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Giá'),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Mô tả')),
                const SizedBox(height: 8),
                TextField(
                    controller: imageUrlController,
                    decoration: const InputDecoration(labelText: 'URL Hình ảnh')),
                const SizedBox(height: 8),
                TextField(
                    controller: categoryIdController,
                    decoration: const InputDecoration(labelText: 'Category ID')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      if (nameController.text.isEmpty || priceController.text.isEmpty) {
        if (mounted) {
          ElegantNotification.error(
                  title: const Text('Lỗi'),
                  description: const Text('Vui lòng điền Tên và Giá sản phẩm.'))
              .show(context);
        }
        return;
      }

      final price = double.tryParse(priceController.text);
      if (price == null) {
        if (mounted) {
          ElegantNotification.error(
                  title: const Text('Lỗi'),
                  description: const Text('Giá sản phẩm không hợp lệ.'))
              .show(context);
        }
        return;
      }

      final productData = {
        'name': nameController.text.trim(),
        'price': price,
        'description': descriptionController.text.trim(),
        'imageUrl': imageUrlController.text.trim(),
        'categoryId': categoryIdController.text.trim(),
      };

      if (isEditMode) {
        // Cập nhật sản phẩm đã có
        await MongoDatabase.productCollection.updateOne(
          M.where.id(product['_id']),
          M.modify
            ..set('name', productData['name'])
            ..set('price', productData['price'])
            ..set('description', productData['description'])
            ..set('imageUrl', productData['imageUrl'])
            ..set('categoryId', productData['categoryId']),
        );
      } else {
        // Thêm sản phẩm mới
        await MongoDatabase.productCollection
            .insertOne({'_id': M.ObjectId(), ...productData});
      }

      if (mounted) {
        ElegantNotification.success(
                title: const Text('Thành công'),
                description: Text(isEditMode
                    ? 'Đã cập nhật sản phẩm.'
                    : 'Đã thêm sản phẩm mới.'))
            .show(context);
        setState(() {}); // Tải lại danh sách
      }
    }
  }

  // Hàm để xóa một sản phẩm
  Future<void> _deleteProduct(M.ObjectId productId) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: const Text('Bạn có chắc chắn muốn xóa sản phẩm này không?'),
          actions: <Widget>[
            TextButton(
                child: const Text('Hủy'),
                onPressed: () => Navigator.of(context).pop(false)),
            TextButton(
                child: const Text('Xóa', style: TextStyle(color: Colors.red)),
                onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      await MongoDatabase.productCollection.remove(M.where.id(productId));
      if (mounted) {
        ElegantNotification.success(
          title: const Text("Thành công"),
          description: const Text("Đã xóa sản phẩm thành công."),
        ).show(context);
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Sản phẩm'),
        backgroundColor: Colors.redAccent,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditProduct(),
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add),
        tooltip: 'Thêm Sản phẩm mới',
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: MongoDatabase.productCollection.find().toList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Chưa có sản phẩm nào.'));
          }

          var products = snapshot.data!;

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final imageUrl = product['imageUrl'];
              final price = (product['price'] as num?)?.toDouble() ?? 0.0;

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          height: 50,
                          width: 50,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error, size: 40),
                        )
                      : Container(
                          height: 50,
                          width: 50,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported)),
                  title: Text(product['name'] ?? 'Chưa có tên',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${price.toStringAsFixed(0)} VNĐ'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _addOrEditProduct(product: product),
                        tooltip: 'Chỉnh sửa',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteProduct(product['_id']),
                        tooltip: 'Xóa',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}