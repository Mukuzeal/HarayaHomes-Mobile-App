import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uni_links/uni_links.dart';
import 'payment_result_service.dart';

class AppLinkService {
  static final AppLinkService _instance = AppLinkService._internal();
  factory AppLinkService() => _instance;
  AppLinkService._internal();

  StreamSubscription<String>? _sub;
  final StreamController<AppLinkData> _linkController = StreamController<AppLinkData>.broadcast();
  Stream<AppLinkData> get linkStream => _linkController.stream;

  void initialize() {
    // Listen to uni_links stream for deep links
    _sub = getLinksStream().listen((String link) {
      if (link.isNotEmpty) {
        final uri = Uri.parse(link);
        _handleIncomingLink(uri);R
      }
    }, onError: (err) {
      print('Error handling deep link: $err');
    });

    // Check for initial link (when app was closed)
    _getInitialLink();
  }

  Future<void> _getInitialLink() async {
    try {
      final initialLink = await getInitialLink();
      if (initialLink != null && initialLink.isNotEmpty) {
        final uri = Uri.parse(initialLink);
        _handleIncomingLink(uri);
      }
    } catch (e) {
      print('Error getting initial link: $e');
    }
  }

  void _handleIncomingLink(Uri uri) {
    print('Received deep link: $uri');
    
    if (uri.scheme == 'haraya') {
      switch (uri.host) {
        case 'payment-success':
          _handlePaymentSuccess(uri);
          break;
        default:
          print('Unknown deep link host: ${uri.host}');
      }
    }
  }

  void _handlePaymentSuccess(Uri uri) {
    final userId = uri.queryParameters['user_id'] ?? '';
    print('Payment success deep link received for user: $userId');
    
    // Emit payment success event
    _linkController.add(AppLinkData(
      type: AppLinkType.paymentSuccess,
      data: {
        'user_id': userId,
        'source': 'deep_link',
      },
    ));
  }

  void dispose() {
    _sub?.cancel();
    _linkController.close();
  }
}

enum AppLinkType {
  paymentSuccess,
}

class AppLinkData {
  final AppLinkType type;
  final Map<String, String> data;

  AppLinkData({
    required this.type,
    required this.data,
  });
}
