import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notification_polling_service.dart';
import '../theme.dart';
import '../widgets/haraya_widgets.dart';
import 'order_tracking_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const NotificationsScreen({super.key, required this.user});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationPollingService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationPollingService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.background,
      appBar: AppBar(
        backgroundColor: HarayaColors.primary,
        foregroundColor: Colors.white,
        title: Text('Notifications', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await _notificationService.markAllAsRead();
              if (mounted) showHarayaSnackBar(context, 'All marked as read');
            },
            icon: const Icon(Icons.done_all, color: Colors.white, size: 18),
            label: Text('Mark All', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<dynamic>>(
        valueListenable: _notificationService.notifications,
        builder: (context, notifications, _) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_none_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('No notifications yet',
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _notificationService.pollNotifications(),
            color: HarayaColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: notifications.length,
              itemBuilder: (_, i) => _NotificationTile(
                notification: notifications[i],
                user: widget.user,
                onMarkRead: () => _notificationService.markAsRead(notifications[i]['notification_id'] as int),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final Map<String, dynamic> user;
  final VoidCallback onMarkRead;

  const _NotificationTile({
    required this.notification,
    required this.user,
    required this.onMarkRead,
  });

  IconData _getIcon(String type) {
    switch (type) {
      case 'new_order':
        return Icons.shopping_bag_outlined;
      case 'payment_verified':
      case 'payment_rejected':
        return Icons.payment;
      case 'rider_assigned':
        return Icons.two_wheeler;
      case 'delivery_proof_uploaded':
        return Icons.check_circle_outline;
      case 'order_delivered_seller':
        return Icons.local_shipping;
      case 'order_completed':
        return Icons.done_all;
      case 'payment_released':
        return Icons.account_balance_wallet;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'payment_rejected':
        return Colors.red;
      case 'payment_verified':
      case 'order_completed':
        return HarayaColors.success;
      case 'rider_assigned':
      case 'delivery_proof_uploaded':
        return Colors.blue;
      default:
        return HarayaColors.primary;
    }
  }

  void _handleTap(BuildContext context) {
    onMarkRead();
    final orderId = notification['order_id'];
    if (orderId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(
            orderId: orderId as int,
            user: user,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = notification['is_read'] == 1 || notification['is_read'] == true;
    final createdAt = notification['created_at'] ?? '';
    final relativeTime = _getRelativeTime(createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isRead ? Colors.white : Colors.blue.shade50,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getIconColor(notification['type'] ?? '').withValues(alpha: 0.1),
          ),
          child: Icon(_getIcon(notification['type'] ?? ''),
              color: _getIconColor(notification['type'] ?? ''), size: 24),
        ),
        title: Text(notification['title'] ?? 'Notification',
            style: GoogleFonts.poppins(
                fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                fontSize: 13)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification['message'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            Text(relativeTime, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
        trailing: !isRead
            ? Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HarayaColors.primary,
                ),
              )
            : null,
        onTap: () => _handleTap(context),
      ),
    );
  }

  String _getRelativeTime(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.month}/${date.day}/${date.year}';
      }
    } catch (_) {
      return dateStr;
    }
  }
}
