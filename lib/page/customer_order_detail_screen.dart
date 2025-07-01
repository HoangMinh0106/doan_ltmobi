// lib/page/customer_order_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomerOrderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const CustomerOrderDetailScreen({Key? key, required this.order}) : super(key: key);

  // Map để dịch trạng thái từ tiếng Anh sang tiếng Việt
  final Map<String, String> statusMap = const {
    'Pending': 'Đang xử lý',
    'Shipping': 'Đang giao',
    'Delivered': 'Đã giao',
    'Cancelled': 'Đã hủy',
  };

  @override
  Widget build(BuildContext context) {
    final orderDate = order['orderDate'] as DateTime;
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(orderDate);
    final currentStatusKey = order['status'] ?? 'Pending';
    final translatedStatus = statusMap[currentStatusKey] ?? 'Không rõ';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
        backgroundColor: const Color(0xFFE57373),
        foregroundColor: Colors.white,
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
                _buildInfoRow('Mã đơn hàng:', order['_id'].toHexString()),
                _buildInfoRow('Ngày đặt:', formattedDate),
                _buildInfoRow('Địa chỉ giao hàng:', order['shippingAddress'] ?? 'Không rõ'),
                _buildInfoRow('Trạng thái:', translatedStatus, isStatus: true),
                _buildInfoRow(
                  'Tổng tiền:',
                  '${NumberFormat('#,##0').format(order['totalPrice'])} VNĐ',
                  isHighlighted: true,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Danh sách sản phẩm ---
            _buildSectionCard(
              title: 'Danh sách sản phẩm',
              children: [
                ...?order['products']?.map<Widget>((product) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Image.network(
                      product['imageUrl'] ?? '',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 50),
                    ),
                    title: Text(product['name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Số lượng: ${product['quantity']}'),
                    trailing: Text('${NumberFormat('#,##0').format(product['price'])} VNĐ'),
                  );
                }).toList(),
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE57373)),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlighted = false, bool isStatus = false}) {
    Color statusColor;
    switch (value) {
      case 'Đang giao':
        statusColor = Colors.blueAccent;
        break;
      case 'Đã giao':
        statusColor = Colors.green;
        break;
      case 'Đã hủy':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orangeAccent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isHighlighted || isStatus ? FontWeight.bold : FontWeight.normal,
                fontSize: isHighlighted ? 17 : 15,
                color: isHighlighted ? Colors.redAccent : (isStatus ? statusColor : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}