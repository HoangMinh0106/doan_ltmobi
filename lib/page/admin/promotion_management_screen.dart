// lib/page/admin/promotion_management_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as M;

class PromotionManagementScreen extends StatefulWidget {
  const PromotionManagementScreen({Key? key}) : super(key: key);

  @override
  State<PromotionManagementScreen> createState() =>
      _PromotionManagementScreenState();
}

class _PromotionManagementScreenState extends State<PromotionManagementScreen> {
  // Hàm xử lý cho cả việc Thêm và Sửa Ưu đãi
  Future<void> _addOrEditPromotion({Map<String, dynamic>? promotion}) async {
    final bool isEditMode = promotion != null;
    final titleController =
        TextEditingController(text: isEditMode ? promotion['title'] : '');
    final contentController =
        TextEditingController(text: isEditMode ? promotion['content'] : '');
    final imageUrlController =
        TextEditingController(text: isEditMode ? promotion['imageUrl'] : '');

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEditMode ? 'Chỉnh sửa Ưu đãi' : 'Thêm Ưu đãi mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Tiêu đề ưu đãi')),
                const SizedBox(height: 8),
                TextField(
                    controller: contentController,
                    maxLines: 4, // Cho phép nhập nhiều dòng
                    decoration: const InputDecoration(labelText: 'Nội dung chi tiết')),
                const SizedBox(height: 8),
                TextField(
                    controller: imageUrlController,
                    decoration: const InputDecoration(labelText: 'URL Hình ảnh')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      if (titleController.text.isEmpty || imageUrlController.text.isEmpty) {
        if (mounted) {
          ElegantNotification.error(
                  title: const Text('Lỗi'),
                  description: const Text('Vui lòng điền Tiêu đề và URL Hình ảnh.'))
              .show(context);
        }
        return;
      }

      final promotionData = {
        'title': titleController.text.trim(),
        'content': contentController.text.trim(),
        'imageUrl': imageUrlController.text.trim(),
      };

      if (isEditMode) {
        // Cập nhật ưu đãi đã có
        await MongoDatabase.bannerCollection.updateOne(
          M.where.id(promotion['_id']),
          M.modify
            ..set('title', promotionData['title'])
            ..set('content', promotionData['content'])
            ..set('imageUrl', promotionData['imageUrl']),
        );
      } else {
        // Thêm ưu đãi mới
        await MongoDatabase.bannerCollection
            .insertOne({'_id': M.ObjectId(), ...promotionData});
      }

      if (mounted) {
        ElegantNotification.success(
                title: const Text('Thành công'),
                description: Text(isEditMode
                    ? 'Đã cập nhật ưu đãi.'
                    : 'Đã thêm ưu đãi mới.'))
            .show(context);
        setState(() {}); // Tải lại danh sách
      }
    }
  }

  // Hàm để xóa một ưu đãi
  Future<void> _deletePromotion(M.ObjectId promotionId) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: const Text('Bạn có chắc chắn muốn xóa ưu đãi này không?'),
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
      await MongoDatabase.bannerCollection.remove(M.where.id(promotionId));
      if (mounted) {
        ElegantNotification.success(
          title: const Text("Thành công"),
          description: const Text("Đã xóa ưu đãi thành công."),
        ).show(context);
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Ưu đãi'),
        backgroundColor: Colors.teal,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditPromotion(),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
        tooltip: 'Thêm Ưu đãi mới',
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // Sử dụng bannerCollection
        future: MongoDatabase.bannerCollection.find().toList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Chưa có ưu đãi nào.'));
          }

          var promotions = snapshot.data!;

          return ListView.builder(
            itemCount: promotions.length,
            itemBuilder: (context, index) {
              final promo = promotions[index];
              final imageUrl = promo['imageUrl'];
              final content = promo['content'] ?? 'Chưa có nội dung.';

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
                  title: Text(promo['title'] ?? 'Chưa có tiêu đề',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _addOrEditPromotion(promotion: promo),
                        tooltip: 'Chỉnh sửa',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deletePromotion(promo['_id']),
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