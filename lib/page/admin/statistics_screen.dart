// lib/page/admin/statistics_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<Map<String, dynamic>> _statsFuture;

  final NumberFormat currencyFormatter = NumberFormat('#,##0', 'vi_VN');
  static const Color primaryColor = Color(0xFFE57373);

  @override
  void initState() {
    super.initState();
    _statsFuture = _fetchStatistics();
  }

  Future<Map<String, dynamic>> _fetchStatistics() async {
    final results = await Future.wait([
      MongoDatabase.getTotalUsers(),
      MongoDatabase.getTotalProducts(),
      MongoDatabase.getTotalOrders(),
      MongoDatabase.getTotalRevenue(),
      MongoDatabase.getOrderStatusCounts(),
    ]);
    return {
      'totalUsers': results[0],
      'totalProducts': results[1],
      'totalOrders': results[2],
      'totalRevenue': results[3],
      'orderStatusCounts': results[4],
    };
  }

  void _refreshData() {
    setState(() {
      _statsFuture = _fetchStatistics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê & Báo cáo'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Làm mới dữ liệu',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Không có dữ liệu để hiển thị.'));
          }

          final stats = snapshot.data!;
          final orderStatusCounts = stats['orderStatusCounts'] as Map<String, int>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildStatsGrid(stats),
                const SizedBox(height: 24),
                _buildOrderStatusSection(orderStatusCounts),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: <Widget>[
        _buildStatCard(
          icon: Icons.people_alt_outlined,
          title: 'Người dùng',
          value: (stats['totalUsers'] ?? 0).toString(),
          color: Colors.blue,
        ),
        _buildStatCard(
          icon: Icons.inventory_2_outlined,
          title: 'Sản phẩm',
          value: (stats['totalProducts'] ?? 0).toString(),
          color: Colors.orange,
        ),
        _buildStatCard(
          icon: Icons.receipt_long_outlined,
          title: 'Đơn hàng',
          value: (stats['totalOrders'] ?? 0).toString(),
          color: Colors.teal,
        ),
        _buildStatCard(
          icon: Icons.monetization_on_outlined,
          title: 'Tổng doanh thu',
          value: '${currencyFormatter.format(stats['totalRevenue'] ?? 0)} VNĐ',
          color: Colors.green,
          isCurrency: true,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    bool isCurrency = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: isCurrency ? 18 : 24,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusSection(Map<String, int> statusCounts) {
    final statusMap = {
      'Pending': 'Đang xử lý',
      'Shipping': 'Đang giao',
      'Delivered': 'Đã giao',
      'Cancelled': 'Đã hủy',
    };
    final statusColors = {
      'Pending': Colors.orangeAccent,
      'Shipping': Colors.blueAccent,
      'Delivered': Colors.green,
      'Cancelled': Colors.red,
    };
    final total = statusCounts.values.fold(0, (sum, count) => sum + count);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phân loại đơn hàng',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...statusMap.keys.map((key) {
              final count = statusCounts[key] ?? 0;
              final percentage = total > 0 ? (count / total) * 100 : 0.0;
              return _buildOrderStatusRow(
                title: statusMap[key]!,
                count: count,
                percentage: percentage,
                color: statusColors[key]!,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusRow({
    required String title,
    required int count,
    required double percentage,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, color: color, size: 12),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                    const Spacer(),
                    Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: color.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}