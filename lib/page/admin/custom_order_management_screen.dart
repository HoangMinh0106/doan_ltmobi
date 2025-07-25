// lib/page/admin/custom_order_management_screen.dart

import 'package:flutter/material.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as m;
import 'custom_order_detail_screen.dart'; // File này cũng cần được tạo

class CustomOrderManagementScreen extends StatefulWidget {
  const CustomOrderManagementScreen({super.key});

  @override
  _CustomOrderManagementScreenState createState() => _CustomOrderManagementScreenState();
}

class _CustomOrderManagementScreenState extends State<CustomOrderManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Đặt bánh tùy chỉnh'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: MongoDatabase.customOrderCollection.find(m.where.sortBy('requestDate', descending: true)).toList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Chưa có yêu cầu đặt bánh nào.'));
          }

          var orders = snapshot.data!;

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              var order = orders[index];
              String status = order['status'] ?? 'Không rõ';
              Color statusColor;
              switch (status) {
                case 'Mới':
                  statusColor = Colors.blue;
                  break;
                case 'Đã báo giá':
                  statusColor = Colors.orange;
                  break;
                case 'Đã xác nhận':
                  statusColor = Colors.green;
                  break;
                case 'Đã hủy':
                  statusColor = Colors.red;
                  break;
                default:
                  statusColor = Colors.grey;
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text('Yêu cầu từ: ${order['contactName']}'),
                  subtitle: Text('Ngày yêu cầu: ${DateFormat('dd/MM/yyyy HH:mm').format(order['requestDate'].toLocal())}'),
                  trailing: Chip(
                    label: Text(status, style: const TextStyle(color: Colors.white)),
                    backgroundColor: statusColor,
                  ),
                  onTap: () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CustomOrderDetailScreen(order: order),
                      ),
                    ).then((_) => setState(() {})); // Tải lại trang khi quay về
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}