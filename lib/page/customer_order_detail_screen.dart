import 'package:doan_ltmobi/page/add_review_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

// Chuyển thành StatefulWidget để quản lý trạng thái
class CustomerOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic> userDocument;

  const CustomerOrderDetailScreen({super.key, required this.order, required this.userDocument});

  @override
  State<CustomerOrderDetailScreen> createState() => _CustomerOrderDetailScreenState();
}

class _CustomerOrderDetailScreenState extends State<CustomerOrderDetailScreen> {
  late Map<String, dynamic> _currentOrder;
  bool _madeChanges = false; // Cờ để báo hiệu có thay đổi không

  final Map<String, String> statusMap = const {
    'Pending': 'Đang xử lý',
    'Shipping': 'Đang giao',
    'Delivered': 'Đã giao',
    'Cancelled': 'Đã hủy',
  };

  @override
  void initState() {
    super.initState();
    _currentOrder = Map<String, dynamic>.from(widget.order);
  }

  @override
  Widget build(BuildContext context) {
    final orderDate = _currentOrder['orderDate'] as DateTime;
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(orderDate);
    final currentStatusKey = _currentOrder['status'] ?? 'Pending';
    final translatedStatus = statusMap[currentStatusKey] ?? 'Không rõ';

    return WillPopScope(
      onWillPop: () async {
        // Trả về cờ _madeChanges khi người dùng bấm nút back
        Navigator.pop(context, _madeChanges);
        return true;
      },
      child: Scaffold(
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
                  _buildInfoRow('Mã đơn hàng:', _currentOrder['_id'].toHexString()),
                  _buildInfoRow('Ngày đặt:', formattedDate),
                  _buildInfoRow('Địa chỉ giao hàng:', _currentOrder['shippingAddress'] ?? 'Không rõ'),
                  _buildInfoRow('Trạng thái:', translatedStatus, isStatus: true),
                  _buildInfoRow(
                    'Tổng tiền:',
                    '${NumberFormat('#,##0').format(_currentOrder['totalPrice'])} VNĐ',
                    isHighlighted: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Danh sách sản phẩm ---
              _buildSectionCard(
                title: 'Danh sách sản phẩm',
                children: [
                  ...(_currentOrder['products'] as List).map<Widget>((product) {
                    final bool canReview = (_currentOrder['status'] == 'Delivered' && product['reviewed'] != true);
                    
                    // **SỬA LỖI**: Lấy URL và kiểm tra trước khi hiển thị
                    final imageUrl = product['imageUrl'] as String?;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: (imageUrl != null && imageUrl.isNotEmpty)
                          ? Image.network(
                              imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 50),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                            ),
                      title: Text(product['name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Số lượng: ${product['quantity']}'),
                          const SizedBox(height: 8),
                          if (canReview)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.rate_review_outlined, size: 16),
                              label: const Text('Đánh giá'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                textStyle: const TextStyle(fontSize: 12),
                                backgroundColor: Colors.amber.shade700,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                final success = await showDialog<bool>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => AddReviewDialog(
                                    userDocument: widget.userDocument,
                                    product: product,
                                    orderId: _currentOrder['_id'],
                                  ),
                                );
                                if (success == true) {
                                  setState(() {
                                    product['reviewed'] = true;
                                    _madeChanges = true;
                                  });
                                }
                              },
                            )
                          else if (product['reviewed'] == true)
                            const Text('✓ Đã đánh giá', style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic))
                        ],
                      ),
                      trailing: Text('${NumberFormat('#,##0').format(product['price'])} VNĐ'),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
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