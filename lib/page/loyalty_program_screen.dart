// lib/page/loyalty_program_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
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

  @override
  void initState() {
    super.initState();
    _currentUserDocument = widget.userDocument;
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    final updatedUser = await MongoDatabase.userCollection.findOne(m.where.id(_currentUserDocument['_id']));
    
    if (updatedUser != null && mounted) {
      setState(() {
        _currentUserDocument = updatedUser;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật điểm của bạn!'), backgroundColor: Colors.green),
      );
    } else {
       if(mounted){
         setState(() {
            _isLoading = false;
         });
       }
    }
  }

  void _handleRedeem(int pointsToRedeem, double voucherValue) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đổi điểm'),
        content: Text('Bạn có chắc chắn muốn dùng $pointsToRedeem điểm để đổi lấy voucher ${NumberFormat('#,##0').format(voucherValue)} VNĐ không?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Đổi')),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await MongoDatabase.redeemPointsForVoucher(
      userId: _currentUserDocument['_id'],
      pointsToRedeem: pointsToRedeem,
      voucherValue: voucherValue,
    );

    if (mounted) {
      await _refreshData();

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
                  final voucherCode = message.substring(message.lastIndexOf(':') + 2);
                  Clipboard.setData(ClipboardData(text: voucherCode));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép mã voucher!')));
                },
                child: const Text('Sao chép mã'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int currentPoints = _currentUserDocument['loyaltyPoints'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khách hàng thân thiết'),
        backgroundColor: Colors.amber[700],
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.only(right: 20.0),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
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
            decoration: BoxDecoration(
              color: Colors.amber[700],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Điểm tích lũy của bạn',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 10),
                Text(
                  NumberFormat('#,##0').format(currentPoints),
                  style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  '1,000 VNĐ chi tiêu = 1 điểm',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Đổi thưởng',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          _buildRedeemOption(
            points: 500,
            voucherValue: 50000,
            icon: Icons.card_giftcard,
            color: Colors.teal,
            currentPoints: currentPoints,
          ),
          _buildRedeemOption(
            points: 1000,
            voucherValue: 120000,
            icon: Icons.confirmation_number,
            color: Colors.blueAccent,
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
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Bạn chưa có lịch sử tích điểm.'));
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
                      // SỬA LỖI: Thêm .toLocal() để chuyển sang múi giờ Việt Nam
                      subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format((item['date'] as DateTime).toLocal())),
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

  Widget _buildRedeemOption({
    required int points,
    required double voucherValue,
    required IconData icon,
    required Color color,
    required int currentPoints
  }) {
    bool canRedeem = currentPoints >= points;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text('Voucher ${NumberFormat('#,##0').format(voucherValue)} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Dùng ${NumberFormat('#,##0').format(points)} điểm'),
        trailing: ElevatedButton(
          onPressed: canRedeem ? () => _handleRedeem(points, voucherValue) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: const Text('Đổi'),
        ),
      ),
    );
  }
}