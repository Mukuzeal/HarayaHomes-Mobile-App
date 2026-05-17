import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/haraya_widgets.dart';

class PaymentCardScreen extends StatefulWidget {
  final int userId;
  final List<int>? cartIds;
  final int? productId;
  final int quantity;
  final double totalAmount;
  final double shippingFee;

  const PaymentCardScreen({
    super.key,
    required this.userId,
    this.cartIds,
    this.productId,
    this.quantity = 1,
    required this.totalAmount,
    required this.shippingFee,
  });

  @override
  State<PaymentCardScreen> createState() => _PaymentCardScreenState();
}

class _PaymentCardScreenState extends State<PaymentCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvcCtrl = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    _expiryCtrl.dispose();
    _cvcCtrl.dispose();
    super.dispose();
  }

  // Validates MM/YY and returns (month, year) or null if invalid.
  (int, int)? _parseExpiry(String val) {
    final parts = val.split('/');
    if (parts.length != 2) return null;
    final m = int.tryParse(parts[0].trim());
    final y = int.tryParse(parts[1].trim());
    if (m == null || y == null || m < 1 || m > 12) return null;
    return (m, y < 100 ? 2000 + y : y);
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    final expiry = _parseExpiry(_expiryCtrl.text);
    if (expiry == null) {
      showHarayaSnackBar(context, 'Invalid expiry date', isError: true);
      return;
    }

    setState(() => _loading = true);
    final result = await ApiService.directCharge(
      userId: widget.userId,
      cartIds: widget.cartIds,
      productId: widget.productId,
      quantity: widget.quantity,
      cardNumber: _numberCtrl.text.replaceAll(' ', ''),
      expMonth: expiry.$1,
      expYear: expiry.$2,
      cvc: _cvcCtrl.text.trim(),
      cardName: _nameCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      if (result['requires_action'] == true) {
        // 3DS redirect — not handled in this build; show message
        showHarayaSnackBar(context,
            '3D Secure verification required. Please use GCash or try another card.',
            isError: true);
        return;
      }
      Navigator.of(context).pop({'success': true, 'order_ids': result['order_ids']});
    } else {
      showHarayaSnackBar(
          context, result['message']?.toString() ?? 'Payment failed', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.sectionBg,
      appBar: AppBar(
        backgroundColor: HarayaColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Card Payment',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('Order Summary'),
              const SizedBox(height: 8),
              _SummaryCard(totalAmount: widget.totalAmount, shippingFee: widget.shippingFee),
              const SizedBox(height: 24),
              const _SectionLabel('Card Details'),
              const SizedBox(height: 12),
              _buildCardNumberField(),
              const SizedBox(height: 14),
              _buildNameField(),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _buildExpiryField()),
                const SizedBox(width: 14),
                Expanded(child: _buildCvcField()),
              ]),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _pay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HarayaColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(HarayaRadius.pill)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text('Pay ₱${(widget.totalAmount + widget.shippingFee).toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded, size: 13, color: HarayaColors.textMuted),
                    const SizedBox(width: 4),
                    Text('Secured by PayMongo',
                        style: GoogleFonts.poppins(fontSize: 11, color: HarayaColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardNumberField() {
    return TextFormField(
      controller: _numberCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _CardNumberFormatter(),
      ],
      decoration: _inputDeco('Card Number', '1234 5678 9012 3456',
          icon: Icons.credit_card_rounded),
      style: GoogleFonts.poppins(fontSize: 14, letterSpacing: 1.5),
      validator: (v) {
        final digits = (v ?? '').replaceAll(' ', '');
        if (digits.length < 13 || digits.length > 19) return 'Enter a valid card number';
        return null;
      },
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameCtrl,
      textCapitalization: TextCapitalization.words,
      decoration: _inputDeco('Cardholder Name', 'Juan Dela Cruz', icon: Icons.person_rounded),
      style: GoogleFonts.poppins(fontSize: 14),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter cardholder name' : null,
    );
  }

  Widget _buildExpiryField() {
    return TextFormField(
      controller: _expiryCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _ExpiryFormatter(),
      ],
      decoration: _inputDeco('Expiry', 'MM/YY'),
      style: GoogleFonts.poppins(fontSize: 14),
      validator: (v) {
        if (_parseExpiry(v ?? '') == null) return 'Invalid expiry';
        return null;
      },
    );
  }

  Widget _buildCvcField() {
    return TextFormField(
      controller: _cvcCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      obscureText: true,
      decoration: _inputDeco('CVV', '•••', icon: Icons.lock_rounded),
      style: GoogleFonts.poppins(fontSize: 14),
      validator: (v) {
        if (v == null || v.length < 3) return 'Invalid CVV';
        return null;
      },
    );
  }

  InputDecoration _inputDeco(String label, String hint, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.poppins(fontSize: 12, color: HarayaColors.textMuted),
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: HarayaColors.textLight),
      prefixIcon: icon != null ? Icon(icon, size: 18, color: HarayaColors.textMuted) : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: HarayaColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: HarayaColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: HarayaColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600, color: HarayaColors.textDark),
      );
}

class _SummaryCard extends StatelessWidget {
  final double totalAmount;
  final double shippingFee;
  const _SummaryCard({required this.totalAmount, required this.shippingFee});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HarayaColors.border),
      ),
      child: Column(
        children: [
          _Row('Subtotal', '₱${totalAmount.toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          _Row('Shipping', '₱${shippingFee.toStringAsFixed(2)}'),
          const Divider(height: 16, color: HarayaColors.border),
          _Row('Total', '₱${(totalAmount + shippingFee).toStringAsFixed(2)}', bold: true),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _Row(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: bold ? HarayaColors.textDark : HarayaColors.textMuted,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: bold ? HarayaColors.primary : HarayaColors.textDark,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ],
      );
}

// ── Input Formatters ──────────────────────────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final str = buf.toString();
    return TextEditingValue(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(RegExp(r'\D'), '');
    String str = digits;
    if (digits.length >= 3) {
      str = '${digits.substring(0, 2)}/${digits.substring(2, digits.length.clamp(0, 4))}';
    } else if (digits.length == 2 && old.text.length < next.text.length) {
      str = '$digits/';
    }
    return TextEditingValue(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}
