import 'package:web/web.dart' as web;

/// Opens [url] as a centred popup window (not a new tab).
/// Browsers allow popups triggered directly by a user gesture click.
void openPaymentPopup(String url) {
  const w = 500;
  const h = 720;
  final left = (web.window.screen.width - w) ~/ 2;
  final top  = (web.window.screen.height - h) ~/ 2;
  web.window.open(
    url,
    'paymongo_payment',
    'width=$w,height=$h,left=$left,top=$top,popup=1,scrollbars=yes',
  );
}
