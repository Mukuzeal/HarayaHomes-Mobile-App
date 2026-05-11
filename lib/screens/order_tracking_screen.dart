import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/haraya_widgets.dart';

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;
  final Map<String, dynamic> user;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.user,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Future<Map<String, dynamic>> _orderDetailFuture;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _orderDetailFuture = ApiService.getOrderDetail(widget.orderId);
  }

  Future<void> _confirmReceipt(Map<String, dynamic> order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm Receipt',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Confirm that you have received this order. Payment will be released to the seller and rider.',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _confirming = true);
    try {
      final result = await ApiService.confirmOrderReceived((widget.user['id'] as int?) ?? 0, widget.orderId);
      if (!mounted) return;
      if (result['success'] == true) {
        showHarayaSnackBar(context, 'Order confirmed! Thank you for shopping with us.');
        setState(() => _orderDetailFuture = ApiService.getOrderDetail(widget.orderId));
      } else {
        showHarayaSnackBar(context, result['message'] ?? 'Failed to confirm order', isError: true);
      }
    } catch (e) {
      if (mounted) showHarayaSnackBar(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.background,
      appBar: AppBar(
        backgroundColor: HarayaColors.primary,
        foregroundColor: Colors.white,
        title: Text('Order Tracking', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _orderDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null || snapshot.data!['error'] != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Failed to load order details',
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _orderDetailFuture = ApiService.getOrderDetail(widget.orderId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final order = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order header
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Order #${order['order_id']}',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _statusColor(order['orderstatus']),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(_statusLabel(order['orderstatus']),
                                  style: GoogleFonts.poppins(
                                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(order['product_name'] ?? 'Product',
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('₱${(order['total_amount'] ?? 0).toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: HarayaColors.error)),
                            Text('Ordered: ${_formatDate(order['order_date'])}',
                                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Timeline
                Text('Delivery Progress', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 16),
                _buildTimeline(order),
                const SizedBox(height: 24),

                // Delivery proof if available
                if (order['delivery_photo'] != null) ...[
                  Text('Proof of Delivery', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      '${ApiService.baseUrl}/${order['delivery_photo']}',
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Rider info
                if (order['rider_fname'] != null) ...[
                  Text('Delivery Personnel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${order['rider_fname']} ${order['rider_lname']}',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(order['vehicle_type'] ?? 'Vehicle',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                          if (order['rider_email'] != null) ...[
                            const SizedBox(height: 4),
                            Text(order['rider_email'],
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Confirm receipt button
                if (order['orderstatus'] == 'pending_buyer_confirmation') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirming ? null : () => _confirmReceipt(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HarayaColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _confirming
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Order Received',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white)),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeline(Map<String, dynamic> order) {
    final steps = [
      ('Order Placed', 'order_placed', order['order_date']),
      ('Payment Verified', 'payment_verified', order['payment_status'] == 'paid' ? 'done' : null),
      ('Seller Accepted', 'seller_accepted', _contains(order['orderstatus'], ['preparing', 'for_pickup', 'shipped', 'delivered', 'pending_buyer_confirmation', 'completed']) ? 'done' : null),
      ('Ready for Pickup', 'ready_pickup', _contains(order['orderstatus'], ['for_pickup', 'shipped', 'delivered', 'pending_buyer_confirmation', 'completed']) ? 'done' : null),
      ('Rider Assigned', 'rider_assigned', _contains(order['orderstatus'], ['shipped', 'delivered', 'pending_buyer_confirmation', 'completed']) ? 'done' : null),
      ('Out for Delivery', 'out_delivery', _contains(order['orderstatus'], ['shipped', 'delivered', 'pending_buyer_confirmation', 'completed']) ? 'done' : null),
      ('Delivered', 'delivered', _contains(order['orderstatus'], ['delivered', 'pending_buyer_confirmation', 'completed']) ? 'done' : null),
      ('Awaiting Confirmation', 'awaiting_confirm', order['orderstatus'] == 'pending_buyer_confirmation' ? 'current' : null),
      ('Completed', 'completed', order['orderstatus'] == 'completed' ? 'done' : null),
    ];

    return Column(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _buildTimelineStep(
            label: steps[i].$1,
            status: steps[i].$3,
            isLast: i == steps.length - 1,
          ),
        ],
      ],
    );
  }

  Widget _buildTimelineStep({
    required String label,
    required String? status,
    required bool isLast,
  }) {
    final isDone = status == 'done';
    final isCurrent = status == 'current';
    final isFuture = status == null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? HarayaColors.success : isCurrent ? HarayaColors.primary : Colors.grey.shade300,
              ),
              child: Icon(
                isDone ? Icons.check : isCurrent ? Icons.schedule : Icons.circle_outlined,
                color: isDone || isCurrent ? Colors.white : Colors.grey,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isDone ? HarayaColors.success : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                color: isFuture ? Colors.grey : Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _contains(String? status, List<String> values) {
    return status != null && values.contains(status);
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'completed':
        return HarayaColors.success;
      case 'pending_buyer_confirmation':
        return Colors.amber;
      case 'shipped':
      case 'delivered':
        return Colors.blue;
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'preparing':
        return 'Preparing';
      case 'for_pickup':
        return 'Ready for Pickup';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'pending_buyer_confirmation':
        return 'Awaiting Your Confirmation';
      case 'completed':
        return 'Completed';
      case 'canceled':
        return 'Canceled';
      default:
        return status ?? 'Unknown';
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    final dateStr = date.toString();
    try {
      final parsed = DateTime.parse(dateStr);
      return '${parsed.month}/${parsed.day}/${parsed.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
