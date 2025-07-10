// lib/page/profile_screen.dart

import 'dart:convert';
import 'package:doan_ltmobi/page/edit_profile_screen.dart'; // Kích hoạt lại import này
import 'package:doan_ltmobi/page/login_screen.dart';
import 'package:doan_ltmobi/page/order_history_screen.dart';
import 'package:doan_ltmobi/page/favorites_screen.dart'; 
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userDocument;
  final Function(Map<String, dynamic>) onProfileUpdated;

  const ProfileScreen({
    super.key,
    required this.userDocument,
    required this.onProfileUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Map<String, dynamic> _currentUserDocument;
  ImageProvider? _imageProvider;

  @override
  void initState() {
    super.initState();
    _currentUserDocument = widget.userDocument;
    _loadImage();
  }
  
  // Cập nhật lại khi có thay đổi từ widget cha
  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userDocument != oldWidget.userDocument) {
      setState(() {
        _currentUserDocument = widget.userDocument;
        _loadImage();
      });
    }
  }

  void _loadImage() {
    final String? base64String = _currentUserDocument['profile_image_base64'];
    if (base64String != null && base64String.isNotEmpty) {
      final imageBytes = base64Decode(base64String);
      _imageProvider = MemoryImage(imageBytes);
    } else {
      _imageProvider = const AssetImage("assets/image/default-avatar.png");
    }
  }

  // Hàm này được gọi khi màn hình EditProfile trả về dữ liệu mới
  void _updateProfile(Map<String, dynamic> newDocument) {
    setState(() {
      _currentUserDocument = newDocument;
      _loadImage();
    });
    // Báo cho HomeScreen biết để cập nhật dữ liệu toàn cục
    widget.onProfileUpdated(newDocument);
  }

  @override
  Widget build(BuildContext context) {
    final String email = _currentUserDocument["email"] ?? "N/A";
    final String userName = _currentUserDocument["user"] ?? email.split('@').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ của tôi', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: _imageProvider,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(email, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildProfileMenu(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMenu(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.edit_outlined,
            text: 'Chỉnh sửa hồ sơ',
            onTap: () async {
              // Kích hoạt lại chức năng này
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(
                    userDocument: _currentUserDocument,
                  ),
                ),
              );
              // Nếu có kết quả trả về (sau khi lưu), cập nhật lại hồ sơ
              if (result != null && result is Map<String, dynamic>) {
                _updateProfile(result);
              }
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildMenuItem(
            icon: Icons.favorite_border_outlined,
            text: 'Sản phẩm yêu thích',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FavoritesScreen(
                    userDocument: _currentUserDocument,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildMenuItem(
            icon: Icons.history_outlined,
            text: 'Lịch sử đơn hàng',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderHistoryScreen(
                    userId: _currentUserDocument['_id'] as mongo.ObjectId,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildMenuItem(
            icon: Icons.lock_outline,
            text: 'Đổi mật khẩu',
            onTap: () {
              // Bạn có thể tạo màn hình ChangePasswordScreen tương tự
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chức năng đang được phát triển!')));
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildMenuItem(
            icon: Icons.logout,
            text: 'Đăng xuất',
            textColor: Colors.red,
            onTap: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({required IconData icon, required String text, VoidCallback? onTap, Color? textColor}) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.grey.shade700),
      title: Text(text, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}