// lib/page/admin/flash_sale_admin_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'product_selection_screen.dart';

class FlashSaleAdminScreen extends StatefulWidget {
  const FlashSaleAdminScreen({super.key});

  @override
  State<FlashSaleAdminScreen> createState() => _FlashSaleAdminScreenState();
}

class _FlashSaleAdminScreenState extends State<FlashSaleAdminScreen> {
  DateTime? _startTime;
  DateTime? _endTime;
  // Sửa thành Map để lưu ID và giá sale
  Map<mongo.ObjectId, double> _selectedProducts = {}; 
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadCurrentSaleSettings();
  }

  Future<void> _loadCurrentSaleSettings() async {
    final saleSettings = await MongoDatabase.getFlashSale();
    if (saleSettings != null && mounted) {
      setState(() {
        _startTime = saleSettings['startTime'];
        _endTime = saleSettings['endTime'];
        // Load danh sách sản phẩm và giá sale đã có
        final saleProducts = (saleSettings['products'] as List<dynamic>?) ?? [];
        _selectedProducts = {
          for (var p in saleProducts) (p['_id'] as mongo.ObjectId): (p['salePrice'] as num).toDouble()
        };
      });
    }
  }

  Future<void> _selectDateTime(BuildContext context, bool isStartTime) async {
    final initialDate = (isStartTime ? _startTime : _endTime) ?? DateTime.now();
    
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2101),
    );
    if (date == null || !mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;

    final selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStartTime) {
        _startTime = selectedDateTime;
      } else {
        _endTime = selectedDateTime;
      }
    });
  }

  Future<void> _selectProducts() async {
    final result = await Navigator.push<Map<mongo.ObjectId, double>>(
      context,
      MaterialPageRoute(
        builder: (context) => ProductSelectionScreen(initialSelections: _selectedProducts),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedProducts = result;
      });
    }
  }

  Future<void> _saveFlashSale() async {
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn cả thời gian bắt đầu và kết thúc!')));
      return;
    }
    if (_endTime!.isBefore(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi: Thời gian kết thúc phải sau thời gian bắt đầu.')));
      return;
    }

    // Chuyển Map thành List các object để lưu vào DB
    final productsToSave = _selectedProducts.entries.map((entry) {
      return {'productId': entry.key, 'salePrice': entry.value};
    }).toList();

    try {
      await MongoDatabase.flashSaleCollection.updateOne(
        mongo.where.eq('_id', 'current_sale'),
        mongo.modify
            .set('startTime', _startTime)
            .set('endTime', _endTime)
            .set('isActive', true)
            .set('products', productsToSave), // Lưu danh sách mới
        upsert: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu cài đặt Flash Sale!')));
        Navigator.pop(context);
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lưu thất bại: $e')));
       }
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Chưa chọn';
    return DateFormat('HH:mm - dd/MM/yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt Flash Sale'),
        backgroundColor: const Color(0xFFE91E63),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Thời gian bắt đầu', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _selectDateTime(context, true),
                  child: Text(_formatDateTime(_startTime)),
                ),
                const SizedBox(height: 24),
                Text('Thời gian kết thúc', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _selectDateTime(context, false),
                  child: Text(_formatDateTime(_endTime)),
                ),
                const SizedBox(height: 24),
                
                Text('Sản phẩm áp dụng (${_selectedProducts.length} đã chọn)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.check_box_outlined),
                  label: const Text('Chọn & Sửa giá sản phẩm'),
                  onPressed: _selectProducts,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 50),
                ElevatedButton(
                  onPressed: _saveFlashSale,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  child: const Text('Lưu Cài Đặt', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}