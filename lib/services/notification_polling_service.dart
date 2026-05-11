import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';

class NotificationPollingService {
  static final NotificationPollingService _instance = NotificationPollingService._internal();
  late Timer _pollingTimer;
  late int _userId;
  bool _isRunning = false;

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  final ValueNotifier<List<dynamic>> notifications = ValueNotifier<List<dynamic>>([]);

  factory NotificationPollingService() {
    return _instance;
  }

  NotificationPollingService._internal();

  void start(int userId) {
    if (_isRunning) return;
    _userId = userId;
    _isRunning = true;
    pollNotifications(); // First poll immediately
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) => pollNotifications());
  }

  Future<void> pollNotifications() async {
    try {
      final notifs = await ApiService.getNotifications(_userId);
      notifications.value = notifs;
      final unread = notifs.where((n) => n['is_read'] == 0 || n['is_read'] == false).length;
      unreadCount.value = unread;
    } catch (e) {
      debugPrint('Notification poll error: $e');
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await ApiService.markNotificationRead(notificationId, _userId);
      pollNotifications();
    } catch (e) {
      debugPrint('Error marking notification read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await ApiService.markAllNotificationsRead(_userId);
      pollNotifications();
    } catch (e) {
      debugPrint('Error marking all read: $e');
    }
  }

  void stop() {
    if (_isRunning) {
      _pollingTimer.cancel();
      _isRunning = false;
    }
  }

  void dispose() {
    stop();
    unreadCount.dispose();
    notifications.dispose();
  }
}
