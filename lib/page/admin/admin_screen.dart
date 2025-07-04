// lib/page/admin/admin_screen.dart

import 'package:doan_ltmobi/page/admin/user_management_screen.dart';
import 'package:doan_ltmobi/page/admin/category_management_screen.dart';
import 'package:doan_ltmobi/page/admin/product_management_screen.dart';
import 'package:doan_ltmobi/page/admin/promotion_management_screen.dart';
import 'package:doan_ltmobi/page/admin/order_management_screen.dart';
import 'package:doan_ltmobi/page/login_screen.dart';
import 'package:flutter/material.dart';
import 'voucher_management_screen.dart'; // <-- THÊM MỚI

class AdminScreen extends StatelessWidget {
  const AdminScreen({Key? key}) : super(key: key);

  Widget _buildDashboardCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang quản trị'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
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
                  MaterialPageRoute(
                      builder: (context) => const UserManagementScreen()),
                );
              },
            ),
            _buildDashboardCard(
              context: context,
              icon: Icons.category_outlined,
              title: 'Quản lý danh mục',
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CategoryManagementScreen()),
                );
              },
            ),
            _buildDashboardCard(
              context: context,
              icon: Icons.inventory_2_outlined,
              title: 'Quản lý sản phẩm',
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProductManagementScreen()),
                );
              },
            ),
            _buildDashboardCard(
              context: context,
              icon: Icons.campaign_outlined,
              title: 'Quản lý khuyến mãi',
              color: Colors.red,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PromotionManagementScreen()),
                );
              },
            ),
            _buildDashboardCard(
              context: context,
              icon: Icons.receipt_long_outlined,
              title: 'Quản lý đơn hàng',
              color: Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const OrderManagementScreen()),
                );
              },
            ),
            _buildDashboardCard( // <-- THÊM CARD MỚI
              context: context,
              icon: Icons.local_offer_outlined,
              title: 'Quản lý Voucher',
              color: Colors.deepPurple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VoucherManagementScreen()),
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