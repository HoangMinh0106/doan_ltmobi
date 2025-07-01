// lib/page/profile_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:doan_ltmobi/page/login_screen.dart';
import 'package:doan_ltmobi/page/order_history_screen.dart'; // Import màn hình mới
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mongo_dart/mongo_dart.dart' as M;
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userDocument;
  final Function(Map<String, dynamic>) onProfileUpdated;
  const ProfileScreen(
      {Key? key,
      required this.userDocument,
      required this.onProfileUpdated})
      : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _phoneController;
  late TextEditingController _nameController;
  String? _selectedGender;
  File? _newProfileImageFile;
  String? _currentProfileImageBase64;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final String email = widget.userDocument["email"] ?? "";
    _nameController = TextEditingController(text: email.split('@').first);
    _phoneController =
        TextEditingController(text: widget.userDocument["phone"]);
    _selectedGender = widget.userDocument["gender"];
    _currentProfileImageBase64 = widget.userDocument['profile_image_base64'];
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userDocument != oldWidget.userDocument) {
      _loadUserData();
    }
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
    setState(() => _isLoading = true);

    final M.ObjectId userId = widget.userDocument['_id'];
    String? updatedImageBase64 = _currentProfileImageBase64;

    if (_newProfileImageFile != null) {
      final imageBytes = await _newProfileImageFile!.readAsBytes();
      updatedImageBase64 = base64Encode(imageBytes);
    }

    final newEmail = "${_nameController.text.trim()}@gmail.com";

    var modifier = M.modify
        .set('email', newEmail)
        .set('phone', _phoneController.text.trim())
        .set('gender', _selectedGender)
        .set('profile_image_base64', updatedImageBase64);

    await MongoDatabase.userCollection.update(M.where.id(userId), modifier);

    var updatedDoc =
        await MongoDatabase.userCollection.findOne(M.where.id(userId));

    setState(() {
      _isLoading = false;
      if (updatedDoc != null) {
        _currentProfileImageBase64 = updatedDoc['profile_image_base64'];
        _newProfileImageFile = null;
        widget.onProfileUpdated(updatedDoc);
      }
    });

    if (mounted) {
      ElegantNotification.success(
        title: const Text("Thành công"),
        description: const Text("Thông tin của bạn đã được cập nhật."),
      ).show(context);
    }
  }

  Future<void> _logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          icon: const Icon(Icons.logout_rounded,
              color: Color(0xFFE57373), size: 48),
          title: const Text(
            'Xác nhận đăng xuất',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này không?',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: <Widget>[
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Hủy',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE57373))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE57373),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _logout,
                    child: const Text('Đăng xuất',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Tài khoản của tôi",
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 22)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            // --- Phần thông tin cá nhân (Avatar, Tên, SĐT, Giới tính) ---
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: _newProfileImageFile != null
                        ? FileImage(_newProfileImageFile!)
                        : (_currentProfileImageBase64 != null &&
                                _currentProfileImageBase64!.isNotEmpty
                            ? MemoryImage(
                                base64Decode(_currentProfileImageBase64!))
                            : null) as ImageProvider?,
                    child: _newProfileImageFile == null &&
                            (_currentProfileImageBase64 == null ||
                                _currentProfileImageBase64!.isEmpty)
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE57373),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text("Tên hiển thị",
                    style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: Colors.black, width: 2.0),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text("Số điện thoại",
                    style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide:
                        const BorderSide(color: Colors.black, width: 2.0),
                  ),
                ),
                keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            const Align(
                alignment: Alignment.centerLeft,
                child:
                    Text("Giới tính", style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: Colors.black, width: 2.0),
                ),
              ),
              value: _selectedGender,
              items: ['Nam', 'Nữ', 'Khác']
                  .map((String value) =>
                      DropdownMenuItem<String>(value: value, child: Text(value)))
                  .toList(),
              onChanged: (newValue) => setState(() => _selectedGender = newValue),
            ),

            const SizedBox(height: 32),
            
            // --- CÁC NÚT BẤM ---
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateUserInfo,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE57373),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 3))
                    : const Text('Cập nhật thông tin',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),

            // **NÚT LỊCH SỬ ĐƠN HÀNG MỚI**
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long, color: Colors.black54),
                label: const Text('Lịch sử đơn hàng',
                    style: TextStyle(color: Colors.black, fontSize: 16)),
                onPressed: () {
                  final userId = widget.userDocument['_id'] as M.ObjectId?;
                  if (userId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderHistoryScreen(userId: userId),
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(height: 16),

            // Nút đăng xuất
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.black54),
                label: const Text('Đăng xuất',
                    style: TextStyle(color: Colors.black, fontSize: 16)),
                onPressed: _showLogoutDialog,
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}