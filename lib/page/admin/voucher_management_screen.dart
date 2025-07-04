// lib/page/admin/voucher_management_screen.dart
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo; // Sửa prefix

class VoucherManagementScreen extends StatefulWidget {
  // Sửa constructor
  const VoucherManagementScreen({super.key});

  @override
  State<VoucherManagementScreen> createState() =>
      _VoucherManagementScreenState();
}

class _VoucherManagementScreenState extends State<VoucherManagementScreen> {
  final NumberFormat currencyFormatter = NumberFormat('#,##0', 'vi_VN');

  // Hàm để Thêm hoặc Sửa voucher
  Future<void> _addOrEditVoucher({Map<String, dynamic>? voucher}) async {
    final bool isEditMode = voucher != null;
    // Bỏ các dấu '!' không cần thiết
    final codeController =
        TextEditingController(text: isEditMode ? voucher['code'] : '');
    final discountValueController = TextEditingController(
        text: isEditMode ? voucher['discountValue']?.toString() : '');
    String discountType =
        isEditMode ? (voucher['discountType'] ?? 'fixed') : 'fixed';
    final minPurchaseController = TextEditingController(
        text: isEditMode ? voucher['minPurchase']?.toString() : '0');

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditMode ? 'Chỉnh sửa Voucher' : 'Thêm Voucher'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: codeController,
                        decoration: const InputDecoration(labelText: 'Mã Voucher')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: discountValueController,
                        decoration:
                            const InputDecoration(labelText: 'Giá trị giảm'),
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: discountType,
                      decoration:
                          const InputDecoration(labelText: 'Loại giảm giá'),
                      items: const [
                        DropdownMenuItem(value: 'fixed', child: Text('Số tiền cố định (VNĐ)')),
                        DropdownMenuItem(value: 'percent', child: Text('Phần trăm (%)')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            discountType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                        controller: minPurchaseController,
                        decoration: const InputDecoration(
                            labelText: 'Giá trị đơn hàng tối thiểu'),
                        keyboardType: TextInputType.number),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Hủy')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    if (codeController.text.isEmpty ||
        discountValueController.text.isEmpty) {
      // Đã có kiểm tra `mounted` sẵn từ bản chất của `showDialog`
      ElegantNotification.error(
              title: const Text('Lỗi'),
              description: const Text('Vui lòng điền Mã và Giá trị giảm.'))
          .show(context);
      return;
    }

    final voucherData = {
      'code': codeController.text.trim().toUpperCase(),
      'discountValue': double.tryParse(discountValueController.text) ?? 0,
      'discountType': discountType,
      'minPurchase': double.tryParse(minPurchaseController.text) ?? 0,
      'isActive': true,
    };

    try {
      if (isEditMode) {
        await MongoDatabase.voucherCollection.updateOne(
          mongo.where.id(voucher['_id']), // Sửa prefix
          {'\$set': voucherData},
        );
      } else {
        await MongoDatabase.voucherCollection.insertOne(voucherData);
      }

      if (mounted) {
        ElegantNotification.success(
                title: const Text('Thành công'),
                description: Text(isEditMode ? 'Đã cập nhật voucher.' : 'Đã thêm voucher mới.'))
            .show(context);
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ElegantNotification.error(
                title: const Text('Lỗi'),
                description: Text('Thao tác thất bại: $e'))
            .show(context);
      }
    }
  }

  // Hàm để xóa voucher
  Future<void> _deleteVoucher(mongo.ObjectId voucherId) async { // Sửa prefix
    final bool? confirmDelete = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              title: const Text('Xác nhận xóa'),
              content: const Text('Bạn có chắc chắn muốn xóa voucher này không?'),
              actions: [
                TextButton(child: const Text('Hủy'), onPressed: () => Navigator.of(context).pop(false)),
                TextButton(child: const Text('Xóa', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(context).pop(true)),
              ],
            ));

    if (confirmDelete == true) {
      await MongoDatabase.voucherCollection.remove(mongo.where.id(voucherId)); // Sửa prefix
      if (mounted) {
        ElegantNotification.success(
          title: const Text("Thành công"),
          description: const Text("Đã xóa voucher thành công."),
        ).show(context);
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Voucher'),
        backgroundColor: Colors.deepPurple,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditVoucher(),
        backgroundColor: Colors.deepPurple,
        tooltip: 'Thêm Voucher mới',
        child: const Icon(Icons.add), // Sắp xếp lại child
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: MongoDatabase.voucherCollection.find().toList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Chưa có voucher nào.'));
          }

          var vouchers = snapshot.data!;

          return ListView.builder(
            itemCount: vouchers.length,
            itemBuilder: (context, index) {
              final voucher = vouchers[index];
              final discountType = voucher['discountType'] == 'percent' ? '%' : 'VNĐ';
              final discountValue = voucher['discountValue'];
              final formattedValue = discountType == '%'
                  ? discountValue.toString()
                  : currencyFormatter.format(discountValue);

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.local_offer, color: Colors.deepPurple),
                  title: Text(voucher['code'] ?? 'Không có mã',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Giảm: $formattedValue $discountType - Tối thiểu: ${currencyFormatter.format(voucher['minPurchase'] ?? 0)} VNĐ'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _addOrEditVoucher(voucher: voucher),
                        tooltip: 'Chỉnh sửa',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteVoucher(voucher['_id']),
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