// lib/page/loyalty_program_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as m;

class LoyaltyProgramScreen extends StatefulWidget {
  final Map<String, dynamic> userDocument;

  const LoyaltyProgramScreen({super.key, required this.userDocument});

  @override
  State<LoyaltyProgramScreen> createState() => _LoyaltyProgramScreenState();
}

class _LoyaltyProgramScreenState extends State<LoyaltyProgramScreen> {
  late Map<String, dynamic> _currentUserDocument;
  bool _isLoading = false;

  static const Color primaryLoyaltyColor = Color(0xFFE91E63);
  static const Color lightPinkBackground = Color(0xFFFCE4EC);

  @override
  void initState() {
    super.initState();
    _currentUserDocument = widget.userDocument;
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    final updatedUser = await MongoDatabase.userCollection
        .findOne(m.where.id(_currentUserDocument['_id']));

    if (mounted) {
      if (updatedUser != null) {
        setState(() {
          _currentUserDocument = updatedUser;
        });
      }
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đã cập nhật điểm của bạn!'),
            backgroundColor: Colors.green),
      );
    }
  }

  void _handleRedeem(int pointsToRedeem, double voucherValue) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đổi điểm'),
        content: Text(
            'Bạn có chắc chắn muốn dùng $pointsToRedeem điểm để đổi lấy voucher ${NumberFormat('#,##0').format(voucherValue)} VNĐ không?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child:
                  const Text('Đổi', style: TextStyle(color: primaryLoyaltyColor))),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await MongoDatabase.redeemPointsForVoucher(
      userId: _currentUserDocument['_id'],
      pointsToRedeem: pointsToRedeem,
      voucherValue: voucherValue,
    );

    await _refreshData();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result['success'] == true ? 'Thành công' : 'Thất bại'),
        content: Text(result['message']),
        actions: [
          if (result['success'] == true)
            TextButton(
              onPressed: () {
                final message = result['message'] as String;
                final voucherCode =
                    message.substring(message.lastIndexOf(':') + 2);
                Clipboard.setData(ClipboardData(text: voucherCode));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép mã voucher!')));
              },
              child: const Text('Sao chép mã',
                  style: TextStyle(color: primaryLoyaltyColor)),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: primaryLoyaltyColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int currentPoints = _currentUserDocument['loyaltyPoints'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Khách hàng thân thiết'),
        backgroundColor: primaryLoyaltyColor,
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.only(right: 20.0),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3)),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshData,
                  tooltip: 'Cập nhật điểm',
                ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30),
            decoration: const BoxDecoration(
              color: lightPinkBackground,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(35),
                bottomRight: Radius.circular(35),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Điểm tích lũy của bạn',
                  style: TextStyle(color: Colors.black54, fontSize: 18),
                ),
                const SizedBox(height: 10),
                Text(
                  NumberFormat('#,##0').format(currentPoints),
                  style: const TextStyle(
                      color: primaryLoyaltyColor,
                      fontSize: 48,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  '1,000 VNĐ chi tiêu = 1 điểm',
                  style: TextStyle(color: Colors.black54, fontSize: 16),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Đổi thưởng',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          
          _buildRedeemOption(
            points: 500,
            voucherValue: 50000,
            icon: Icons.card_giftcard,
            currentPoints: currentPoints,
          ),
          _buildRedeemOption(
            points: 1000,
            voucherValue: 120000,
            icon: Icons.confirmation_number,
            currentPoints: currentPoints,
          ),
          
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Lịch sử điểm',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: MongoDatabase.getPointHistory(_currentUserDocument['_id']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: primaryLoyaltyColor));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('Bạn chưa có lịch sử tích điểm.'));
                }
                var history = snapshot.data!;
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    var item = history[index];
                    bool isEarned = item['type'] == 'earned';
                    return ListTile(
                      leading: Icon(
                        isEarned ? Icons.add_circle : Icons.remove_circle,
                        color: isEarned ? Colors.green : Colors.red,
                      ),
                      title: Text(item['description']),
                      subtitle: Text(DateFormat('dd/MM/yyyy HH:mm')
                          .format((item['date'] as DateTime).toLocal())),
                      trailing: Text(
                        '${isEarned ? '+' : ''}${item['points']}',
                        style: TextStyle(
                          color: isEarned ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // SỬA ĐỔI: Widget đổi thưởng được thiết kế lại để có màu đồng nhất
  Widget _buildRedeemOption({
    required int points,
    required double voucherValue,
    required IconData icon,
    required int currentPoints,
  }) {
    bool canRedeem = currentPoints >= points;
    
    // Dải màu gradient đồng nhất cho các thẻ có thể đổi
    final List<Color> activeGradient = [const Color(0xFFF06292), const Color(0xFFD81B60)];
    final List<Color> disabledGradient = [Colors.grey.shade400, Colors.grey.shade500];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: canRedeem ? activeGradient : disabledGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: canRedeem ? [
            BoxShadow(
              color: primaryLoyaltyColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canRedeem ? () => _handleRedeem(points, voucherValue) : null,
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 36),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voucher ${NumberFormat('#,##0').format(voucherValue)} VNĐ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dùng ${NumberFormat('#,##0').format(points)} điểm',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canRedeem)
                    const Icon(Icons.arrow_forward_ios, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}