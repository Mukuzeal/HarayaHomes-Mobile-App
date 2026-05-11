import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/haraya_widgets.dart';

class SellerOrdersScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const SellerOrdersScreen({super.key, required this.user});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int get _userId => (widget.user['id'] as int?) ?? 0;

  List<dynamic> _all = [];
  bool _loading = true;

  List<dynamic> get _pending       => _all.where((o) => o['orderstatus'] == 'pending').toList();
  List<dynamic> get _preparing     => _all.where((o) => o['orderstatus'] == 'preparing').toList();
  List<dynamic> get _riderRequests => _all.where((o) => o['orderstatus'] == 'rider_requested').toList();
  List<dynamic> get _shipping      => _all.where((o) =>
      o['orderstatus'] == 'for_pickup' || o['orderstatus'] == 'shipped').toList();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiService.getSellerOrders(_userId);
    if (mounted) setState(() { _all = data; _loading = false; });
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _accept(int orderId) async {
    final res = await ApiService.sellerAcceptOrder(_userId, orderId);
    if (!mounted) return;
    if (res['success'] == true) {
      showHarayaSnackBar(context, 'Order accepted — now preparing.');
      _load();
    } else {
      showHarayaSnackBar(context, res['message'] ?? 'Failed.', isError: true);
    }
  }

  Future<void> _reject(int orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reject order #$orderId?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('The order will be canceled and the buyer notified.',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final res = await ApiService.sellerRejectOrder(_userId, orderId);
    if (!mounted) return;
    if (res['success'] == true) {
      showHarayaSnackBar(context, 'Order rejected.');
      _load();
    } else {
      showHarayaSnackBar(context, res['message'] ?? 'Failed.', isError: true);
    }
  }

  Future<void> _markReady(int orderId) async {
    final res = await ApiService.sellerMarkReady(_userId, orderId);
    if (!mounted) return;
    if (res['success'] == true) {
      showHarayaSnackBar(context, 'Order marked ready for pickup!');
      _load();
    } else {
      showHarayaSnackBar(context, res['message'] ?? 'Failed.', isError: true);
    }
  }

  Future<void> _approveRider(int orderId) async {
    final res = await ApiService.sellerApproveRider(_userId, orderId);
    if (!mounted) return;
    if (res['success'] == true) {
      showHarayaSnackBar(context, 'Rider approved — delivery started!');
      _load();
    } else {
      showHarayaSnackBar(context, res['message'] ?? 'Failed.', isError: true);
    }
  }

  Future<void> _rejectRider(int orderId, String riderName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reject $riderName?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Order #$orderId returns to the available pool.',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject Rider')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final res = await ApiService.sellerRejectRider(_userId, orderId);
    if (!mounted) return;
    if (res['success'] == true) {
      showHarayaSnackBar(context, 'Rider rejected — order back in pool.');
      _load();
    } else {
      showHarayaSnackBar(context, res['message'] ?? 'Failed.', isError: true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.background,
      appBar: AppBar(
        title: Text('My Orders',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: HarayaColors.primary,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              labelColor: HarayaColors.primary,
              unselectedLabelColor: const Color(0xFF888888),
              indicatorColor: HarayaColors.primary,
              indicatorWeight: 3,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
              tabs: [
                _tab('New', _pending.length),
                _tab('Preparing', _preparing.length),
                _tab('Rider Req.', _riderRequests.length, color: Colors.orange),
                _tab('Shipping', _shipping.length, color: const Color(0xFF388E3C)),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: HarayaColors.primary,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildList(_pending, _buildPendingCard),
                  _buildList(_preparing, _buildPreparingCard),
                  _buildList(_riderRequests, _buildRiderRequestCard),
                  _buildList(_shipping, _buildShippingCard),
                ],
              ),
            ),
    );
  }

  Tab _tab(String label, int count, {Color? color}) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: (color ?? HarayaColors.primary).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color ?? HarayaColors.primary)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(List<dynamic> items, Widget Function(dynamic) builder) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_rounded, size: 64, color: Color(0xFFCCCCCC)),
            const SizedBox(height: 12),
            Text('Nothing here',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: const Color(0xFF888888))),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (_, i) => builder(items[i]),
    );
  }

  // ── Tab 0: New (pending) ──────────────────────────────────────────────────
  Widget _buildPendingCard(dynamic o) {
    return _OrderCard(
      order: o,
      statusLabel: 'New Order',
      statusColor: HarayaColors.primary,
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _reject(o['order_id'] as int),
              icon: const Icon(Icons.close_rounded, size: 15),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 10)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => _accept(o['order_id'] as int),
              icon: const Icon(Icons.check_rounded, size: 15),
              label: const Text('Accept Order'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Preparing ──────────────────────────────────────────────────────
  Widget _buildPreparingCard(dynamic o) {
    return _OrderCard(
      order: o,
      statusLabel: 'Preparing',
      statusColor: const Color(0xFFF57C00),
      actions: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _markReady(o['order_id'] as int),
          icon: const Icon(Icons.storefront_rounded, size: 16),
          label: const Text('Mark Ready for Pickup'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF57C00),
              padding: const EdgeInsets.symmetric(vertical: 11)),
        ),
      ),
    );
  }

  // ── Tab 2: Rider Requests ─────────────────────────────────────────────────
  Widget _buildRiderRequestCard(dynamic o) {
    final riderName = o['rider_name'] ?? '—';
    final vehicle   = o['vehicle_type'] ?? '—';
    return _OrderCard(
      order: o,
      statusLabel: 'Rider Request',
      statusColor: Colors.orange,
      extraContent: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: HarayaColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.two_wheeler_rounded,
                  color: HarayaColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(riderName,
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(vehicle,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: const Color(0xFF888888))),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _rejectRider(o['order_id'] as int, riderName),
              icon: const Icon(Icons.close_rounded, size: 15),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 10)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => _approveRider(o['order_id'] as int),
              icon: const Icon(Icons.check_rounded, size: 15),
              label: const Text('Approve Rider'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF388E3C),
                  padding: const EdgeInsets.symmetric(vertical: 10)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Shipping (for_pickup / shipped) ────────────────────────────────
  Widget _buildShippingCard(dynamic o) {
    final status = o['orderstatus'] as String;
    final isShipped = status == 'shipped';
    return _OrderCard(
      order: o,
      statusLabel: isShipped ? 'Out for Delivery' : 'Waiting for Rider',
      statusColor: isShipped ? const Color(0xFF388E3C) : HarayaColors.primary,
      actions: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isShipped ? Icons.local_shipping_rounded : Icons.hourglass_top_rounded,
              size: 16,
              color: const Color(0xFF888888),
            ),
            const SizedBox(width: 8),
            Text(
              isShipped ? 'Rider is on the way' : 'Awaiting rider pickup',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: const Color(0xFF888888)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared card widget ─────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final dynamic order;
  final String statusLabel;
  final Color statusColor;
  final Widget actions;
  final Widget? extraContent;

  const _OrderCard({
    required this.order,
    required this.statusLabel,
    required this.statusColor,
    required this.actions,
    this.extraContent,
  });

  @override
  Widget build(BuildContext context) {
    final fee = (order['shipping_fee'] as num?)?.toStringAsFixed(2) ?? '0.00';
    final total = (order['total_amount'] as num?)?.toStringAsFixed(2) ?? '0.00';
    final payType = order['payment_type'] ?? '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusLabel,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor)),
                ),
                const Spacer(),
                Text('Order #${order['order_id']}',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: const Color(0xFF888888))),
              ],
            ),
            const SizedBox(height: 12),

            _Row(icon: Icons.inventory_2_rounded, label: order['product_name'] ?? '—'),
            const SizedBox(height: 4),
            _Row(icon: Icons.person_rounded, label: order['customer_name'] ?? '—'),
            const SizedBox(height: 4),
            _Row(icon: Icons.location_on_rounded,
                label: order['delivery_address'] ?? '—', maxLines: 2),

            const Divider(height: 18),

            // Payment info
            Row(
              children: [
                _Chip(
                  label: payType,
                  icon: payType.toLowerCase().contains('gcash') ||
                          payType.toLowerCase().contains('qrph')
                      ? Icons.qr_code_rounded
                      : Icons.credit_card_rounded,
                  color: HarayaColors.primary,
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: order['payment_status'] == 'paid' ? 'Paid' : 'Pending',
                  icon: order['payment_status'] == 'paid'
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  color: order['payment_status'] == 'paid'
                      ? const Color(0xFF388E3C)
                      : Colors.orange,
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₱$total',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: HarayaColors.primary)),
                    Text('+ ₱$fee shipping',
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: const Color(0xFF888888))),
                  ],
                ),
              ],
            ),

            if (extraContent != null) ...[
              const SizedBox(height: 12),
              extraContent!,
            ],

            const SizedBox(height: 12),
            actions,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final int maxLines;
  const _Row({required this.icon, required this.label, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF888888)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(label,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 13, color: HarayaColors.textDark)),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Chip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
