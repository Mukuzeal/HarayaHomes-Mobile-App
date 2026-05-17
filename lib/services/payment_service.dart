import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';
import 'api_service.dart';

class PaymentResult {
  final bool success;
  final String? sessionId;
  final String? error;

  PaymentResult({required this.success, this.sessionId, this.error});
}

class PaymentService {
  static Future<PaymentResult?> showPaymentUI(
    BuildContext context, {
    required String checkoutUrl,
    required String sessionId,
  }) async {
    // Open PayMongo checkout in a new browser tab
    final uri = Uri.parse(checkoutUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!context.mounted) return null;

    // Show a waiting dialog while the user completes payment in the tab
    return showDialog<PaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentWaitDialog(sessionId: sessionId),
    );
  }
}

class _PaymentWaitDialog extends StatefulWidget {
  final String sessionId;
  const _PaymentWaitDialog({required this.sessionId});

  @override
  State<_PaymentWaitDialog> createState() => _PaymentWaitDialogState();
}

class _PaymentWaitDialogState extends State<_PaymentWaitDialog> {
  bool _checking = false;
  String? _statusMsg;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Auto-poll every 5 seconds to catch webhook-driven completion
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus({bool silent = false}) async {
    if (_checking) return;
    if (!silent) setState(() { _checking = true; _statusMsg = null; });
    try {
      final result = await ApiService.checkPaymentSession(widget.sessionId);
      if (!mounted) return;
      final paid = result['paid'] == true;
      if (paid) {
        _pollTimer?.cancel();
        Navigator.of(context).pop(PaymentResult(success: true, sessionId: widget.sessionId));
      } else if (!silent) {
        setState(() { _statusMsg = 'Payment not yet confirmed. Complete it in the browser tab.'; });
      }
    } catch (_) {
      if (!silent && mounted) {
        setState(() { _statusMsg = 'Could not reach server. Please try again.'; });
      }
    } finally {
      if (!silent && mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: HarayaColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.open_in_new_rounded, color: HarayaColors.primary, size: 28),
          ),
          const SizedBox(height: 16),
          Text('Complete Your Payment',
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600,
                  color: HarayaColors.textDark)),
          const SizedBox(height: 8),
          Text(
            'A payment page has been opened in your browser.\n'
            'Complete your payment there, then tap "I\'ve Paid" below.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: HarayaColors.textMuted, height: 1.5),
          ),
          if (_statusMsg != null) ...[
            const SizedBox(height: 10),
            Text(_statusMsg!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange.shade700)),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _checking ? null : () => _checkStatus(),
              style: ElevatedButton.styleFrom(
                backgroundColor: HarayaColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HarayaRadius.pill)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: _checking
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text("I've Paid",
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600,
                          color: Colors.white)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _pollTimer?.cancel();
                Navigator.of(context).pop(PaymentResult(success: false, error: 'Cancelled'));
              },
              child: Text('Cancel',
                  style: GoogleFonts.poppins(fontSize: 13, color: HarayaColors.textMuted)),
            ),
          ],
        ),
      ],
    );
  }
}
