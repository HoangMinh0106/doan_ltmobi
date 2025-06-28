// lib/page/vnpay_service.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class VNPayService {
  static const String vnp_TmnCode = '29JGDAY6';
  static const String vnp_HashSecret = 'AG5R1Q82IHQEXFU5DTX4X7G3YXB8Y80C';
  static const String vnp_Url = 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html';
  static const String vnp_ReturnUrl = 'https://sandbox.vnpayment.vn/tryitnow/Home/VnPayIPN';

  /// Hàm này tạo và trả về một chuỗi URL thanh toán để hiển thị dưới dạng QR.
  static Future<String> createPaymentUrl({
    required int amount,
    required String orderId,
    String? bankCode,
  }) async {
    final Map<String, String> params = {
      'vnp_Version': '2.1.0',
      'vnp_Command': 'pay',
      'vnp_TmnCode': vnp_TmnCode,
      'vnp_Amount': (amount * 100).toString(),
      'vnp_CreateDate': _getCurrentDate(),
      'vnp_CurrCode': 'VND',
      'vnp_IpAddr': '127.0.0.1',
      'vnp_Locale': 'vn',
      'vnp_OrderInfo': 'Thanh toan don hang $orderId',
      'vnp_OrderType': 'other',
      'vnp_ReturnUrl': vnp_ReturnUrl,
      'vnp_TxnRef': orderId,
    };

    if (bankCode != null && bankCode.isNotEmpty) {
      params['vnp_BankCode'] = bankCode;
    }

    final sortedKeys = params.keys.toList()..sort();
    final hashDataBuffer = StringBuffer();
    for (final key in sortedKeys) {
      hashDataBuffer.write(key);
      hashDataBuffer.write('=');
      hashDataBuffer.write(params[key]);
      if (key != sortedKeys.last) {
        hashDataBuffer.write('&');
      }
    }
    String hashData = hashDataBuffer.toString();

    final key = utf8.encode(vnp_HashSecret);
    final hmacSha512 = Hmac(sha512, key);
    final digest = hmacSha512.convert(utf8.encode(hashData));
    final vnpSecureHash = hex.encode(digest.bytes);

    params['vnp_SecureHash'] = vnpSecureHash;

    final paymentUrl = Uri.parse(vnp_Url).replace(queryParameters: params).toString();

    if (kDebugMode) {
      print('================= QR URL DEBUG =================');
      print('URL for QR: $paymentUrl');
      print('-------------------------------------------------');
      print('HASH DATA: $hashData');
      print('=================================================');
    }

    return paymentUrl;
  }

  static String _getCurrentDate() {
    final now = DateTime.now();
    return '${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}${_twoDigits(now.hour)}${_twoDigits(now.minute)}${_twoDigits(now.second)}';
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
}