// lib/page/custom_cake_order_screen.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:mongo_dart/mongo_dart.dart' as m;

class CustomCakeOrderScreen extends StatefulWidget {
  const CustomCakeOrderScreen({super.key});

  @override
  _CustomCakeOrderScreenState createState() => _CustomCakeOrderScreenState();
}

class _CustomCakeOrderScreenState extends State<CustomCakeOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers and variables
  String? _selectedSize;
  String? _selectedFlavor;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  DateTime? _selectedDate;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  final List<String> _cakeSizes = ['Nhỏ (16cm, 2-4 người)', 'Vừa (20cm, 5-7 người)', 'Lớn (24cm, 8-10 người)'];
  final List<String> _cakeFlavors = ['Vani', 'Sô-cô-la', 'Dâu tây', 'Trà xanh', 'Bắp', 'Red Velvet'];

  bool _isLoading = false;
  bool _isPickingImage = false; // <-- SỬA LỖI: Thêm biến trạng thái

  // SỬA LỖI: Cập nhật hàm chọn ảnh để chống nhấn nhiều lần
  Future<void> _pickImage() async {
    if (_isPickingImage) return; // Không cho phép chạy nếu đang chọn ảnh

    setState(() {
      _isPickingImage = true;
    });

    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("Lỗi khi chọn ảnh: $e");
    } finally {
      // Luôn đảm bảo nút được kích hoạt lại
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now().add(const Duration(days: 3)),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
        final userDocument = await MongoDatabase.userCollection.findOne(); 
        if (userDocument == null) {
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Không tìm thấy thông tin người dùng. Vui lòng đăng nhập lại.'))
            );
            return;
        }

      setState(() {
        _isLoading = true;
      });

      String? imageBase64;
      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        imageBase64 = base64Encode(bytes);
      }

      final customOrderData = {
        'userId': userDocument['_id'],
        'contactName': _contactNameController.text,
        'contactPhone': _contactPhoneController.text,
        'cakeSize': _selectedSize,
        'cakeFlavor': _selectedFlavor,
        'notes': _notesController.text,
        'desiredDate': _selectedDate,
        'sampleImage': imageBase64,
        'status': 'Mới',
        'requestDate': DateTime.now(),
      };

      final message = await MongoDatabase.createCustomOrder(customOrderData);
      
      setState(() {
        _isLoading = false;
      });

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Thành công'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); 
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt Bánh Theo Yêu Cầu'),
        backgroundColor: Colors.pink[100],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hãy cho chúng tôi biết về chiếc bánh mơ ước của bạn. Chúng tôi sẽ liên hệ lại để tư vấn và báo giá.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _contactNameController,
                decoration: const InputDecoration(labelText: 'Tên của bạn', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactPhoneController,
                decoration: const InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập số điện thoại' : null,
              ),
              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                value: _selectedSize,
                decoration: const InputDecoration(labelText: 'Chọn kích thước bánh', border: OutlineInputBorder()),
                items: _cakeSizes.map((String size) {
                  return DropdownMenuItem<String>(value: size, child: Text(size));
                }).toList(),
                onChanged: (newValue) => setState(() => _selectedSize = newValue),
                validator: (value) => value == null ? 'Vui lòng chọn kích thước' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedFlavor,
                decoration: const InputDecoration(labelText: 'Chọn hương vị', border: OutlineInputBorder()),
                items: _cakeFlavors.map((String flavor) {
                  return DropdownMenuItem<String>(value: flavor, child: Text(flavor));
                }).toList(),
                onChanged: (newValue) => setState(() => _selectedFlavor = newValue),
                validator: (value) => value == null ? 'Vui lòng chọn hương vị' : null,
              ),
              const SizedBox(height: 16),
              
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_selectedDate == null
                    ? 'Chọn ngày nhận bánh'
                    : 'Ngày nhận: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú thêm',
                  hintText: 'VD: Viết chữ "Chúc mừng sinh nhật Mẹ", làm ít ngọt...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              const Text('Ảnh mẫu (nếu có)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Tải ảnh lên'),
                // SỬA LỖI: Vô hiệu hóa nút khi đang chọn ảnh
                onPressed: _isPickingImage ? null : _pickImage,
              ),
              if (_imageFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Image.file(_imageFile!, height: 150, fit: BoxFit.cover),
                ),
              const SizedBox(height: 32),

              Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child: const Text('Gửi Yêu Cầu'),
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }
}