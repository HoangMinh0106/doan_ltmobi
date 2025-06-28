// lib/page/admin/order_detail_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as M;

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({Key? key, required this.order}) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<Map<String, dynamic>?> _userFuture;
  late String _currentStatus;

  final Map<String, String> statusMap = {
    'Pending': 'Đang xử lý',
    'Shipping': 'Đang giao',
    'Delivered': 'Đã giao',
    'Cancelled': 'Đã hủy',
  };

  @override
  void initState() {
    super.initState();
    _userFuture = _fetchUserDetails();
    _currentStatus = widget.order['status'] ?? 'Pending';
    if (!statusMap.containsKey(_currentStatus)) {
      _currentStatus = 'Pending';
    }
  }

  Future<Map<String, dynamic>?> _fetchUserDetails() async {
    final userId = widget.order['userId'] as M.ObjectId;
    return await MongoDatabase.userCollection.findOne(M.where.id(userId));
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    try {
      await MongoDatabase.orderCollection.update(
        M.where.id(widget.order['_id']),
        M.modify.set('status', newStatus),
      );
      if (mounted) {
        ElegantNotification.success(
          title: const Text("Thành công"),
          description: const Text("Đã cập nhật trạng thái đơn hàng."),
        ).show(context);
        setState(() {
          _currentStatus = newStatus;
        });
      }
    } catch (e) {
      if (mounted) {
        ElegantNotification.error(
          title: const Text("Lỗi"),
          description: Text("Không thể cập nhật trạng thái: $e"),
        ).show(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderDate = widget.order['orderDate'] as DateTime;
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(orderDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
        backgroundColor: Colors.redAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Thông tin chung ---
            _buildSectionCard(
              title: 'Thông tin đơn hàng',
              children: [
                _buildInfoRow('Mã đơn hàng:', widget.order['_id'].toHexString()),
                _buildInfoRow('Ngày đặt:', formattedDate),
                _buildInfoRow(
                  'Tổng tiền:',
                  '${NumberFormat('#,##0').format(widget.order['totalPrice'])} VNĐ',
                  isHighlighted: true,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Thông tin khách hàng (bao gồm địa chỉ) ---
            FutureBuilder<Map<String, dynamic>?>(
              future: _userFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final user = snapshot.data;
                return _buildSectionCard(
                  title: 'Thông tin khách hàng',
                  children: [
                    _buildInfoRow('Tên khách hàng:', user?['email']?.split('@').first ?? 'Không rõ'),
                    _buildInfoRow('Email:', user?['email'] ?? 'Không rõ'),
                    _buildInfoRow('Số điện thoại:', user?['phone'] ?? 'Không rõ'),
                    _buildInfoRow('Địa chỉ giao hàng:', widget.order['shippingAddress'] ?? 'Không rõ'),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            
            // --- Danh sách sản phẩm ---
            _buildSectionCard(
              title: 'Danh sách sản phẩm',
              children: [
                ...?widget.order['products']?.map<Widget>((product) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Image.network(
                      product['imageUrl'] ?? '',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                    ),
                    title: Text(product['name'] ?? 'N/A'),
                    subtitle: Text('Số lượng: ${product['quantity']}'),
                    trailing: Text('${NumberFormat('#,##0').format(product['price'])} VNĐ'),
                  );
                }).toList(),
              ],
            ),
            const SizedBox(height: 16),

            // --- Cập nhật trạng thái ---
            _buildSectionCard(
              title: 'Trạng thái đơn hàng',
              children: [
                DropdownButtonFormField<String>(
                  value: _currentStatus,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: statusMap.keys.map((String key) {
                      return DropdownMenuItem<String>(
                        value: key,
                        child: Text(statusMap[key]!),
                      );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null && newValue != _currentStatus) {
                      _updateOrderStatus(newValue);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                fontSize: isHighlighted ? 16 : 14,
                color: isHighlighted ? Colors.redAccent : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}