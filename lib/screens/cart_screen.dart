import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/payment_result_service.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'orders_screen.dart';

class CartScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const CartScreen({super.key, required this.user});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  int get _userId => (widget.user['id'] as int?) ?? 0;

  List<dynamic> _items  = [];
  bool _loading         = true;
  bool _paying          = false;
  final Set<int> _selected = {};
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await ApiService.getCart(_userId);
    setState(() {
      _items    = items;
      _loading  = false;
      _selected.addAll(items.map<int>((e) => e['cart_id'] as int));
    });
  }

  double get _subtotal => _items
      .where((i) => _selected.contains(i['cart_id'] as int))
      .fold(0.0, (s, i) => s + (double.tryParse(i['price'].toString()) ?? 0) * (i['quantity'] as int));

  double get _shipping => _selected.isEmpty ? 0 : 50.0;
  double get _total    => _subtotal + _shipping;

  String _img(dynamic item) {
    final raw = item['image_url'];
    if (raw is List && raw.isNotEmpty) {
      String p = raw[0].toString();
      if (!p.startsWith('http')) p = '${ApiService.baseUrl}$p';
      return p;
    }
    return '';
  }

  Future<void> _remove(int cartId) async {
    await ApiService.removeCartItem(cartId: cartId, userId: _userId);
    _selected.remove(cartId);
    await _load();
  }

  Future<void> _updateQty(dynamic item, int delta) async {
    final newQty = (item['quantity'] as int) + delta;
    final stock  = int.tryParse(item['stock_quantity'].toString()) ?? 0;
    if (newQty < 1 || newQty > stock) return;
    await ApiService.updateCartItem(
      cartId: item['cart_id'] as int,
      userId: _userId,
      quantity: newQty,
    );
    await _load();
  }

  void _showPaymentSheet() {
    if (_selected.isEmpty) {
      _snack('Select at least one item.', isError: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PaymentSheet(
        total: _total,
        onPay: (type) => _pay(type),
        sessionId: _currentSessionId,
        userId: _userId,
        user: widget.user,
        showSnack: _snack,
      ),
    );
  }

  Future<void> _pay(String paymentType) async {
    Navigator.pop(context);
    setState(() => _paying = true);
    try {
      final result = await ApiService.createPaymentSession(
        userId:      _userId,
        cartIds:     _selected.toList(),
        paymentType: paymentType,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        final sessionId = result['session_id'] as String;
        setState(() => _currentSessionId = sessionId);
        
        // Save pending payment info for app resume handling
        await PaymentResultService.savePendingPayment(
          sessionId: sessionId,
          userId: _userId,
        );
        
        final url = result['checkout_url'] as String;
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        _snack(result['message'] ?? 'Payment failed.', isError: true);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: isError ? HarayaColors.error : HarayaColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.background,
      appBar: AppBar(
        backgroundColor: HarayaColors.primary,
        foregroundColor: Colors.white,
        title: Text('My Cart', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => OrdersScreen(user: widget.user))),
            icon: const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 18),
            label: Text('Orders', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmpty()
              : _buildList(),
      bottomNavigationBar: _items.isEmpty ? null : _buildBottomBar(),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Your cart is empty',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
        ]),
      );

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _load,
      color: HarayaColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        itemCount: _items.length,
        itemBuilder: (_, i) => _CartTile(
          item:      _items[i],
          selected:  _selected.contains(_items[i]['cart_id'] as int),
          imgUrl:    _img(_items[i]),
          onSelect:  (v) => setState(() => v! ? _selected.add(_items[i]['cart_id'] as int)
                                              : _selected.remove(_items[i]['cart_id'] as int)),
          onRemove:  () => _remove(_items[i]['cart_id'] as int),
          onInc:     () => _updateQty(_items[i], 1),
          onDec:     () => _updateQty(_items[i], -1),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Subtotal', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
          Text('₱${_subtotal.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 13)),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Shipping', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
          Text('₱${_shipping.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 13)),
        ]),
        const Divider(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          Text('₱${_total.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: HarayaColors.error)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _paying || _selected.isEmpty ? null : _showPaymentSheet,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _paying
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Checkout (${_selected.length} item${_selected.length == 1 ? '' : 's'})',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ),
      ]),
    );
  }
}

// ── Cart item tile ─────────────────────────────────────────────────────────────

class _CartTile extends StatelessWidget {
  final dynamic  item;
  final bool     selected;
  final String   imgUrl;
  final ValueChanged<bool?> onSelect;
  final VoidCallback onRemove, onInc, onDec;

  const _CartTile({
    required this.item,
    required this.selected,
    required this.imgUrl,
    required this.onSelect,
    required this.onRemove,
    required this.onInc,
    required this.onDec,
  });

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(item['price'].toString()) ?? 0.0;
    final qty   = item['quantity'] as int;
    final stock = int.tryParse(item['stock_quantity'].toString()) ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Checkbox(
            value: selected,
            onChanged: onSelect,
            activeColor: HarayaColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imgUrl.isNotEmpty
                ? Image.network(imgUrl, width: 70, height: 70, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['product_name'] ?? '',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text(item['store_name'] ?? '',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 6),
            Row(children: [
              Text('₱${price.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: HarayaColors.error, fontSize: 14)),
              const Spacer(),
              _QtyBtn(Icons.remove, onDec, qty > 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('$qty', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              ),
              _QtyBtn(Icons.add, onInc, qty < stock),
            ]),
          ])),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: onRemove,
          ),
        ]),
      ),
    );
  }

  Widget _placeholder() => Container(
      width: 70, height: 70, color: const Color(0xFFEEF3F8),
      child: const Icon(Icons.home_outlined, color: HarayaColors.primary, size: 30));
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  const _QtyBtn(this.icon, this.onTap, this.enabled);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: enabled ? HarayaColors.primary : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon,
              size: 16, color: enabled ? Colors.white : Colors.grey.shade400),
        ),
      );
}

// ── Payment method bottom sheet ────────────────────────────────────────────────

class _PaymentSheet extends StatelessWidget {
  final double total;
  final void Function(String) onPay;
  final String? sessionId;
  final int userId;
  final Map<String, dynamic> user;
  final void Function(String, {bool isError}) showSnack;
  
  const _PaymentSheet({
    required this.total, 
    required this.onPay, 
    this.sessionId,
    required this.userId,
    required this.user,
    required this.showSnack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Choose Payment Method',
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
        Text('Total: ₱${total.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 20),
        _MethodTile(
          icon: '💳', label: 'Credit / Debit Card',
          sub: 'Visa, Mastercard, JCB',
          onTap: () => onPay('card'),
        ),
        const SizedBox(height: 10),
        _MethodTile(
          icon: '📱', label: 'GCash',
          sub: 'Pay via GCash QR or app',
          onTap: () => onPay('gcash'),
        ),
        const SizedBox(height: 10),
        _MethodTile(
          icon: '💙', label: 'Maya',
          sub: 'Pay via Maya (formerly PayMaya)',
          onTap: () => onPay('paymaya'),
        ),
        
        // Simulation buttons for testing
        if (sessionId != null) ...[
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          Text('Testing Options',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _simulatePayment(context, sessionId!, true),
                icon: const Icon(Icons.check_circle, size: 16),
                label: Text('Simulate Success', style: GoogleFonts.poppins(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _simulatePayment(context, sessionId!, false),
                icon: const Icon(Icons.cancel, size: 16),
                label: Text('Simulate Failure', style: GoogleFonts.poppins(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  void _simulatePayment(BuildContext context, String sessionId, bool success) async {
    try {
      final result = success 
          ? await ApiService.simulatePaymentSuccess(sessionId)
          : await ApiService.simulatePaymentFailure(sessionId);
      
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Simulation complete'),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      
      // Close the payment sheet after simulation
      Navigator.pop(context);
      
      // If successful, also call payment success handler to ensure proper processing
      if (result['success'] == true && success) {
        try {
          final successResult = await ApiService.handlePaymentSuccess(sessionId, userId: userId);
          if (successResult['success'] == true) {
            showSnack('Payment completed successfully! Stock deducted.');
            // Navigate to orders after a short delay
            Future.delayed(const Duration(seconds: 1), () {
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => OrdersScreen(user: user)),
                );
              }
            });
          }
        } catch (e) {
          showSnack('Payment processed but notification failed: $e', isError: true);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Simulation error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

class _MethodTile extends StatelessWidget {
  final String icon, label, sub;
  final VoidCallback onTap;
  const _MethodTile({required this.icon, required this.label, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(sub,   style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
            ])),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      );
}

// ── Reusable guest-prompt dialog ───────────────────────────────────────────────

Future<void> showLoginPrompt(BuildContext context) async {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Sign In Required',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      content: Text('You need to be logged in to add items to your cart or purchase.',
          style: GoogleFonts.poppins(fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
          },
          child: Text('Sign In', style: GoogleFonts.poppins()),
        ),
      ],
    ),
  );
}
