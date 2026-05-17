import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/api_service.dart';
import '../theme.dart';

class PaymentQrScreen extends StatefulWidget {
  final int userId;
  final List<int>? cartIds;
  final int? productId;
  final int quantity;
  final double totalAmount;
  final double shippingFee;

  const PaymentQrScreen({
    super.key,
    required this.userId,
    this.cartIds,
    this.productId,
    this.quantity = 1,
    required this.totalAmount,
    required this.shippingFee,
  });

  @override
  State<PaymentQrScreen> createState() => _PaymentQrScreenState();
}

class _PaymentQrScreenState extends State<PaymentQrScreen> {
  bool _loading = true;
  String? _checkoutUrl;
  String? _error;
  Timer? _pollTimer;
  bool _paid = false;

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _createSession() async {
    final result = await ApiService.createPaymentSession(
      userId: widget.userId,
      cartIds: widget.cartIds,
      productId: widget.productId,
      quantity: widget.quantity,
      paymentType: 'qrph',
    );
    if (!mounted) return;

    if (result['success'] == true) {
      final sessionId = result['session_id'] as String? ?? '';
      final url = result['checkout_url'] as String? ?? '';
      setState(() {
        _checkoutUrl = url;
        _loading = false;
      });
      _startPolling(sessionId);
    } else {
      setState(() {
        _error = result['message']?.toString() ?? 'Could not generate QR code.';
        _loading = false;
      });
    }
  }

  void _startPolling(String sessionId) {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final result = await ApiService.checkPaymentSession(sessionId);
      if (!mounted) return;
      if (result['paid'] == true) {
        _pollTimer?.cancel();
        setState(() => _paid = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop({'success': true, 'session_id': sessionId});
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.sectionBg,
      appBar: AppBar(
        backgroundColor: HarayaColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Scan to Pay',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HarayaColors.primary))
          : _error != null
              ? _buildError()
              : _paid
                  ? _buildSuccess()
                  : _buildQrBody(),
    );
  }

  Widget _buildQrBody() {
    final url = _checkoutUrl ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: HarayaShadows.card,
            ),
            child: Column(
              children: [
                Text('₱${(widget.totalAmount + widget.shippingFee).toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                        fontSize: 28, fontWeight: FontWeight.w700,
                        color: HarayaColors.primary)),
                const SizedBox(height: 4),
                Text('Total including shipping',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: HarayaColors.textMuted)),
                const SizedBox(height: 20),
                QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: HarayaColors.sectionBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: HarayaColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Text('Waiting for payment...',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: HarayaColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _InstructionRow(
            icon: Icons.phone_iphone_rounded,
            text: 'Open GCash, Maya, or any PH bank app on your phone',
          ),
          const SizedBox(height: 12),
          const _InstructionRow(
            icon: Icons.qr_code_scanner_rounded,
            text: 'Tap "Scan QR" and point your camera at the code above',
          ),
          const SizedBox(height: 12),
          const _InstructionRow(
            icon: Icons.check_circle_outline_rounded,
            text: 'Confirm the amount and approve — this screen updates automatically',
          ),
          const SizedBox(height: 28),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: HarayaColors.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 72, color: Colors.green),
          const SizedBox(height: 16),
          Text('Payment Confirmed!',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: HarayaColors.textDark)),
          const SizedBox(height: 8),
          Text('Your order has been placed.',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: HarayaColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 52, color: HarayaColors.border),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: HarayaColors.textMuted)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                setState(() { _loading = true; _error = null; });
                _createSession();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InstructionRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: HarayaColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: HarayaColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(text,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: HarayaColors.textMuted, height: 1.4)),
          ),
        ),
      ],
    );
  }
}
