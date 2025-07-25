// lib/page/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:doan_ltmobi/dpHelper/mongodb.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as m;

class NotificationsScreen extends StatefulWidget {
  final m.ObjectId userId;

  const NotificationsScreen({super.key, required this.userId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    setState(() {
      _notificationsFuture = MongoDatabase.getNotificationsForUser(widget.userId);
    });
  }

  Future<void> _markAllAsRead() async {
    await MongoDatabase.markAllAsRead(widget.userId);
    _loadNotifications(); // Tải lại danh sách để cập nhật UI
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'order_status':
        return Icons.local_shipping_outlined;
      case 'promotion':
        return Icons.campaign_outlined;
      case 'account':
        return Icons.person_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text(
              'Đánh dấu đã đọc',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadNotifications();
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'Bạn không có thông báo nào.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }
            final notifications = snapshot.data!;
            return ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final bool isRead = notification['isRead'] ?? false;

                return InkWell(
                  onTap: () async {
                    if (!isRead) {
                      await MongoDatabase.markAsRead(notification['_id']);
                      _loadNotifications();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: isRead ? Colors.white : Colors.blue.shade50,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _getIconForType(notification['type']),
                          color: Theme.of(context).primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification['title'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isRead ? Colors.black87 : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notification['body'],
                                style: TextStyle(
                                  color: isRead ? Colors.grey.shade600 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                DateFormat('dd/MM/yyyy HH:mm').format(
                                  (notification['createdAt'] as DateTime).toLocal(),
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isRead)
                          Container(
                            margin: const EdgeInsets.only(left: 12, top: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                          )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}