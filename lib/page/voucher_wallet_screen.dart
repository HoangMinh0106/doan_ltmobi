// lib/page/voucher_wallet_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';

class VoucherWalletScreen extends StatefulWidget {
  final Map<String, dynamic> userDocument;

  const VoucherWalletScreen({super.key, required this.userDocument});

  @override
  State<VoucherWalletScreen> createState() => _VoucherWalletScreenState();
}

class _VoucherWalletScreenState extends State<VoucherWalletScreen> {
  late Future<List<Map<String, dynamic>>> _vouchersFuture;

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  void _loadVouchers() {
    setState(() {
      _vouchersFuture = MongoDatabase.getVouchersForUser(widget.userDocument['_id']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho Voucher'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _vouchersFuture,
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
                  Icon(Icons.local_offer_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Bạn chưa có voucher nào.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final vouchers = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vouchers.length,
            itemBuilder: (context, index) {
              return _buildVoucherCard(vouchers[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildVoucherCard(Map<String, dynamic> voucher) {
    final currencyFormatter = NumberFormat('#,##0', 'vi_VN');
    final discountValue = (voucher['discountValue'] as num).toDouble();
    final minPurchase = (voucher['minPurchase'] as num).toDouble();
    final code = voucher['code'] as String;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Giảm ${currencyFormatter.format(discountValue)} VNĐ',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE57373),
              ),
            ),
            const Divider(height: 20),
            Text('Mã: $code'),
            const SizedBox(height: 8),
            Text('Áp dụng cho đơn hàng từ ${currencyFormatter.format(minPurchase)} VNĐ'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép mã voucher!')),
                  );
                },
                child: const Text('SAO CHÉP MÃ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}