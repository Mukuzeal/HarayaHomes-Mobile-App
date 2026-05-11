import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentService {
  static Future<PaymentResult?> showPaymentUI(
    BuildContext context, {
    required String checkoutUrl,
    required String sessionId,
  }) async {
    final result = await showDialog<PaymentResult?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentDialog(
        checkoutUrl: checkoutUrl,
        sessionId: sessionId,
      ),
    );
    return result;
  }
}

class PaymentResult {
  final bool success;
  final String? sessionId;
  final String? error;

  PaymentResult({
    required this.success,
    this.sessionId,
    this.error,
  });
}

class _PaymentDialog extends StatefulWidget {
  final String checkoutUrl;
  final String sessionId;

  const _PaymentDialog({
    required this.checkoutUrl,
    required this.sessionId,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
            _checkPaymentCompletion(url);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _checkPaymentCompletion(url);
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _checkPaymentCompletion(String url) {
    if (url.contains('payment/success')) {
      Navigator.pop(
        context,
        PaymentResult(
          success: true,
          sessionId: widget.sessionId,
        ),
      );
    } else if (url.contains('payment/failed') || url.contains('cancel')) {
      Navigator.pop(
        context,
        PaymentResult(
          success: false,
          error: 'Payment was cancelled or failed',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Complete Payment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (_hasError)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text('Failed to load payment page'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _hasError = false);
                            _initWebView();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else
                  WebViewWidget(controller: _webViewController),
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
