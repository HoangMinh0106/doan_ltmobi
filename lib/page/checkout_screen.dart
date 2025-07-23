// lib/page/checkout_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:doan_ltmobi/page/success_dialog.dart';
import 'package:doan_ltmobi/page/vietqr_payment_screen.dart';
import 'package:doan_ltmobi/page/vn_location_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:flutter_paypal_payment/flutter_paypal_payment.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> userDocument;
  final List<Map<String, dynamic>> cartItems;
  final double totalPrice;
  final VoidCallback onOrderPlaced;
  final String shippingAddress;

  const CheckoutScreen({
    super.key,
    required this.userDocument,
    required this.cartItems,
    required this.totalPrice,
    required this.onOrderPlaced,
    required this.shippingAddress,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isProcessing = false;
  String _paymentMethod = 'cod';
  late String _selectedAddress;

  final TextEditingController _voucherController = TextEditingController();
  Map<String, dynamic>? _appliedVoucher;
  double _discountAmount = 0.0;
  String _voucherMessage = '';

  String _membershipLevel = 'Đồng';
  double _membershipDiscount = 0.0;
  bool _isCheckingMembership = true;
  bool _isLoadingLocation = false;

  final NumberFormat _currency = NumberFormat('#,##0', 'vi_VN');

  static const Color primaryColor = Color(0xFFE57373);
  static const Color secondaryTextColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _selectedAddress = widget.shippingAddress.trim();
    _checkMembershipStatus();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Dịch vụ vị trí đã bị tắt.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Bạn đã từ chối quyền truy cập vị trí.');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Quyền vị trí bị từ chối vĩnh viễn, không thể yêu cầu quyền.');
      } 

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      // --- SỬA LỖI: XÓA DÒNG `localeIdentifier` ---
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String fullAddress = [
          if (place.street != null && place.street!.isNotEmpty) place.street,
          if (place.subLocality != null && place.subLocality!.isNotEmpty) place.subLocality,
          if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) place.subAdministrativeArea,
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) place.administrativeArea,
          if (place.country != null && place.country!.isNotEmpty) place.country,
        ].where((s) => s != null).join(', ');

        setState(() {
          _selectedAddress = fullAddress;
        });
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lấy vị trí: $e'))
        );
      }
    } finally {
      if(mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _checkMembershipStatus() async {
    setState(() => _isCheckingMembership = true);
    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    try {
      final totalSpending = await MongoDatabase.getUserTotalSpending(userId);
      final membership = MongoDatabase.getMembershipLevel(totalSpending);
      if (mounted) {
        setState(() {
          _membershipLevel = membership['level'];
          final discountPercent = membership['discountPercent'] as int;
          _membershipDiscount = (widget.totalPrice - _discountAmount) * (discountPercent / 100);
        });
      }
    } catch (e) {
      print("Lỗi khi kiểm tra thành viên: $e");
    } finally {
      if (mounted) {
        setState(() => _isCheckingMembership = false);
      }
    }
  }

  Future<void> _selectAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VnLocationSearch()),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedAddress = result is String ? result : (result['full_address'] ?? '').toString();
      });
    }
  }

  Future<void> _applyVoucher() async {
    final code = _voucherController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final voucher = await MongoDatabase.voucherCollection.findOne(
      mongo.where.eq('code', code).eq('isActive', true),
    );

    if (voucher == null) {
      setState(() {
        _voucherMessage = 'Mã giảm giá không hợp lệ hoặc đã hết hạn.';
        _appliedVoucher = null;
        _discountAmount = 0;
      });
      await _checkMembershipStatus();
      return;
    }

    final minPurchase = (voucher['minPurchase'] as num?)?.toDouble() ?? 0.0;
    if (widget.totalPrice < minPurchase) {
      setState(() {
        _voucherMessage = 'Đơn hàng chưa đạt giá trị tối thiểu (${_currency.format(minPurchase)} VNĐ).';
        _appliedVoucher = null;
        _discountAmount = 0;
      });
      await _checkMembershipStatus();
      return;
    }

    double discount = 0;
    final discountType = voucher['discountType'];
    final discountValue = (voucher['discountValue'] as num).toDouble();
    if (discountType == 'percent') {
      discount = (widget.totalPrice * discountValue) / 100;
    } else {
      discount = discountValue;
    }

    setState(() {
      _appliedVoucher = voucher;
      _discountAmount = discount;
      _voucherMessage = 'Áp dụng thành công!';
    });
    await _checkMembershipStatus();
  }

  double get _finalPrice => widget.totalPrice - _discountAmount - _membershipDiscount;

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
        _finalPrice,
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
      if (mounted) Navigator.of(context).pop();
      widget.onOrderPlaced();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi đặt hàng: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processVietQROrder() async {
    if (_selectedAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn địa chỉ giao hàng!')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final userId = widget.userDocument['_id'] as mongo.ObjectId;
      final newOrderId = mongo.ObjectId();
      await MongoDatabase.orderCollection.insertOne({
        '_id': newOrderId,
        'userId': userId,
        'products': widget.cartItems,
        'shippingAddress': _selectedAddress,
        'totalPrice': _finalPrice,
        'orderDate': DateTime.now(),
        'status': 'Awaiting Payment',
      });
      await MongoDatabase.clearCart(userId);
      widget.onOrderPlaced();
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VietQRPaymentScreen(
              amount: _finalPrice,
              orderId: newOrderId.toHexString(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi tạo đơn hàng QR: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _payWithPayPal() {
    if (_finalPrice <= 0) {
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
    final usd = (_finalPrice / rate).toStringAsFixed(2);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaypalCheckoutView(
          sandboxMode: true,
          clientId: 'ASWpZzeLcjyWKtcQImVarVnuJsKa8aOcHhuwM6Gm0a_LXkucil9mlptWeMlAnMtc37QhhymrFLIPMHjT',
          secretKey: 'EEI0qjoEnL8uo_R3wnf657itcIzRHxsJwPKSoTMl-boXE6IHoPoT5fMiGZRImr8DVaXosk3UbdAyMEYO',
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi thanh toán PayPal.')));
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _handleConfirmOrder() {
    if (_paymentMethod == 'paypal') {
      _payWithPayPal();
    } else if (_paymentMethod == 'vietqr') {
      _processVietQROrder();
    } else {
      _processOrderCreation();
    }
  }

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
            subtitle: _selectedAddress.isEmpty ? 'Chưa chọn địa chỉ' : _selectedAddress,
            onTap: _selectAddress,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _isLoadingLocation
                ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                : Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                      onPressed: _getCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Sử dụng vị trí hiện tại'),
                    ),
                ),
          ),
          const SizedBox(height: 20),
          _buildSection('Mã giảm giá'),
          _buildVoucherInput(),
          const SizedBox(height: 20),
          _buildSection('Phương thức thanh toán'),
          _buildPaymentOption(
            title: 'Thanh toán khi nhận hàng',
            value: 'cod',
            icon: const Icon(Icons.local_shipping_outlined, color: Colors.brown, size: 28),
          ),
          _buildPaymentOption(
            title: 'Chuyển khoản VietQR',
            value: 'vietqr',
            icon: const Icon(Icons.qr_code_2, color: Colors.indigo, size: 28),
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

  Widget _buildSection(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  );

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => Card(
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

  Widget _buildVoucherInput() {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 8.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_outlined, color: primaryColor),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _voucherController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập mã giảm giá',
                      border: InputBorder.none,
                    ),
                    onChanged: (text) {
                      if (_voucherMessage.isNotEmpty) {
                        setState(() => _voucherMessage = '');
                      }
                    },
                  ),
                ),
                TextButton(
                  onPressed: _applyVoucher,
                  child: const Text('Áp dụng', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (_voucherMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 48),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _voucherMessage,
                    style: TextStyle(
                      color: _appliedVoucher != null ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

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
            boxShadow: selected ? [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4))
            ] : [],
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text('Số lượng: ${item['quantity']}',
                style: const TextStyle(color: secondaryTextColor, fontSize: 14)),
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
        BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 3, blurRadius: 10)
      ],
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tạm tính:', style: TextStyle(fontSize: 16, color: secondaryTextColor)),
            Text('${_currency.format(widget.totalPrice)} VNĐ', style: const TextStyle(fontSize: 16)),
          ],
        ),
        if (_appliedVoucher != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Giảm giá (${_appliedVoucher!['code']}):', style: const TextStyle(fontSize: 16, color: Colors.green)),
                Text('-${_currency.format(_discountAmount)} VNĐ', style: const TextStyle(fontSize: 16, color: Colors.green)),
              ],
            ),
          ),
        if (_membershipDiscount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ưu đãi TV ($_membershipLevel):', style: const TextStyle(fontSize: 16, color: Colors.blue)),
                Text('-${_currency.format(_membershipDiscount)} VNĐ', style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        if (_isCheckingMembership)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tổng cộng:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: secondaryTextColor)),
            Text('${_currency.format(_finalPrice)} VNĐ', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isProcessing || _isCheckingMembership ? null : _handleConfirmOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 2,
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                : Text(
                    _paymentMethod == 'cod' ? 'Đặt hàng' : (_paymentMethod == 'vietqr' ? 'Tạo mã VietQR' : 'Thanh toán với ${_paymentMethod.toUpperCase()}'),
                    style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    ),
  );
}