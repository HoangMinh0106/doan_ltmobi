// lib/page/checkout_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:doan_ltmobi/page/success_dialog.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'vnpay_service.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:flutter_paypal_payment/flutter_paypal_payment.dart';

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

  Future<void> _processOrderCreation() async {
    setState(() {
      _isProcessing = true;
    });
    try {
      final userId = widget.userDocument['_id'] as mongo.ObjectId;
      await MongoDatabase.createOrder(
        userId,
        widget.cartItems,
        widget.totalPrice,
        widget.shippingAddress,
      );
      await MongoDatabase.clearCart(userId);
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (dialogContext) => SuccessDialog(
                title: 'Đặt hàng thành công!',
                message:
                    'Cảm ơn bạn đã tin tưởng. Đơn hàng của bạn đang được xử lý.',
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
        );
        if (mounted) Navigator.of(context).pop();
        widget.onOrderPlaced();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi đặt hàng: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _payWithPayPal() {
    if (widget.totalPrice <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Tổng tiền không hợp lệ.")));
      return;
    }
    const double exchangeRate = 25000;
    final totalAmountUSD = (widget.totalPrice / exchangeRate).toStringAsFixed(
      2,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (BuildContext context) => PaypalCheckoutView(
              sandboxMode: true,
              clientId:
                  "ASWpZzeLcjyWKtcQImVarVnuJsKa8aOcHhuwM6Gm0a_LXkucil9mlptWeMlAnMtc37QhhymrFLIPMHjT",
              secretKey:
                  "EEI0qjoEnL8uo_R3wnf657itcIzRHxsJwPKSoTMl-boXE6IHoPoT5fMiGZRImr8DVaXosk3UbdAyMEYO",
              //email personal : sb-43l47vv38933884@personal.example.com
              //pass: ({<e2P-H
              transactions: [
                {
                  "amount": {
                    "total": totalAmountUSD,
                    "currency": "USD",
                    "details": {
                      "subtotal": totalAmountUSD,
                      "shipping": '0',
                      "shipping_discount": 0,
                    },
                  },
                  "description": "Thanh toán cho đơn hàng.",
                },
              ],
              note: "Vui lòng hoàn tất thanh toán.",
              onSuccess: (Map params) async {
                Navigator.pop(context);
                await _processOrderCreation();
              },
              onError: (error) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Lỗi thanh toán PayPal.")),
                );
              },
              onCancel: () {
                Navigator.pop(context);
              },
            ),
      ),
    );
  }

  void _handleConfirmOrder() {
    if (_paymentMethod == 'paypal') {
      _payWithPayPal();
    } else {
      _processOrderCreation();
    }
  }

  Widget _buildPaymentOption({
    required String title,
    required String value,
    required Widget icon,
  }) {
    final bool isSelected = _paymentMethod == value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey.shade300,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : [],
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: primaryColor, size: 24),
            ],
          ),
        ),
      ),
    );
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

            _buildPaymentOption(
              title: 'Thanh toán khi nhận hàng',
              value: 'cod',
              icon: const Icon(
                Icons.local_shipping_outlined,
                color: Colors.brown,
                size: 28,
              ),
            ),
            _buildPaymentOption(
              title: 'Thanh toán qua VNPAY',
              value: 'vnpay',
              icon: Image.asset('assets/vnpay_logo.png', width: 28, height: 28),
            ),
            _buildPaymentOption(
              title: 'Thanh toán qua PayPal',
              value: 'paypal',
              icon: Image.asset(
                'assets/paypal_logo.png',
                width: 28,
                height: 28,
              ),
            ),

            const SizedBox(height: 20),
            _buildSectionTitle('Tóm tắt đơn hàng'),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.cartItems.length,
              itemBuilder:
                  (context, index) => _buildOrderItem(widget.cartItems[index]),
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
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
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
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: secondaryTextColor),
        ),
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
            errorBuilder:
                (context, error, stackTrace) => Container(
                  width: 70,
                  height: 70,
                  color: Colors.grey.shade200,
                ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['name'] ?? 'Sản phẩm',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Số lượng: ${item['quantity']}',
                style: const TextStyle(color: secondaryTextColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '${(item['price'] as num?)?.toDouble().toStringAsFixed(0) ?? '0'} VNĐ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCheckoutBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 3,
            blurRadius: 10,
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng cộng:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: secondaryTextColor,
                ),
              ),
              Text(
                '${widget.totalPrice.toStringAsFixed(0)} VNĐ',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 2,
              ),
              child:
                  _isProcessing
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                      : Text(
                        _paymentMethod == 'cod'
                            ? 'Đặt hàng'
                            : 'Thanh toán với ${_paymentMethod.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
