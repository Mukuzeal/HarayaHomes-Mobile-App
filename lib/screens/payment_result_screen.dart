import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';
import 'orders_screen.dart';

class PaymentResultScreen extends StatefulWidget {
  final bool success;
  final String? message;
  final String? orderId;
  final Map<String, dynamic> user;

  const PaymentResultScreen({
    super.key,
    required this.success,
    this.message,
    this.orderId,
    required this.user,
  });

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _animationController.forward();

    // Auto-close after 3 seconds if successful
    if (widget.success) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.5),
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success/Failure Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: widget.success
                        ? HarayaColors.success.withValues(alpha: 0.1)
                        : HarayaColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.success ? Icons.check_circle : Icons.cancel,
                    size: 40,
                    color: widget.success ? HarayaColors.success : HarayaColors.error,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  widget.success ? 'Payment Successful!' : 'Payment Failed',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: widget.success ? HarayaColors.success : HarayaColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  widget.message ?? 
                  (widget.success 
                      ? 'Your order has been placed successfully!'
                      : 'There was an issue processing your payment.'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Order ID (if successful)
                if (widget.success && widget.orderId != null) ...[
                  Text(
                    'Order ID: ${widget.orderId}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else if (!widget.success) ...[
                  const SizedBox(height: 20),
                ],

                // Action Buttons
                if (widget.success) ...[
                  Row(
                    children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: HarayaColors.primary),
                            ),
                            child: Text(
                              'Continue Shopping',
                              style: GoogleFonts.poppins(
                                color: HarayaColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => OrdersScreen(user: widget.user),
                              ));
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: HarayaColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'View Orders',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'This will close automatically in 3 seconds',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ] else ...[
                  // Failure buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HarayaColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Try Again',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'Back to Home',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Helper function to show payment result popup
void showPaymentResult({
  required BuildContext context,
  required bool success,
  String? message,
  String? orderId,
  required Map<String, dynamic> user,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PaymentResultScreen(
      success: success,
      message: message,
      orderId: orderId,
      user: user,
    ),
  );
}
