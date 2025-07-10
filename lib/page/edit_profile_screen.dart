// lib/page/edit_profile_screen.dart

import 'dart:convert';
import 'dart:io';

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userDocument;

  const EditProfileScreen({super.key, required this.userDocument});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  String? _selectedGender;
  File? _newProfileImageFile;
  String? _currentProfileImageBase64;
  bool _isLoading = false;

  // *** BẮT ĐẦU CẢI TIẾN: Định nghĩa màu sắc chủ đạo để dễ dàng sử dụng ***
  static const Color primaryColor = Color(0xFFE57373);
  // *** KẾT THÚC CẢI TIẾN ***

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final String email = widget.userDocument["email"] ?? "";
    final String currentName = widget.userDocument["user"] ?? email.split('@').first;
    
    _nameController = TextEditingController(text: currentName);
    _phoneController = TextEditingController(text: widget.userDocument["phone"]);
    _selectedGender = widget.userDocument["gender"];
    _currentProfileImageBase64 = widget.userDocument['profile_image_base64'];
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() {
        _newProfileImageFile = File(image.path);
      });
    }
  }

  Future<void> _updateUserInfo() async {
    if (_nameController.text.trim().isEmpty) {
       ElegantNotification.error(
        title: const Text("Lỗi"),
        description: const Text("Tên hiển thị không được để trống."),
      ).show(context);
      return;
    }

    setState(() => _isLoading = true);

    final mongo.ObjectId userId = widget.userDocument['_id'];
    String? updatedImageBase64 = _currentProfileImageBase64;

    if (_newProfileImageFile != null) {
      final imageBytes = await _newProfileImageFile!.readAsBytes();
      updatedImageBase64 = base64Encode(imageBytes);
    }
    
    final updateDoc = {
      '\$set': {
        'user': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _selectedGender,
        'profile_image_base64': updatedImageBase64,
      }
    };
    
    await MongoDatabase.userCollection.update(mongo.where.id(userId), updateDoc);

    var updatedUserDoc = await MongoDatabase.userCollection.findOne(mongo.where.id(userId));

    setState(() => _isLoading = false);

    if (mounted) {
      ElegantNotification.success(
        title: const Text("Thành công"),
        description: const Text("Thông tin của bạn đã được cập nhật."),
      ).show(context);
      
      Navigator.pop(context, updatedUserDoc);
    }
  }

  @override
  Widget build(BuildContext context) {
    // *** BẮT ĐẦU CẢI TIẾN: Cập nhật giao diện tổng thể ***
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Chỉnh sửa hồ sơ"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar và nút chọn ảnh
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: _newProfileImageFile != null
                        ? FileImage(_newProfileImageFile!)
                        : (_currentProfileImageBase64 != null &&
                                _currentProfileImageBase64!.isNotEmpty
                            ? MemoryImage(base64Decode(_currentProfileImageBase64!))
                            : const AssetImage("assets/image/default-avatar.png")) as ImageProvider?,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: primaryColor, // Đồng bộ màu
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Các ô nhập liệu
            _buildLabeledTextField(
              label: "Tên hiển thị",
              controller: _nameController,
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 20),
            _buildLabeledTextField(
              label: "Số điện thoại",
              controller: _phoneController,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            _buildLabeledDropdown(),
            
            const SizedBox(height: 40),

            // Nút lưu thay đổi
            ElevatedButton(
              onPressed: _isLoading ? null : _updateUserInfo,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor, // Đồng bộ màu
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Text(
                      'Lưu thay đổi',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget mới để tạo ô nhập liệu có nhãn và icon
  Widget _buildLabeledTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey.shade600),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  // Widget mới cho dropdown giới tính
  Widget _buildLabeledDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Giới tính", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.wc_outlined, color: Colors.grey.shade600),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
             focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
          ),
          value: _selectedGender,
          items: ['Nam', 'Nữ', 'Khác']
              .map((String value) =>
                  DropdownMenuItem<String>(value: value, child: Text(value)))
              .toList(),
          onChanged: (newValue) => setState(() => _selectedGender = newValue),
        ),
      ],
    );
  }
  // *** KẾT THÚC CẢI TIẾN ***
}