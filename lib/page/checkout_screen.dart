// lib/page/checkout_screen.dart
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:doan_ltmobi/page/success_dialog.dart';
import 'package:doan_ltmobi/page/vn_location_search.dart';          
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  // ──────────────────────────────────────────────────────────────
  // STATE
  bool _isProcessing = false;
  String _paymentMethod = 'cod';
  late String _selectedAddress;   // địa chỉ động

  final NumberFormat _currency =
      NumberFormat('#,##0', 'vi_VN'); // 10 000 → 10.000

  static const Color primaryColor = Color(0xFFE57373);
  static const Color secondaryTextColor = Colors.grey;
  // ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _selectedAddress = widget.shippingAddress.trim();
  }

  // ──────────────────────────────────────────────────────────────
  // CHỌN ĐỊA CHỈ TỪ VnLocationSearch
  Future<void> _selectAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VnLocationSearch()),
    );

    // Kết quả có thể là String hoặc Map tuỳ bạn cấu hình trong VnLocationSearch
    if (result != null && mounted) {
      setState(() {
        _selectedAddress = result is String
            ? result
            : (result['full_address'] ?? '').toString();
      });
    }
  }

  // ──────────────────────────────────────────────────────────────
  // XỬ LÝ ĐẶT HÀNG / THANH TOÁN
  Future<void> _processOrderCreation() async {
    if (_selectedAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn địa chỉ giao hàng!')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final userId = widget.userDocument['_id'] as mongo.ObjectId;
      await MongoDatabase.createOrder(
        userId,
        widget.cartItems,
        widget.totalPrice,
        _selectedAddress,
      );
      await MongoDatabase.clearCart(userId);

      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => SuccessDialog(
          title: 'Đặt hàng thành công!',
          message: 'Cảm ơn bạn đã tin tưởng. Đơn hàng của bạn đang được xử lý.',
          onPressed: () => Navigator.of(context).pop(),
        ),
      );
      if (mounted) Navigator.of(context).pop(); // đóng Checkout
      widget.onOrderPlaced();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi khi đặt hàng: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _payWithPayPal() {
    if (widget.totalPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tổng tiền không hợp lệ.')),
      );
      return;
    }
    if (_selectedAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn địa chỉ giao hàng!')),
      );
      return;
    }

    const double rate = 25000;
    final usd = (widget.totalPrice / rate).toStringAsFixed(2);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaypalCheckoutView(
          sandboxMode: true,
          clientId:
              'ASWpZzeLcjyWKtcQImVarVnuJsKa8aOcHhuwM6Gm0a_LXkucil9mlptWeMlAnMtc37QhhymrFLIPMHjT',
          secretKey:
              'EEI0qjoEnL8uo_R3wnf657itcIzRHxsJwPKSoTMl-boXE6IHoPoT5fMiGZRImr8DVaXosk3UbdAyMEYO',
          transactions: [
            {
              'amount': {
                'total': usd,
                'currency': 'USD',
                'details': {'subtotal': usd, 'shipping': '0', 'shipping_discount': 0},
              },
              'description': 'Thanh toán cho đơn hàng.',
            },
          ],
          note: 'Vui lòng hoàn tất thanh toán.',
          onSuccess: (_) async {
            Navigator.pop(context);
            await _processOrderCreation();
          },
          onError: (_) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Lỗi thanh toán PayPal.')));
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _handleConfirmOrder() =>
      _paymentMethod == 'paypal' ? _payWithPayPal() : _processOrderCreation();

  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8F8F8),
        appBar: AppBar(
          title: const Text('Xác nhận đơn hàng'),
          backgroundColor: Colors.white,
          elevation: 1,
          foregroundColor: Colors.black87,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection('Thông tin giao hàng'),
              _buildInfoCard(
                icon: Icons.location_on,
                title: 'Giao đến',
                subtitle: _selectedAddress.isEmpty
                    ? 'Chưa chọn địa chỉ'
                    : _selectedAddress,
                onTap: _selectAddress,
              ),
              const SizedBox(height: 20),
              _buildSection('Phương thức thanh toán'),
              _buildPaymentOption(
                title: 'Thanh toán khi nhận hàng',
                value: 'cod',
                icon: const Icon(Icons.local_shipping_outlined,
                    color: Colors.brown, size: 28),
              ),
              _buildPaymentOption(
                title: 'Thanh toán qua VNPAY',
                value: 'vnpay',
                icon: Image.asset('assets/vnpay_logo.png', width: 28, height: 28),
              ),
              _buildPaymentOption(
                title: 'Thanh toán qua PayPal',
                value: 'paypal',
                icon: Image.asset('assets/paypal_logo.png', width: 28, height: 28),
              ),
              const SizedBox(height: 20),
              _buildSection('Tóm tắt đơn hàng'),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.cartItems.length,
                itemBuilder: (_, i) => _buildOrderItem(widget.cartItems[i]),
                separatorBuilder: (_, __) => const Divider(height: 24),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildCheckoutBar(),
      );

  // ──────────────────────────────────────────────────────────────
  Widget _buildSection(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Card(
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(icon, color: primaryColor),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle:
              Text(subtitle, style: const TextStyle(color: secondaryTextColor)),
          trailing:
              const Icon(Icons.chevron_right, color: secondaryTextColor),
          onTap: onTap,
        ),
      );

  Widget _buildPaymentOption({
    required String title,
    required String value,
    required Widget icon,
  }) {
    final selected = _paymentMethod == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? primaryColor.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? primaryColor : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: primaryColor.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]
                : [],
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: primaryColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) => Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              item['imageUrl'] ?? '',
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
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
                Text(item['name'] ?? 'Sản phẩm',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text('Số lượng: ${item['quantity']}',
                    style:
                        const TextStyle(color: secondaryTextColor, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text('${_currency.format((item['price'] as num?)?.toDouble() ?? 0)} VNĐ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      );

  Widget _buildCheckoutBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 3,
                blurRadius: 10)
          ],
          borderRadius:
              const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng cộng:',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: secondaryTextColor)),
                Text('${_currency.format(widget.totalPrice)} VNĐ',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryColor)),
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
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 3),
                      )
                    : Text(
                        _paymentMethod == 'cod'
                            ? 'Đặt hàng'
                            : 'Thanh toán với ${_paymentMethod.toUpperCase()}',
                        style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      );
}
