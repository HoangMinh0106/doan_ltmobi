// lib/page/profile_screen.dart

import 'dart:convert';
import 'package:doan_ltmobi/dpHelper/mongodb.dart'; // SỬA LỖI: Sửa đường dẫn import
import 'package:doan_ltmobi/page/change_password_screen.dart';
import 'package:doan_ltmobi/page/edit_profile_screen.dart';
import 'package:doan_ltmobi/page/login_screen.dart';
import 'package:doan_ltmobi/page/order_history_screen.dart';
import 'package:doan_ltmobi/page/favorites_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:shared_preferences/shared_preferences.dart';

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

  String _membershipLevel = 'Đồng';
  String _progressText = '';
  double _progressValue = 0.0;
  bool _isLoadingMembership = true;
  final _currencyFormatter = NumberFormat('#,##0', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _currentUserDocument = widget.userDocument;
    _loadImage();
    _loadMembershipData();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userDocument != oldWidget.userDocument) {
      setState(() {
        _currentUserDocument = widget.userDocument;
        _loadImage();
        _loadMembershipData();
      });
    }
  }

  void _loadImage() {
    final String? base64String = _currentUserDocument['profile_image_base64'];
    if (base64String != null && base64String.isNotEmpty) {
      try {
        final imageBytes = base64Decode(base64String);
        _imageProvider = MemoryImage(imageBytes);
      } catch (e) {
        _imageProvider = const AssetImage("assets/image/default-avatar.png");
      }
    } else {
      _imageProvider = const AssetImage("assets/image/default-avatar.png");
    }
  }

  Future<void> _loadMembershipData() async {
    if (!mounted) return;
    setState(() => _isLoadingMembership = true);

    final userId = _currentUserDocument['_id'] as mongo.ObjectId;
    final totalSpending = await MongoDatabase.getUserTotalSpending(userId);
    final membership = MongoDatabase.getMembershipLevel(totalSpending);

    double amountNeeded = 0;
    double progressValue = 0;
    String progressText = '';

    const silverThreshold = 3000000.0;
    const goldThreshold = 5000000.0;

    if (membership['level'] == 'Vàng') {
      progressText = 'Bạn đã đạt hạng thành viên cao nhất!';
      progressValue = 1.0;
    } else if (membership['level'] == 'Bạc') {
      amountNeeded = goldThreshold - totalSpending;
      progressValue = (totalSpending - silverThreshold) / (goldThreshold - silverThreshold);
      progressText = 'Chi tiêu thêm ${_currencyFormatter.format(amountNeeded)}đ để lên hạng Vàng.';
    } else { // Hạng Đồng
      amountNeeded = silverThreshold - totalSpending;
      progressValue = totalSpending / silverThreshold;
      progressText = 'Chi tiêu thêm ${_currencyFormatter.format(amountNeeded)}đ để lên hạng Bạc.';
    }

    if (mounted) {
      setState(() {
        _membershipLevel = membership['level'];
        _progressText = progressText;
        _progressValue = progressValue.clamp(0.0, 1.0);
        _isLoadingMembership = false;
      });
    }
  }

  void _updateProfile(Map<String, dynamic> newDocument) {
    setState(() {
      _currentUserDocument = newDocument;
      _loadImage();
    });
    widget.onProfileUpdated(newDocument);
    _loadMembershipData();
  }

  Future<void> _logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String email = _currentUserDocument["email"] ?? "N/A";
    final String userName = _currentUserDocument["user"] ?? email.split('@').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ', style: TextStyle(fontWeight: FontWeight.bold)),
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
              _buildMembershipCard(),
              const SizedBox(height: 24),
              _buildProfileMenu(context),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMembershipCard() {
    Color levelColor;
    IconData levelIcon;
    switch (_membershipLevel) {
      case 'Vàng':
        levelColor = Colors.amber.shade700;
        levelIcon = Icons.workspace_premium;
        break;
      case 'Bạc':
        levelColor = Colors.blueGrey.shade400;
        levelIcon = Icons.shield;
        break;
      default:
        levelColor = Colors.brown.shade400;
        levelIcon = Icons.star;
    }

    return Card(
      elevation: 4,
      shadowColor: Colors.grey.withAlpha(50), // SỬA LỖI: Dùng withAlpha
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoadingMembership
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(levelIcon, color: levelColor, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'Hạng thành viên: $_membershipLevel',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: levelColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progressValue,
                      minHeight: 12,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _progressText,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
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
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(
                    userDocument: _currentUserDocument,
                  ),
                ),
              );
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
                    userDocument: _currentUserDocument,
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChangePasswordScreen(
                    userId: _currentUserDocument['_id'] as mongo.ObjectId,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildMenuItem(
            icon: Icons.logout,
            text: 'Đăng xuất',
            textColor: Colors.red,
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.grey.shade700),
      title: Text(text, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}