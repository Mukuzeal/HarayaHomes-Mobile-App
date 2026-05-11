import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme.dart';
import 'order_tracking_screen.dart';
import 'seller_store_screen.dart';

class OrdersScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const OrdersScreen({super.key, required this.user});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int get _userId => (widget.user['id'] as int?) ?? 0;

  List<dynamic> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await ApiService.getOrders(_userId);
    setState(() {
      _orders  = orders;
      _loading = false;
    });
  }

  String _img(dynamic order) {
    final raw = order['image_url'];
    if (raw is List && raw.isNotEmpty) {
      String p = raw[0].toString();
      if (!p.startsWith('http')) p = '${ApiService.baseUrl}$p';
      return p;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.background,
      appBar: AppBar(
        backgroundColor: HarayaColors.primary,
        foregroundColor: Colors.white,
        title: Text('My Orders',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: HarayaColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _orders.length,
                    itemBuilder: (_, i) => _OrderTile(
                      order:  _orders[i],
                      imgUrl: _img(_orders[i]),
                      user: widget.user,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderTrackingScreen(
                            orderId: _orders[i]['order_id'] as int,
                            user: widget.user,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No orders yet',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
        ]),
      );
}

class _OrderTile extends StatelessWidget {
  final dynamic order;
  final String imgUrl;
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  const _OrderTile({
    required this.order,
    required this.imgUrl,
    required this.user,
    required this.onTap,
  });

  static const _statusColors = {
    'pending':    Color(0xFFF57C00),
    'preparing':  Color(0xFF1976D2),
    'for_pickup': Color(0xFF7B1FA2),
    'shipped':    Color(0xFF0288D1),
    'delivered':  Color(0xFF388E3C),
    'canceled':   Color(0xFFD32F2F),
  };

  static const _payColors = {
    'paid':    Color(0xFF388E3C),
    'pending': Color(0xFFF57C00),
  };

  Color _statusColor(String s) =>
      _statusColors[s.toLowerCase()] ?? Colors.grey;

  Color _payColor(String s) =>
      _payColors[s.toLowerCase()] ?? Colors.grey;

  String _label(String raw) =>
      raw.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  @override
  Widget build(BuildContext context) {
    final price   = double.tryParse(order['total_amount'].toString()) ?? 0.0;
    final status  = (order['orderstatus']    ?? 'pending').toString();
    final payStatus = (order['payment_status'] ?? 'pending').toString();
    final name    = order['product_name'] ?? 'Product';
    final store   = order['store_name']   ?? '';
    final qty     = order['quantity']     ?? 1;
    final date    = (order['order_date']  ?? '').toString().substring(0, 10);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imgUrl.isNotEmpty
                ? Image.network(imgUrl, width: 64, height: 64, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SellerStoreScreen(
                      sellerId: order['store_id'] ?? 0,
                      sellerName: store,
                      user: user,
                    ),
                  ),
                );
              },
              child: Text(store,
                  style: GoogleFonts.poppins(fontSize: 11, color: HarayaColors.primary, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 6),
            Row(children: [
              _Badge(_label(status), _statusColor(status)),
              const SizedBox(width: 6),
              _Badge(_label(payStatus), _payColor(payStatus)),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Qty: $qty  ·  $date',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
              Text('₱${price.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, fontSize: 14, color: HarayaColors.error)),
            ]),
          ])),
        ]),
      ),
      ),
    );
  }

  Widget _placeholder() => Container(
      width: 64, height: 64, color: const Color(0xFFEEF3F8),
      child: const Icon(Icons.home_outlined, color: HarayaColors.primary, size: 28));
}

class _Badge extends StatelessWidget {
  final String text;
  final Color  color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      );
}
