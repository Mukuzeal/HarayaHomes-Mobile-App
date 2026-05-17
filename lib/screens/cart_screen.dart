import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/payment_service.dart';
import '../services/payment_result_service.dart';
import '../theme.dart';
import '../utils/app_animations.dart';
import '../widgets/haraya_widgets.dart';
import 'login_screen.dart';
import 'orders_screen.dart';
import 'address_screen.dart';
import 'payment_card_screen.dart';

class CartScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const CartScreen({super.key, required this.user});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  int get _userId => (widget.user['id'] as int?) ?? 0;

  List<dynamic> _items        = [];
  bool _loading               = true;
  bool _paying                = false;
  final Set<int> _selected    = {};
  String? _currentSessionId;
  Map<String, dynamic>? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await ApiService.getCart(_userId);
    setState(() {
      _items   = items;
      _loading = false;
      _selected.addAll(items.map<int>((e) => e['cart_id'] as int));
    });
  }

  double get _subtotal => _items
      .where((i) => _selected.contains(i['cart_id'] as int))
      .fold(0.0, (s, i) =>
          s + (double.tryParse(i['price'].toString()) ?? 0) * (i['quantity'] as int));

  double get _shipping => _selected.isEmpty ? 0 : 50.0;
  double get _total    => _subtotal + _shipping;

  String _img(dynamic item) {
    try {
      final raw = item['image_url'];
      String p = '';
      if (raw is List && raw.isNotEmpty) {
        p = raw[0].toString().trim();
      } else if (raw is String && raw.isNotEmpty) {
        final str = raw.trim();
        if (str.startsWith('[')) {
          final decoded = json.decode(str);
          if (decoded is List && decoded.isNotEmpty) p = decoded[0].toString().trim();
        } else {
          p = str;
        }
      }
      if (p.isEmpty) return '';
      if (p.startsWith('http://') || p.startsWith('https://')) return p;
      return '${ApiService.baseUrl}/$p';
    } catch (_) {}
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
      cartId:   item['cart_id'] as int,
      userId:   _userId,
      quantity: newQty,
    );
    await _load();
  }

  void _showPaymentSheet() {
    if (_selected.isEmpty) {
      _snack('Select at least one item.', isError: true);
      return;
    }
    if (_selectedAddress == null) {
      _snack('Please select a delivery address.', isError: true);
      _selectAddress();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentSheet(
        total: _total,
        onPay: (type) => _pay(type),
        sessionId: _currentSessionId,
        userId: _userId,
        user: widget.user,
        showSnack: _snack,
        selectedAddress: _selectedAddress,
      ),
    );
  }

  Future<void> _selectAddress() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => AddressScreen(user: widget.user)),
    );
    if (result != null) {
      setState(() => _selectedAddress = result);
      _snack('Address set: ${result['label']}');
    }
  }

  Future<void> _pay(String paymentType) async {
    Navigator.pop(context);

    if (paymentType == 'card') {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentCardScreen(
            userId: _userId,
            cartIds: _selected.toList(),
            totalAmount: _subtotal,
            shippingFee: _shipping,
          ),
        ),
      );
      if (!mounted) return;
      if (result != null && result['success'] == true) {
        _snack('Payment successful! Your order has been placed.');
        await _load();
        setState(() => _selected.clear());
      }
      return;
    }

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

        await PaymentResultService.savePendingPayment(
          sessionId: sessionId,
          userId:    _userId,
        );

        final url = result['checkout_url'] as String;
        final paymentResult = await PaymentService.showPaymentUI(
          context,
          checkoutUrl: url,
          sessionId:   sessionId,
        );

        if (!mounted) return;
        if (paymentResult?.success == true) {
          _snack('Payment successful! Your order has been placed.');
          await _load();
          setState(() => _selected.clear());
        } else if (paymentResult?.success == false) {
          _snack(paymentResult?.error ?? 'Payment was cancelled.', isError: true);
        }
      } else {
        _snack(result['message'] ?? 'Payment failed.', isError: true);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _snack(String msg, {bool isError = false}) =>
      showHarayaSnackBar(context, msg, isError: isError);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.sectionBg,
      appBar: AppBar(
        backgroundColor: HarayaColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Cart',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => OrdersScreen(user: widget.user)),
            ),
            icon: const Icon(Icons.receipt_long_outlined,
                color: Colors.white, size: 17),
            label: Text(
              'Orders',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? _buildSkeleton()
          : _items.isEmpty
              ? _buildEmpty()
              : _buildList(),
      bottomNavigationBar: _items.isEmpty ? null : _buildBottomBar(),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: 4,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: SkeletonListTile(),
      ),
    );
  }

  Widget _buildEmpty() {
    return EmptyState(
      icon: Icons.shopping_cart_outlined,
      title: 'Your cart is empty',
      subtitle: 'Browse products and add items to get started.',
      buttonLabel: 'Start Shopping',
      onAction: () => Navigator.pop(context),
    );
  }

  Widget _buildList() {
    final allSelected = _items.every((i) => _selected.contains(i['cart_id'] as int));

    return RefreshIndicator(
      onRefresh: _load,
      color: HarayaColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          // Select all row
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Checkbox(
                  value: allSelected,
                  tristate: false,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected.addAll(_items.map<int>((e) => e['cart_id'] as int));
                    } else {
                      _selected.clear();
                    }
                  }),
                  activeColor: HarayaColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                Text(
                  'Select All (${_items.length} items)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: HarayaColors.textDark,
                  ),
                ),
              ],
            ),
          ),

          // Cart items
          ...List.generate(_items.length, (i) {
            final item = _items[i];
            return FadeSlideIn(
              delay: Duration(milliseconds: i * 50),
              child: _CartTile(
                item:     item,
                selected: _selected.contains(item['cart_id'] as int),
                imgUrl:   _img(item),
                onSelect: (v) => setState(() => v!
                    ? _selected.add(item['cart_id'] as int)
                    : _selected.remove(item['cart_id'] as int)),
                onRemove: () => _remove(item['cart_id'] as int),
                onInc:    () => _updateQty(item, 1),
                onDec:    () => _updateQty(item, -1),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Address selector
          PressScale(
            onTap: _selectAddress,
            child: AnimatedContainer(
              duration: HarayaDuration.normal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: _selectedAddress == null
                    ? const Color(0xFFFFF8F0)
                    : HarayaColors.successLight,
                borderRadius: BorderRadius.circular(HarayaRadius.md),
                border: Border.all(
                  color: _selectedAddress == null
                      ? const Color(0xFFFFB347)
                      : HarayaColors.success,
                ),
              ),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: HarayaDuration.fast,
                    child: Icon(
                      _selectedAddress == null
                          ? Icons.location_off_outlined
                          : Icons.location_on_rounded,
                      key: ValueKey(_selectedAddress == null),
                      color: _selectedAddress == null
                          ? const Color(0xFFE88A00)
                          : HarayaColors.success,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _selectedAddress == null
                        ? Text(
                            'Tap to select delivery address',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFFE88A00),
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Deliver to',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: HarayaColors.textMuted,
                                ),
                              ),
                              Text(
                                _selectedAddress!['label'] ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: HarayaColors.textDark,
                                ),
                              ),
                            ],
                          ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: _selectedAddress == null
                        ? const Color(0xFFE88A00)
                        : HarayaColors.success,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Price summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: HarayaColors.textMuted),
              ),
              Text(
                '₱${_subtotal.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: HarayaColors.textDark),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shipping',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: HarayaColors.textMuted),
              ),
              Text(
                '₱${_shipping.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: HarayaColors.textDark),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: HarayaColors.border, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: HarayaColors.textDark,
                ),
              ),
              Text(
                '₱${_total.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: HarayaColors.priceRed,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Checkout button
          LoadingButton(
            isLoading: _paying,
            label: 'Checkout (${_selected.length} item${_selected.length == 1 ? '' : 's'})',
            onPressed: _selected.isEmpty ? null : _showPaymentSheet,
            icon: Icons.shopping_bag_outlined,
          ),
        ],
      ),
    );
  }
}

// ── Cart Item Tile ─────────────────────────────────────────────────────────────
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
    final price  = double.tryParse(item['price'].toString()) ?? 0.0;
    final qty    = item['quantity'] as int;
    final stock  = int.tryParse(item['stock_quantity'].toString()) ?? 0;
    final name   = (item['product_name'] ?? '').toString();
    final store  = (item['store_name'] ?? '').toString();

    return AnimatedContainer(
      duration: HarayaDuration.normal,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(HarayaRadius.lg),
        border: Border.all(
          color: selected ? HarayaColors.primary.withValues(alpha: 0.3) : HarayaColors.border,
          width: selected ? 1.5 : 0.8,
        ),
        boxShadow: HarayaShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Checkbox
            Checkbox(
              value: selected,
              onChanged: onSelect,
              activeColor: HarayaColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),

            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(HarayaRadius.md),
              child: imgUrl.isNotEmpty
                  ? Image.network(
                      imgUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: HarayaColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    store,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: HarayaColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '₱${price.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: HarayaColors.priceRed,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      _QtyBtn(
                        icon: Icons.remove_rounded,
                        enabled: qty > 1,
                        onTap: onDec,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: AnimatedSwitcher(
                          duration: HarayaDuration.fast,
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Text(
                            '$qty',
                            key: ValueKey(qty),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: HarayaColors.textDark,
                            ),
                          ),
                        ),
                      ),
                      _QtyBtn(
                        icon: Icons.add_rounded,
                        enabled: qty < stock,
                        onTap: onInc,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Delete
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: HarayaColors.error, size: 20),
              onPressed: onRemove,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 72,
        height: 72,
        color: HarayaColors.sectionBg,
        child: const Icon(Icons.home_outlined,
            color: HarayaColors.primary, size: 30),
      );
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _QtyBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: HarayaDuration.fast,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled ? HarayaColors.primary : HarayaColors.border,
          borderRadius: BorderRadius.circular(HarayaRadius.sm),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? Colors.white : HarayaColors.textLight,
        ),
      ),
    );
  }
}

// ── Payment Bottom Sheet ───────────────────────────────────────────────────────
class _PaymentSheet extends StatelessWidget {
  final double total;
  final void Function(String) onPay;
  final String? sessionId;
  final int userId;
  final Map<String, dynamic> user;
  final void Function(String, {bool isError}) showSnack;
  final Map<String, dynamic>? selectedAddress;

  const _PaymentSheet({
    required this.total,
    required this.onPay,
    this.sessionId,
    required this.userId,
    required this.user,
    required this.showSnack,
    this.selectedAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(HarayaRadius.xxl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: HarayaColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              20 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: HarayaColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(HarayaRadius.md),
                      ),
                      child: const Icon(Icons.payment_rounded,
                          color: HarayaColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose Payment Method',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: HarayaColors.textDark,
                          ),
                        ),
                        Text(
                          'Total: ₱${total.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: HarayaColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),

                // Address preview
                if (selectedAddress != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: HarayaColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(HarayaRadius.md),
                      border: Border.all(
                          color: HarayaColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: HarayaColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedAddress!['label'] ?? 'Address',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: HarayaColors.primary,
                                ),
                              ),
                              if ((selectedAddress!['full_address'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text(
                                  selectedAddress!['full_address'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: HarayaColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Divider(color: HarayaColors.border, height: 1),
                const SizedBox(height: 14),

                // Payment options
                PaymentMethodTile(
                  emoji: '💳',
                  label: 'Credit / Debit Card',
                  subtitle: 'Visa, Mastercard, JCB',
                  onTap: () => onPay('card'),
                ),
                const SizedBox(height: 10),
                PaymentMethodTile(
                  emoji: '📱',
                  label: 'GCash',
                  subtitle: 'Pay via GCash QR or app',
                  onTap: () => onPay('gcash'),
                ),
                const SizedBox(height: 10),
                PaymentMethodTile(
                  emoji: '🔲',
                  label: 'QRPH',
                  subtitle: 'Scan any PH bank QR code',
                  onTap: () => onPay('qrph'),
                ),

                // Simulation buttons for testing
                if (sessionId != null) ...[
                  const SizedBox(height: 20),
                  Divider(color: HarayaColors.border, height: 1),
                  const SizedBox(height: 12),
                  Text(
                    'Testing Options',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: HarayaColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _simulatePayment(context, sessionId!, true),
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: Text('Simulate Success',
                              style: GoogleFonts.poppins(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HarayaColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _simulatePayment(context, sessionId!, false),
                          icon: const Icon(Icons.cancel, size: 16),
                          label: Text('Simulate Failure',
                              style: GoogleFonts.poppins(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HarayaColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _simulatePayment(
      BuildContext context, String sessionId, bool success) async {
    try {
      final result = success
          ? await ApiService.simulatePaymentSuccess(sessionId)
          : await ApiService.simulatePaymentFailure(sessionId);

      if (!context.mounted) return;

      showHarayaSnackBar(
        context,
        result['message'] ?? 'Simulation complete',
        isError: result['success'] != true,
      );

      Navigator.pop(context);

      if (result['success'] == true && success) {
        try {
          final successResult =
              await ApiService.handlePaymentSuccess(sessionId, userId: userId);
          if (successResult['success'] == true) {
            showSnack('Payment completed successfully! Stock deducted.');
            Future.delayed(const Duration(seconds: 1), () {
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => OrdersScreen(user: user)),
                );
              }
            });
          }
        } catch (e) {
          showSnack('Payment processed but notification failed: $e',
              isError: true);
        }
      }
    } catch (e) {
      if (context.mounted) {
        showHarayaSnackBar(context, 'Simulation error: $e', isError: true);
      }
    }
  }
}

// ── Reusable guest-prompt dialog ───────────────────────────────────────────────
Future<void> showLoginPrompt(BuildContext context) async {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HarayaRadius.xl)),
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HarayaColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock_outline_rounded,
            color: HarayaColors.primary, size: 28),
      ),
      title: Text(
        'Sign In Required',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      ),
      content: Text(
        'You need to be logged in to add items to your cart or make a purchase.',
        style: GoogleFonts.poppins(fontSize: 13, color: HarayaColors.textMuted),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(color: HarayaColors.textMuted),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()));
          },
          child: Text('Sign In', style: GoogleFonts.poppins()),
        ),
      ],
    ),
  );
}
