import 'package:doan_ltmobi/page/admin/user_management_screen.dart'; // Import màn hình mới
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
                // Điều hướng đến trang quản lý người dùng
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserManagementScreen()),
                );
              },
            ),
            _buildDashboardCard(
              context: context,
              icon: Icons.image_outlined,
              title: 'Quản lý Banner',
              color: Colors.green,
              onTap: () {
                // TODO: Thêm logic điều hướng đến trang quản lý banner
              },
            ),
             _buildDashboardCard(
              context: context,
              icon: Icons.category_outlined,
              title: 'Quản lý sản phẩm',
              color: Colors.orange,
              onTap: () {
                // TODO: Thêm logic điều hướng đến trang quản lý sản phẩm
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
