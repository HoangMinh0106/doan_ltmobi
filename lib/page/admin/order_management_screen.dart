// lib/page/admin/order_management_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as M;
import 'order_detail_screen.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({Key? key}) : super(key: key);

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  final Map<String, String> statusMap = {
    'Pending': 'Đang xử lý',
    'Shipping': 'Đang giao',
    'Delivered': 'Đã giao',
    'Cancelled': 'Đã hủy',
  };

  Future<void> _updateOrderStatus(M.ObjectId orderId, String newStatus) async {
    try {
      await MongoDatabase.orderCollection.update(
        M.where.id(orderId),
        M.modify.set('status', newStatus),
      );
      if (mounted) {
        ElegantNotification.success(
          title: const Text("Thành công"),
          description: const Text("Đã cập nhật trạng thái đơn hàng."),
        ).show(context);
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ElegantNotification.error(
          title: const Text("Lỗi"),
          description: Text("Không thể cập nhật trạng thái: $e"),
        ).show(context);
      }
    }
  }

  // --- THÊM MỚI HÀM NÀY ---
  /// Xử lý việc xóa một đơn hàng sau khi có xác nhận.
  Future<void> _deleteOrder(M.ObjectId orderId) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: const Text('Bạn có chắc chắn muốn xóa vĩnh viễn đơn hàng này không? Hành động này không thể hoàn tác.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await MongoDatabase.deleteOrder(orderId);
        if (mounted) {
          ElegantNotification.success(
            title: const Text("Thành công"),
            description: const Text("Đã xóa đơn hàng thành công."),
          ).show(context);
        }
        setState(() {}); // Tải lại danh sách sau khi xóa
      } catch (e) {
        if (mounted) {
          ElegantNotification.error(
            title: const Text("Lỗi"),
            description: Text("Không thể xóa đơn hàng: $e"),
          ).show(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Đơn hàng'),
        backgroundColor: Colors.redAccent,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: MongoDatabase.orderCollection.find(M.where.sortBy('orderDate', descending: true)).toList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Chưa có đơn hàng nào.'));
          }

          var orders = snapshot.data!;

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final orderDate = order['orderDate'] as DateTime;
              final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(orderDate);
              
              String currentStatus = order['status'] ?? 'Pending';
              if (!statusMap.containsKey(currentStatus)) {
                currentStatus = 'Pending';
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrderDetailScreen(order: order),
                              ),
                            ).then((_) {
                              setState(() {});
                            });
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mã đơn: ${order['_id'].toHexString()}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ngày đặt: $formattedDate\nTổng tiền: ${NumberFormat('#,##0').format(order['totalPrice'])} VNĐ',
                              ),
                            ],
                          ),
                        ),
                      ),
                      // --- THAY ĐỔI GIAO DIỆN Ở ĐÂY ---
                      SizedBox(
                        width: 150,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Dropdown để đổi trạng thái
                            DropdownButton<String>(
                              value: currentStatus,
                              items: statusMap.keys.map((String key) {
                                return DropdownMenuItem<String>(
                                  value: key,
                                  child: Text(statusMap[key]!, style: const TextStyle(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  _updateOrderStatus(order['_id'], newValue);
                                }
                              },
                              underline: const SizedBox(),
                            ),
                            // Nút để xóa đơn hàng
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey),
                              tooltip: 'Xóa đơn hàng',
                              onPressed: () => _deleteOrder(order['_id']),
                            ),
                          ],
                        ),
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