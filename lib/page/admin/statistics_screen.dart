import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';  // Import cho fl_chart

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
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tổng quan chỉ số',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildOverviewBarChart(stats),
                const SizedBox(height: 24),
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

  Widget _buildOverviewBarChart(Map<String, dynamic> stats) {
    final barData = [
      {'title': 'Người\ndùng', 'value': (stats['totalUsers'] ?? 0).toDouble(), 'color': Colors.blue},
      {'title': 'Sản\nphẩm', 'value': (stats['totalProducts'] ?? 0).toDouble(), 'color': Colors.orange},
      {'title': 'Đơn\nhàng', 'value': (stats['totalOrders'] ?? 0).toDouble(), 'color': Colors.teal},
      {'title': 'Doanh thu\n(triệu)', 'value': ((stats['totalRevenue'] ?? 0) / 1000000).toDouble(), 'color': Colors.green},
    ];

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SizedBox(
          height: 380,  // Tăng chiều cao để biểu đồ cột rộng hơn
          child: BarChart(
            BarChartData(
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.white.withValues(alpha: 0.9),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final fullTitle = ['Người dùng', 'Sản phẩm', 'Đơn hàng', 'Doanh thu (triệu VNĐ)'][group.x];
                    return BarTooltipItem(
                      '$fullTitle\n${rod.toY}',
                      const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                    );
                  },
                ),
              ),
              barGroups: barData.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: data['value'] as double,
                      gradient: LinearGradient(
                        colors: [
                          (data['color'] as Color).withValues(alpha: 0.7),
                          data['color'] as Color
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: 28,
                      borderRadius: BorderRadius.circular(6),
                      backDrawRodData: BackgroundBarChartRodData(show: true, toY: 0, color: Colors.transparent),
                    ),
                  ],
                  barsSpace: 12,
                );
              }).toList(),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 80,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          barData[index]['title'] as String,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
            ),
            swapAnimationDuration: const Duration(milliseconds: 800),
            swapAnimationCurve: Curves.easeInOut,
          ),
        ),
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
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                color: color.withValues(alpha: 0.9),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  // Pie Chart: Xóa toàn bộ chữ trên biểu đồ, giữ note màu ở ngoài
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

    List<PieChartSectionData> pieSections = [];
    for (var key in statusMap.keys) {
      final count = statusCounts[key] ?? 0;
      pieSections.add(
        PieChartSectionData(
          color: statusColors[key]!,
          value: count.toDouble(),
          title: '',  // Xóa toàn bộ chữ trên biểu đồ
          radius: 120,
          showTitle: false,  // Đảm bảo không hiển thị title
        ),
      );
    }

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            SizedBox(
              height: 300,  // Giữ nguyên chiều cao của biểu đồ hình tròn
              child: PieChart(
                PieChartData(
                  sections: pieSections,
                  centerSpaceRadius: 50,
                  sectionsSpace: 2,
                  pieTouchData: PieTouchData(enabled: true),
                ),
                swapAnimationDuration: const Duration(milliseconds: 800),
                swapAnimationCurve: Curves.easeInOut,
              ),
            ),
            const SizedBox(height: 20),
            // Phần note màu ở ngoài
            const Text(
              'Chú thích màu:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...statusMap.keys.map((key) {
              return Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: statusColors[key],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(statusMap[key]!),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
