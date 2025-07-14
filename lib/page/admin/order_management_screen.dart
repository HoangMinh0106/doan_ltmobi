// lib/page/admin/order_management_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:doan_ltmobi/page/admin/order_detail_screen.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as m;

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  final Map<String, String> statusMap = {
    'Pending': 'Đang xử lý',
    'Shipping': 'Đang giao',
    'Delivered': 'Đã giao',
    'Cancelled': 'Đã hủy',
    'Awaiting Payment': 'Chờ thanh toán', // Thêm trạng thái mới nếu có
  };

  Future<void> _updateOrderStatus(m.ObjectId orderId, String currentStatus, String newStatus, Map<String, dynamic> order) async {
    if (newStatus == 'Delivered' && currentStatus != 'Delivered') {
      await MongoDatabase.addPointsForOrder(order);
    }

    try {
      await MongoDatabase.orderCollection.update(
        m.where.id(orderId),
        m.modify.set('status', newStatus),
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

  Future<void> _deleteOrder(m.ObjectId orderId) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: const Text('Bạn có chắc chắn muốn xóa vĩnh viễn đơn hàng này không?'),
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
        setState(() {});
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
        future: MongoDatabase.orderCollection.find(m.where.sortBy('orderDate', descending: true)).toList(),
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
              // SỬA LỖI: Kiểm tra nếu trạng thái có hợp lệ không, nếu không thì mặc định là 'Pending'
              String currentStatus = order['status'] ?? 'Pending';
              if (!statusMap.containsKey(currentStatus)) {
                currentStatus = 'Pending';
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ExpansionTile(
                  title: Text('Đơn hàng: #${order['_id'].toHexString().substring(0, 8)}...'),
                  subtitle: Text("Ngày: ${DateFormat('dd/MM/yyyy').format(order['orderDate'])} - Trạng thái: ${statusMap[currentStatus] ?? currentStatus}"),
                  children: <Widget>[
                     Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...?(order['products'] as List?)?.map<Widget>((product) {
                            return ListTile(
                              leading: Image.network(product['imageUrl'] ?? '', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.image_not_supported)),
                              title: Text(product['name'] ?? 'N/A'),
                              subtitle: Text("Số lượng: ${product['quantity']}"),
                            );
                          }).toList(),
                          const Divider(),
                          InkWell(
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
                            child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text("Xem chi tiết đơn hàng...", style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                            ),
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Cập nhật trạng thái:", style: TextStyle(fontWeight: FontWeight.bold)),
                              DropdownButton<String>(
                                value: currentStatus,
                                items: statusMap.keys.map((String key) {
                                  return DropdownMenuItem<String>(
                                    value: key,
                                    child: Text(statusMap[key]!),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null && newValue != currentStatus) {
                                    _updateOrderStatus(order['_id'], currentStatus, newValue, order);
                                  }
                                },
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                tooltip: 'Xóa đơn hàng',
                                onPressed: () => _deleteOrder(order['_id']),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}