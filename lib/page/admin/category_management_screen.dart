import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as M;

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({Key? key}) : super(key: key);

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {

  // Hàm xử lý cho cả việc Thêm và Sửa danh mục
  Future<void> _addOrEditCategory({Map<String, dynamic>? category}) async {
    final bool isEditMode = category != null;
    final nameController = TextEditingController(text: isEditMode ? category['name'] : '');
    final imageUrlController = TextEditingController(text: isEditMode ? category['imageUrl'] : '');

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEditMode ? 'Chỉnh sửa Danh mục' : 'Thêm Danh mục mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên danh mục')),
                const SizedBox(height: 8),
                TextField(controller: imageUrlController, decoration: const InputDecoration(labelText: 'URL Hình ảnh')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
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
      if (nameController.text.isEmpty || imageUrlController.text.isEmpty) {
        if(mounted) {
          ElegantNotification.error(title: const Text('Lỗi'), description: const Text('Vui lòng điền đầy đủ thông tin.')).show(context);
        }
        return;
      }

      if (isEditMode) {
        // Cập nhật danh mục đã có
        await MongoDatabase.categoryCollection.updateOne(
          M.where.id(category['_id']),
          M.modify
            ..set('name', nameController.text.trim())
            ..set('imageUrl', imageUrlController.text.trim()),
        );
      } else {
        // Thêm danh mục mới
        await MongoDatabase.categoryCollection.insertOne({
          '_id': M.ObjectId(),
          'name': nameController.text.trim(),
          'imageUrl': imageUrlController.text.trim(),
        });
      }

      if (mounted) {
        ElegantNotification.success(
          title: const Text('Thành công'), 
          description: Text(isEditMode ? 'Đã cập nhật danh mục.' : 'Đã thêm danh mục mới.')
        ).show(context);
        setState(() {}); // Tải lại danh sách
      }
    }
  }
  
  // Hàm để xóa một danh mục
  Future<void> _deleteCategory(M.ObjectId categoryId) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: const Text('Bạn có chắc chắn muốn xóa danh mục này không?'),
          actions: <Widget>[
            TextButton(child: const Text('Hủy'), onPressed: () => Navigator.of(context).pop(false)),
            TextButton(child: const Text('Xóa', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      await MongoDatabase.categoryCollection.remove(M.where.id(categoryId));
      if (mounted) {
        ElegantNotification.success(
          title: const Text("Thành công"),
          description: const Text("Đã xóa danh mục thành công."),
        ).show(context);
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Danh mục'),
        backgroundColor: Colors.redAccent,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditCategory(), // Gọi hàm để thêm mới
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add),
        tooltip: 'Thêm Danh mục mới',
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: MongoDatabase.categoryCollection.find().toList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Chưa có danh mục nào.'));
          }

          var categories = snapshot.data!;

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final imageUrl = category['imageUrl'];

              Widget categoryImage;
              if (imageUrl != null && imageUrl.isNotEmpty) {
                categoryImage = Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  height: 50,
                  width: 50,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.error),
                );
              } else {
                categoryImage = const SizedBox(
                    height: 50,
                    width: 50,
                    child: Icon(Icons.image_not_supported));
              }

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: categoryImage,
                  title: Text(category['name'] ?? 'Chưa có tên', style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _addOrEditCategory(category: category), // Gọi hàm để sửa
                        tooltip: 'Chỉnh sửa',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteCategory(category['_id']),
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
