// lib/page/add_review_dialog.dart
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:elegant_notification/elegant_notification.dart';

class AddReviewDialog extends StatefulWidget {
  final Map<String, dynamic> userDocument;
  final Map<String, dynamic> product; // Sản phẩm trong đơn hàng
  final mongo.ObjectId orderId;

  const AddReviewDialog({
    super.key,
    required this.userDocument,
    required this.product,
    required this.orderId,
  });

  @override
  State<AddReviewDialog> createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends State<AddReviewDialog> {
  double _rating = 5.0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  void _submitReview() async {
    if (_commentController.text.trim().isEmpty) {
      ElegantNotification.error(
        title: const Text("Lỗi"),
        description: const Text("Vui lòng viết nhận xét của bạn."),
      ).show(context);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final reviewData = {
        '_id': mongo.ObjectId(),
        'productId': widget.product['productId'],
        'userId': widget.userDocument['_id'],
        'userName': widget.userDocument['email']?.split('@').first ?? 'Người dùng ẩn danh',
        'userAvatar': widget.userDocument['profile_image_base64'] ?? '',
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'createdAt': DateTime.now(),
      };

      // 1. Gửi đánh giá lên DB
      await MongoDatabase.addReview(reviewData);
      
      // 2. Đánh dấu sản phẩm này đã được đánh giá trong đơn hàng
      await MongoDatabase.markProductAsReviewedInOrder(widget.orderId, widget.product['productId']);

      if (mounted) {
        ElegantNotification.success(
          title: const Text("Thành công"),
          description: const Text("Cảm ơn bạn đã gửi đánh giá!"),
        ).show(context);
        Navigator.pop(context, true); // Trả về true để báo hiệu thành công
      }
    } catch (e) {
      if (mounted) {
        ElegantNotification.error(
          title: const Text("Lỗi"),
          description: Text("Không thể gửi đánh giá: $e"),
        ).show(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text('Viết đánh giá'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.product['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Bạn đánh giá sản phẩm này thế nào?'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () => setState(() => _rating = index + 1.0),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Hãy chia sẻ cảm nhận của bạn về sản phẩm...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReview,
          child: _isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,))
              : const Text('Gửi đánh giá'),
        ),
      ],
    );
  }
}