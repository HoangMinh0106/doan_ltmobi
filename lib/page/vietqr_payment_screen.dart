// lib/page/vietqr_payment_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class VietQRPaymentScreen extends StatelessWidget {
  final double amount;
  final String orderId;

  const VietQRPaymentScreen({
    super.key,
    required this.amount,
    required this.orderId,
  });

  // ==========================================================
  // =====> THÔNG TIN TÀI KHOẢN ĐÃ ĐƯỢC CẬP NHẬT Ở ĐÂY <=====
  // ==========================================================
  static const String bankBin = "970422"; // Mã BIN của MB Bank
  static const String bankAccountNumber = "0903050953"; // Số tài khoản của bạn
  static const String accountName = "Nguyễn Trương Hoàng Minh"; // Tên chủ tài khoản

  // Hàm tạo chuỗi VietQR
  String _buildVietQRString() {
    // Nội dung chuyển khoản là mã đơn hàng, rút gọn
    final String orderInfo = "TT ${orderId.replaceAll('-', '').substring(0, 10)}";
    
    // Tạo chuỗi theo chuẩn VietQR
    // Lưu ý: api.vietqr.io/image là một lựa chọn khác thay cho img.vietqr.io
    return 'https://api.vietqr.io/image/$bankBin-$bankAccountNumber-print.png?amount=$amount&addInfo=$orderInfo&accountName=$accountName';
  }

  @override
  Widget build(BuildContext context) {
    final qrString = _buildVietQRString();
    final formattedAmount = NumberFormat('#,##0', 'vi_VN').format(amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán VietQR'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Quét mã QR để thanh toán',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 4),
                borderRadius: BorderRadius.circular(8)
              ),
              child: QrImageView(
                data: qrString,
                version: QrVersions.auto,
                size: 250.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            _buildInfoCard(
              bankName: 'MB Bank (Ngân hàng Quân đội)',
              accountName: accountName,
              accountNumber: bankAccountNumber,
              amount: formattedAmount,
              orderInfo: "TT ${orderId.replaceAll('-', '').substring(0, 10)}",
              context: context,
            ),
            const SizedBox(height: 24),
            const Text(
              'Sau khi thanh toán thành công, đơn hàng của bạn sẽ được xác nhận trong vài phút.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String bankName,
    required String accountName,
    required String accountNumber,
    required String amount,
    required String orderInfo,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoRow(context, 'Ngân hàng:', bankName),
            _buildInfoRow(context, 'Chủ tài khoản:', accountName),
            _buildInfoRow(context, 'Số tài khoản:', accountNumber, isCopyable: true),
            _buildInfoRow(context, 'Số tiền:', '$amount VNĐ', isHighlighted: true),
            _buildInfoRow(context, 'Nội dung:', orderInfo, isCopyable: true),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {bool isHighlighted = false, bool isCopyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isHighlighted ? Colors.red : Colors.black,
              ),
            ),
          ),
          if (isCopyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã sao chép "$value"'), backgroundColor: Colors.green),
                );
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.copy, size: 18, color: Colors.blue),
              ),
            ),
        ],
      ),
    );
  }
}