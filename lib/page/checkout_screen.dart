// lib/page/checkout_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'vnpay_service.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class CheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> userDocument;
  final List<Map<String, dynamic>> cartItems;
  final double totalPrice;
  final VoidCallback onOrderPlaced;
  final String shippingAddress;

  const CheckoutScreen({
    Key? key,
    required this.userDocument,
    required this.cartItems,
    required this.totalPrice,
    required this.onOrderPlaced,
    required this.shippingAddress,
  }) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isProcessing = false;
  String _paymentMethod = 'cod';

  static const Color primaryColor = Color(0xFFE57373);
  static const Color secondaryTextColor = Colors.grey;

  Future<void> _placeOrderCOD(BuildContext context) async {
    setState(() { _isProcessing = true; });
    try {
      final userId = widget.userDocument['_id'] as mongo.ObjectId;
      // THAY ĐỔI: Truyền thêm `widget.shippingAddress` vào hàm
      await MongoDatabase.createOrder(userId, widget.cartItems, widget.totalPrice, widget.shippingAddress);
      
      await MongoDatabase.clearCart(userId);
      widget.onOrderPlaced();
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('Đặt hàng thành công!'),
            content: const Text('Cảm ơn bạn đã tin tưởng. Đơn hàng của bạn đang được xử lý.'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).popUntil((route) => route.isFirst);
                },
                child: const Text('Về trang chủ', style: TextStyle(color: primaryColor)),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi đặt hàng: $e')));
    } finally {
      if (mounted) { setState(() { _isProcessing = false; }); }
    }
  }

  void _showQRCodeDialog(String qrData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Quét mã QR để thanh toán' ,style: TextStyle(fontSize: 15)),
          content: SizedBox(
            width: 250,
            height: 250,
            child: Center(
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 250.0,
                gapless: false,
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Đóng',style: TextStyle(color: primaryColor),),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _payWithVNPay() async {
    setState(() { _isProcessing = true; });
    try {
      final String orderId = DateTime.now().millisecondsSinceEpoch.toString();
      final String paymentUrl = await VNPayService.createPaymentUrl(
        amount: widget.totalPrice.toInt(),
        orderId: orderId,
      );
      if (mounted) {
        _showQRCodeDialog(paymentUrl);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) { setState(() { _isProcessing = false; }); }
    }
  }

  void _handleConfirmOrder() {
    if (_paymentMethod == 'vnpay') {
      _payWithVNPay();
    } else {
      _placeOrderCOD(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Xác nhận đơn hàng'),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Thông tin giao hàng'),
            _buildInfoCard(
              icon: Icons.location_on,
              title: 'Giao đến',
              subtitle: widget.shippingAddress,
              onTap: () {},
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Phương thức thanh toán'),
            RadioListTile<String>(
              title: const Text('Thanh toán khi nhận hàng (COD)'),
              value: 'cod',
              groupValue: _paymentMethod,
              onChanged: (value) => setState(() => _paymentMethod = value!),
              activeColor: primaryColor,
            ),
            RadioListTile<String>(
              title: const Text('Thanh toán qua VNPAY'),
              value: 'vnpay',
              groupValue: _paymentMethod,
              onChanged: (value) => setState(() => _paymentMethod = value!),
              activeColor: primaryColor,
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Tóm tắt đơn hàng'),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.cartItems.length,
              itemBuilder: (context, index) => _buildOrderItem(widget.cartItems[index]),
              separatorBuilder: (context, index) => const Divider(height: 24),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildCheckoutBottomBar(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: secondaryTextColor)),
        trailing: const Icon(Icons.chevron_right, color: secondaryTextColor),
        onTap: onTap,
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            item['imageUrl'] ?? '',
            width: 70,
            height: 70,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(width: 70, height: 70, color: Colors.grey.shade200),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['name'] ?? 'Sản phẩm',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text('Số lượng: ${item['quantity']}', style: const TextStyle(color: secondaryTextColor)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text('${(item['price'] as num?)?.toDouble().toStringAsFixed(0) ?? '0'} VNĐ',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCheckoutBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 3, blurRadius: 10)],
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng cộng:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: secondaryTextColor)),
              Text('${widget.totalPrice.toStringAsFixed(0)} VNĐ',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handleConfirmOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 2,
              ),
              child: _isProcessing
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : Text(
                      _paymentMethod == 'cod' ? 'Đặt hàng' : 'Thanh toán với VNPAY',
                      style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}