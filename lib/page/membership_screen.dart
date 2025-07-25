// lib/page/membership_screen.dart

import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class MembershipScreen extends StatefulWidget {
  final Map<String, dynamic> userDocument;

  const MembershipScreen({
    super.key,
    required this.userDocument,
  });

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  String _membershipLevel = 'Đồng';
  String _progressText = '';
  double _progressValue = 0.0;
  bool _isLoadingMembership = true;
  final _currencyFormatter = NumberFormat('#,##0', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _loadMembershipData();
  }

  // Cập nhật logic tính toán cho các hạng mới
  Future<void> _loadMembershipData() async {
    if (!mounted) return;
    setState(() => _isLoadingMembership = true);

    final userId = widget.userDocument['_id'] as mongo.ObjectId;
    final totalSpending = await MongoDatabase.getUserTotalSpending(userId);
    final membership = MongoDatabase.getMembershipLevel(totalSpending);

    double amountNeeded = 0;
    double progressValue = 0;
    String progressText = '';

    const silverThreshold = 3000000.0;
    const goldThreshold = 5000000.0;
    const platinumThreshold = 15000000.0;
    const diamondThreshold = 30000000.0;

    String currentLevel = membership['level'];

    switch (currentLevel) {
      case 'Kim Cương':
        progressText = 'Bạn đã đạt hạng thành viên cao nhất!';
        progressValue = 1.0;
        break;
      case 'Bạch Kim':
        amountNeeded = diamondThreshold - totalSpending;
        progressValue = (totalSpending - platinumThreshold) /
            (diamondThreshold - platinumThreshold);
        progressText =
            'Chi tiêu thêm ${_currencyFormatter.format(amountNeeded)} VNĐ để lên hạng Kim Cương.';
        break;
      case 'Vàng':
        amountNeeded = platinumThreshold - totalSpending;
        progressValue =
            (totalSpending - goldThreshold) / (platinumThreshold - goldThreshold);
        progressText =
            'Chi tiêu thêm ${_currencyFormatter.format(amountNeeded)} VNĐ để lên hạng Bạch Kim.';
        break;
      case 'Bạc':
        amountNeeded = goldThreshold - totalSpending;
        progressValue =
            (totalSpending - silverThreshold) / (goldThreshold - silverThreshold);
        progressText =
            'Chi tiêu thêm ${_currencyFormatter.format(amountNeeded)} VNĐ để lên hạng Vàng.';
        break;
      default: // Đồng
        amountNeeded = silverThreshold - totalSpending;
        progressValue = totalSpending / silverThreshold;
        progressText =
            'Chi tiêu thêm ${_currencyFormatter.format(amountNeeded)} VNĐ để lên hạng Bạc.';
    }

    if (mounted) {
      setState(() {
        _membershipLevel = currentLevel;
        _progressText = progressText;
        _progressValue = progressValue.clamp(0.0, 1.0);
        _isLoadingMembership = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hạng thành viên'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _isLoadingMembership
            ? const Center(
                child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator()))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentStatusCard(),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Quyền lợi các hạng',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildBenefitCard(
                    icon: Icons.shield_outlined,
                    levelName: 'Thành viên Bạc',
                    levelColor: Colors.blueGrey.shade400,
                    requirement: 'Chi tiêu tích lũy đạt 3.000.000 VNĐ',
                    benefit: 'Giảm giá 5% cho tất cả đơn hàng',
                  ),
                  const SizedBox(height: 12),
                  _buildBenefitCard(
                    icon: Icons.star_border_purple500_outlined,
                    levelName: 'Thành viên Vàng',
                    levelColor: Colors.amber.shade700,
                    requirement: 'Chi tiêu tích lũy đạt 5.000.000 VNĐ',
                    benefit: 'Giảm giá 10% cho tất cả đơn hàng',
                  ),
                  const SizedBox(height: 12),
                  _buildBenefitCard(
                    icon: Icons.diamond_outlined,
                    levelName: 'Thành viên Bạch Kim',
                    levelColor: Colors.teal,
                    requirement: 'Chi tiêu tích lũy đạt 15.000.000 VNĐ',
                    benefit: 'Giảm giá 15% cho tất cả đơn hàng',
                  ),
                  const SizedBox(height: 12),
                  _buildBenefitCard(
                    icon: Icons.workspace_premium_outlined,
                    levelName: 'Thành viên Kim Cương',
                    levelColor: Colors.purple,
                    requirement: 'Chi tiêu tích lũy đạt 30.000.000 VNĐ',
                    benefit: 'Giảm giá 20% cho tất cả đơn hàng',
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBenefitCard({
    required IconData icon,
    required String levelName,
    required Color levelColor,
    required String requirement,
    required String benefit,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: levelColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  levelName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: levelColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              requirement,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              benefit,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusCard() {
    Color levelColor;
    Color gradientStartColor;
    Color gradientEndColor;
    IconData levelIcon;

    switch (_membershipLevel) {
      case 'Kim Cương':
        levelColor = Colors.purple;
        gradientStartColor = const Color(0xFFF3E5F5);
        gradientEndColor = const Color(0xFFE1BEE7);
        levelIcon = Icons.workspace_premium;
        break;
      case 'Bạch Kim':
        levelColor = Colors.teal;
        gradientStartColor = const Color(0xFFE0F2F1);
        gradientEndColor = const Color(0xFFB2DFDB);
        levelIcon = Icons.diamond;
        break;
      case 'Vàng':
        levelColor = Colors.amber.shade800;
        gradientStartColor = const Color(0xFFFFF8E1);
        gradientEndColor = const Color(0xFFFFECB3);
        levelIcon = Icons.star;
        break;
      case 'Bạc':
        levelColor = Colors.blueGrey.shade600;
        gradientStartColor = const Color(0xFFECEFF1);
        gradientEndColor = const Color(0xFFCFD8DC);
        levelIcon = Icons.shield;
        break;
      default:
        levelColor = Colors.brown.shade400;
        gradientStartColor = const Color(0xFFEFEBE9);
        gradientEndColor = const Color(0xFFFBF9F8);
        levelIcon = Icons.card_membership;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStartColor, gradientEndColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: levelColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(levelIcon, color: levelColor, size: 30),
              const SizedBox(width: 12),
              Text(
                'Hạng của bạn: $_membershipLevel',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: levelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progressValue,
              minHeight: 12,
              backgroundColor: Colors.black.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(levelColor),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              _progressText,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}