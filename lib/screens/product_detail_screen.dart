import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/payment_result_service.dart';
import '../theme.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';
import 'seller_store_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final dynamic product;
  final Map<String, dynamic>? user;

  const ProductDetailScreen({super.key, required this.product, this.user});

  int get _userId {
    final id = user?['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '0') ?? 0;
  }

  bool get _isGuest =>
      user == null ||
      (user?['role'] ?? 'guest') == 'guest' ||
      _userId == 0;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int  _selectedImage = 0;
  int  _quantity      = 1;
  bool _addingToCart  = false;
  bool _paying        = false;
  String? _currentSessionId;

  List<String> get _images {
    try {
      final raw = widget.product['image_url'];
      List<dynamic> imgs = [];
      if (raw is String && raw.isNotEmpty) imgs = json.decode(raw);
      else if (raw is List) imgs = raw;
      return imgs.map((e) {
        String url = e.toString();
        if (!url.startsWith('http')) url = '${ApiService.baseUrl}/$url';
        return url;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  String get _name        => (widget.product['product_name'] ?? 'Product').toString().replaceAll('_', ' ');
  String get _description => (widget.product['product_description'] ?? 'No description available.').toString();
  String get _category    => (widget.product['category'] ?? '').toString().replaceAll('_', ' ');
  String get _subCategory => (widget.product['sub_category'] ?? '').toString().replaceAll('_', ' ');
  String get _seller      => (widget.product['store_name'] ?? 'Unknown Store').toString();
  int    get _stock       => int.tryParse(widget.product['stock_quantity']?.toString() ?? '0') ?? 0;

  double get _price          => double.tryParse(widget.product['price']?.toString() ?? '0') ?? 0.0;
  String get _formattedPrice => '₱${_price.toStringAsFixed(2)}';
  String get _totalPrice     => '₱${(_price * _quantity).toStringAsFixed(2)}';

  // ── Add to cart ────────────────────────────────────────────────────────────
  Future<void> _addToCart() async {
    if (widget._isGuest) { await showLoginPrompt(context); return; }
    if (_stock == 0) { _showSnack('This product is out of stock.', isError: true); return; }

    setState(() => _addingToCart = true);
    try {
      final result = await ApiService.addToCart(
        productId: widget.product['product_id'],
        userId:    widget._userId,
        quantity:  _quantity,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        _showSnack('Added to cart! 🛒');
      } else {
        _showSnack(result['message'] ?? 'Failed to add to cart.', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  // ── Buy Now ────────────────────────────────────────────────────────────────
  Future<void> _buyNow() async {
    if (widget._isGuest) { await showLoginPrompt(context); return; }
    if (_stock == 0) { _showSnack('This product is out of stock.', isError: true); return; }

    _showPaymentSheet();
  }

  void _showPaymentSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PaymentSheet(
        total: _price * _quantity + 50,
        onPay: (type) => _processPayment(type),
        sessionId: _currentSessionId,
        userId: widget._userId,
        user: widget.user ?? {},
        showSnack: _showSnack,
      ),
    );
  }

  Future<void> _processPayment(String paymentType) async {
    Navigator.pop(context);
    setState(() => _paying = true);
    try {
      final result = await ApiService.createPaymentSession(
        userId:      widget._userId,
        productId:   widget.product['product_id'] as int,
        quantity:    _quantity,
        paymentType: paymentType,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        final sessionId = result['session_id'] as String;
        setState(() => _currentSessionId = sessionId);
        
        // Save pending payment info for app resume handling
        await PaymentResultService.savePendingPayment(
          sessionId: sessionId,
          userId: widget._userId,
        );
        
        final url = result['checkout_url'] as String;
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        _showSnack(result['message'] ?? 'Payment failed.', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
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
    final images = _images;

    return Scaffold(
      backgroundColor: HarayaColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar with image ───────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: HarayaColors.primary,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: HarayaColors.primary, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (!widget._isGuest)
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => CartScreen(user: widget.user!))),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  if (images.isNotEmpty)
                    PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _selectedImage = i),
                      itemBuilder: (_, i) => Image.network(
                        images[i],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => _noImage(),
                      ),
                    )
                  else
                    _noImage(),
                  if (images.length > 1)
                    Positioned(
                      bottom: 12, left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          images.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _selectedImage == i ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _selectedImage == i
                                  ? HarayaColors.primary
                                  : Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Product Details ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: HarayaColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (images.length > 1)
                    Container(
                      color: HarayaColors.sectionBg,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: SizedBox(
                        height: 64,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          itemBuilder: (_, i) => GestureDetector(
                            onTap: () => setState(() => _selectedImage = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 8),
                              width: 64, height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedImage == i
                                      ? HarayaColors.primary
                                      : Colors.grey.shade300,
                                  width: _selectedImage == i ? 2.5 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.network(images[i], fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.image_not_supported_outlined)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Text(_formattedPrice,
                                style: GoogleFonts.poppins(
                                    fontSize: 26, fontWeight: FontWeight.w800,
                                    color: const Color(0xFFE53935))),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _stock > 0
                                  ? HarayaColors.success.withValues(alpha: 0.1)
                                  : HarayaColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _stock > 0 ? HarayaColors.success : HarayaColors.error),
                            ),
                            child: Text(
                              _stock > 0 ? '$_stock in stock' : 'Out of stock',
                              style: GoogleFonts.poppins(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: _stock > 0 ? HarayaColors.success : HarayaColors.error),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 10),
                        Text(_name,
                            style: GoogleFonts.poppins(
                                fontSize: 18, fontWeight: FontWeight.w700,
                                color: HarayaColors.textDark, height: 1.3)),

                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SellerStoreScreen(
                                sellerId: widget.product['store_id'] ?? 0,
                                sellerName: _seller,
                                user: widget.user,
                              ),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: HarayaColors.sectionBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                  color: HarayaColors.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.storefront_rounded,
                                    color: HarayaColors.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Sold by',
                                    style: GoogleFonts.poppins(
                                        fontSize: 10, color: const Color(0xFF888888))),
                                Text(_seller,
                                    style: GoogleFonts.poppins(
                                        fontSize: 13, fontWeight: FontWeight.w600,
                                        color: HarayaColors.textDark)),
                              ])),
                              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                            ]),
                          ),
                        ),

                        const SizedBox(height: 16),
                        _divider(),
                        const SizedBox(height: 16),

                        Row(children: [
                          if (_category.isNotEmpty) _chip(_category, HarayaColors.primary),
                          if (_subCategory.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _chip(_subCategory, const Color(0xFF4A90A4)),
                          ],
                        ]),

                        const SizedBox(height: 16),
                        _divider(),
                        const SizedBox(height: 16),

                        Text('Product Description',
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: HarayaColors.textDark)),
                        const SizedBox(height: 8),
                        Text(_description,
                            style: GoogleFonts.poppins(
                                fontSize: 13.5, color: const Color(0xFF555555), height: 1.7)),

                        const SizedBox(height: 20),
                        _divider(),
                        const SizedBox(height: 16),

                        Text('Quantity',
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: HarayaColors.textDark)),
                        const SizedBox(height: 10),
                        Row(children: [
                          _qtyBtn(
                            icon: Icons.remove_rounded,
                            onTap: _quantity > 1 ? () => setState(() => _quantity--) : null,
                          ),
                          const SizedBox(width: 16),
                          Text('$_quantity',
                              style: GoogleFonts.poppins(
                                  fontSize: 18, fontWeight: FontWeight.w700,
                                  color: HarayaColors.textDark)),
                          const SizedBox(width: 16),
                          _qtyBtn(
                            icon: Icons.add_rounded,
                            onTap: _quantity < _stock ? () => setState(() => _quantity++) : null,
                          ),
                          const Spacer(),
                          Text('Total: $_totalPrice',
                              style: GoogleFonts.poppins(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: const Color(0xFFE53935))),
                        ]),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Bottom Action Bar ────────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(children: [
          // Add to Cart
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _addingToCart || _stock == 0 ? null : _addToCart,
              icon: _addingToCart
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: HarayaColors.primary))
                  : const Icon(Icons.shopping_cart_outlined, size: 18),
              label: Text(_addingToCart ? 'Adding...' : 'Add to Cart'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Buy Now
          Expanded(
            child: ElevatedButton(
              onPressed: _paying || _stock == 0 ? null : _buyNow,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              child: _paying
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_stock == 0 ? 'Out of Stock' : 'Buy Now'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _noImage() => Container(
      color: const Color(0xFFEEF3F8),
      child: const Center(
          child: Icon(Icons.home_outlined, color: HarayaColors.primary, size: 80)));

  Widget _divider() => Divider(color: Colors.grey.shade200, height: 1);

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _qtyBtn({required IconData icon, VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: onTap != null ? HarayaColors.primary : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: onTap != null ? Colors.white : Colors.grey.shade400, size: 20),
        ),
      );
}

// ── Payment bottom sheet (reused from cart_screen) ────────────────────────────

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
        Text('Total: ₱${total.toStringAsFixed(2)} (incl. ₱50 shipping)',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 20),
        _tile('💳', 'Credit / Debit Card', 'Visa, Mastercard, JCB', 'card', context),
        const SizedBox(height: 10),
        _tile('📱', 'GCash', 'Pay via GCash QR or app', 'gcash', context),
        const SizedBox(height: 10),
        _tile('💙', 'Maya', 'Pay via Maya (formerly PayMaya)', 'paymaya', context),
        
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

  Widget _tile(String icon, String label, String sub, String type, BuildContext ctx) =>
      InkWell(
        onTap: () => onPay(type),
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
              Text(label,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(sub,
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
            ])),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      );

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
