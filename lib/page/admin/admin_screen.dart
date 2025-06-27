// lib/page/admin/admin_screen.dart

import 'package:doan_ltmobi/page/admin/user_management_screen.dart';
import 'package:doan_ltmobi/page/admin/category_management_screen.dart';
import 'package:doan_ltmobi/page/admin/product_management_screen.dart';
// Import trang quản lý ưu đãi mới
import 'package:doan_ltmobi/page/admin/promotion_management_screen.dart';
import 'package:doan_ltmobi/page/login_screen.dart';
import 'package:flutter/material.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({Key? key}) : super(key: key);

  // Widget để tạo một thẻ chức năng
  Widget _buildDashboardCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang quản trị Admin'),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2, // Hiển thị 2 cột
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: <Widget>[
            _buildDashboardCard(
              context: context,
              icon: Icons.people_outline,
              title: 'Quản lý người dùng',
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserManagementScreen()),
                );
              },
            ),
             _buildDashboardCard(
              context: context,
              icon: Icons.category,
              title: 'Quản lý Danh Mục',
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CategoryManagementScreen()),
                );
              },
            ),
            // ===== THAY ĐỔI Ở ĐÂY =====
            _buildDashboardCard(
              context: context,
              icon: Icons.campaign_outlined, // Đổi icon cho phù hợp
              title: 'Quản lý Ưu đãi', // Đổi tên
              color: Colors.teal,
              onTap: () {
                // Điều hướng đến trang quản lý ưu đãi mới
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PromotionManagementScreen()),
                );
              },
            ),
             _buildDashboardCard(
              context: context,
              icon: Icons.shopping_bag_outlined,
              title: 'Quản lý sản phẩm',
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProductManagementScreen()),
                );
              },
            ),
             _buildDashboardCard(
              context: context,
              icon: Icons.bar_chart_outlined,
              title: 'Thống kê',
              color: Colors.purple,
              onTap: () {
                // TODO: Thêm logic điều hướng đến trang thống kê
              },
            ),
          ],
        ),
      ),
    );
  }
}