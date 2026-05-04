import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../screens/payment_result_screen.dart';

class PaymentResultService {
  static const String _pendingPaymentKey = 'pending_payment';
  static const String _paymentSessionKey = 'payment_session_id';

  /// Save payment session info before launching PayMongo
  static Future<void> savePendingPayment({
    required String sessionId,
    required int userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paymentSessionKey, sessionId);
    await prefs.setInt(_pendingPaymentKey, userId);
  }

  /// Check for pending payment result when app resumes
  static Future<void> checkPendingPaymentResult({
    required BuildContext context,
    required Map<String, dynamic> user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(_paymentSessionKey);
    final userId = prefs.getInt(_pendingPaymentKey);

    if (sessionId != null && userId != null) {
      try {
        // Check payment status
        final result = await ApiService.handlePaymentSuccess(sessionId, userId: userId);
        
        if (result['success'] == true) {
          // Payment successful - show success popup
          final orders = result['orders'] as List?;
          final orderId = orders?.isNotEmpty == true 
              ? orders![0]['order_id']?.toString() 
              : null;
          
          if (context.mounted) {
            showPaymentResult(
              context: context,
              success: true,
              message: result['message'] ?? 'Payment completed successfully!',
              orderId: orderId,
              user: user,
            );
          }
        } else {
          // Payment failed or still pending - don't show popup for pending
          final message = result['message']?.toLowerCase() ?? '';
          if (message.contains('no orders found') || message.contains('invalid')) {
            // Invalid session - clear it
            await clearPendingPayment();
          }
          // Don't show error popup for pending payments
        }
      } catch (e) {
        // Error checking payment - clear pending payment
        await clearPendingPayment();
        print('Error checking payment result: $e');
      }
    }
  }

  /// Clear pending payment info
  static Future<void> clearPendingPayment() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_paymentSessionKey);
    await prefs.remove(_pendingPaymentKey);
  }

  /// Check if there's a pending payment
  static Future<bool> hasPendingPayment() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_paymentSessionKey);
  }
}
