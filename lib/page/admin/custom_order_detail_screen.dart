// lib/page/admin/custom_order_detail_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:mongo_dart/mongo_dart.dart' as m;

class CustomOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const CustomOrderDetailScreen({super.key, required this.order});

  @override
  _CustomOrderDetailScreenState createState() => _CustomOrderDetailScreenState();
}

class _CustomOrderDetailScreenState extends State<CustomOrderDetailScreen> {
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order['status'];
  }

  Future<void> _updateStatus(String newStatus) async {
    await MongoDatabase.customOrderCollection.updateOne(
      m.where.id(widget.order['_id']),
      m.modify.set('status', newStatus),
    );
    setState(() {
      _currentStatus = newStatus;
    });
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật trạng thái thành "$newStatus"')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết Yêu cầu'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Tên khách hàng:', widget.order['contactName']),
            _buildDetailRow('Số điện thoại:', widget.order['contactPhone']),
            _buildDetailRow('Ngày yêu cầu:', DateFormat('dd/MM/yyyy HH:mm').format(widget.order['requestDate'].toLocal())),
            if(widget.order['desiredDate'] != null)
              _buildDetailRow('Ngày nhận mong muốn:', DateFormat('dd/MM/yyyy').format(widget.order['desiredDate'].toLocal())),
            const Divider(height: 30),
            _buildDetailRow('Kích thước bánh:', widget.order['cakeSize']),
            _buildDetailRow('Hương vị:', widget.order['cakeFlavor']),
            _buildDetailRow('Ghi chú:', widget.order['notes'] ?? 'Không có'),
            const Divider(height: 30),
            const Text('Ảnh mẫu:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            if (widget.order['sampleImage'] != null)
              Image.memory(base64Decode(widget.order['sampleImage'])),
            if (widget.order['sampleImage'] == null)
              const Text('Khách hàng không cung cấp ảnh mẫu.'),
            const Divider(height: 30),
            _buildStatusSection(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trạng thái hiện tại: $_currentStatus', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
        const SizedBox(height: 15),
        const Text('Cập nhật trạng thái:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Wrap(
          spacing: 10,
          children: [
            ElevatedButton(onPressed: () => _updateStatus('Đã báo giá'), child: const Text('Đã báo giá')),
            ElevatedButton(onPressed: () => _updateStatus('Đã xác nhận'), child: const Text('Đã xác nhận')),
            ElevatedButton(onPressed: () => _updateStatus('Đã hủy'), child: const Text('Đã hủy'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red)),
          ],
        )
      ],
    );
  }
}