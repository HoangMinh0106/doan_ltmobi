// lib/page/order_history_screen.dart
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:doan_ltmobi/page/customer_order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as M;

class OrderHistoryScreen extends StatefulWidget {
  final M.ObjectId userId;
  final Map<String, dynamic> userDocument;

  const OrderHistoryScreen({super.key, required this.userId, required this.userDocument});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  final Map<String, String> statusMap = const {
    'Pending': 'Đang xử lý',
    'Shipping': 'Đang giao',
    'Delivered': 'Đã giao',
    'Cancelled': 'Đã hủy',
  };

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    _ordersFuture = MongoDatabase.getOrdersByUserId(widget.userId);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Shipping':
        return Colors.blueAccent;
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lịch sử đơn hàng"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ordersFuture,
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
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Bạn chưa có đơn hàng nào.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final orders = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = orders[index];
              final statusKey = order['status'] ?? 'Pending';
              final translatedStatus = statusMap[statusKey] ?? 'Không rõ';

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                  title: Text(
                    'Mã đơn: ${order['_id'].toHexString()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Ngày: ${DateFormat('dd/MM/yyyy').format(order['orderDate'])}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tổng tiền: ${NumberFormat('#,##0').format(order['totalPrice'])} VNĐ',
                      ),
                      const SizedBox(height: 4),
                      Text('Trạng thái: $translatedStatus',
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: _getStatusColor(statusKey))),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CustomerOrderDetailScreen(order: order, userDocument: widget.userDocument),
                      ),
                    ).then((value) {
                        // Tải lại danh sách đơn hàng khi quay về, vì trạng thái đánh giá có thể đã thay đổi
                        if (value == true) { // Chỉ tải lại nếu có sự thay đổi
                           setState(() {
                               _loadOrders();
                           });
                        }
                    });
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