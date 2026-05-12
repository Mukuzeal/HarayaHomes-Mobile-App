import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://haraya-homes-api.onrender.com';

  static void _log(String tag, String msg) {
    if (kDebugMode) print('🔵 [Haraya/$tag] $msg');
  }
  static void _logError(String tag, String msg) {
    if (kDebugMode) print('🔴 [Haraya/$tag] $msg');
  }
  static void _logSuccess(String tag, String msg) {
    if (kDebugMode) print('✅ [Haraya/$tag] $msg');
  }

  static Future<Map<String, String>> _getHeaders({bool isJson = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionCookie = prefs.getString('session_cookie') ?? '';
    return {
      'Content-Type': isJson ? 'application/json' : 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
      if (sessionCookie.isNotEmpty) 'Cookie': sessionCookie,
    };
  }

  static Future<void> _saveSessionCookie(http.Response response) async {
    final cookie = response.headers['set-cookie'];
    if (cookie != null) {
      final sessionPart = cookie.split(';').first;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_cookie', sessionPart);
      _logSuccess('Cookie', 'Session cookie saved: $sessionPart');
    }
  }

  // ── LOGIN ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = '$baseUrl/api/login';
    _log('Login', 'POST → $url');
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({'action': 'signin', 'email': email, 'password': password});
      final response = await http.post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 10));
      _log('Login', 'Status: ${response.statusCode}');
      _log('Login', 'Body: ${response.body}');
      await _saveSessionCookie(response);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException catch (e) {
      _logError('Login', 'JSON decode failed: $e');
      return {'success': false, 'message': 'Server returned unexpected response. Check CORS/Flask.'};
    } catch (e) {
      _logError('Login', 'Exception: $e');
      rethrow;
    }
  }

  // ── SIGNUP ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> signup({
    required String fname,
    required String lname,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final url = '$baseUrl/api/login';
    _log('Signup', 'POST → $url');
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'action': 'signup',
        'fname': fname,
        'lname': lname,
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
      });
      final response = await http.post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 10));
      _log('Signup', 'Status: ${response.statusCode}');
      await _saveSessionCookie(response);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException catch (e) {
      _logError('Signup', 'JSON decode failed: $e');
      return {'success': false, 'message': 'Server returned unexpected response.'};
    } catch (e) {
      _logError('Signup', 'Exception: $e');
      rethrow;
    }
  }

  // ── LOGOUT ─────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    _log('Logout', 'GET → $baseUrl/logout');
    try {
      final headers = await _getHeaders(isJson: false);
      await http.get(Uri.parse('$baseUrl/logout'), headers: headers)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      _logError('Logout', 'Exception: $e');
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_cookie');
      await prefs.remove('user_data');
      _logSuccess('Logout', 'Local session cleared.');
    }
  }

  // ── GET PRODUCTS (public) ──────────────────────────────────────────────
  static Future<List<dynamic>> getPublicProducts() async {
  final url = "$baseUrl/api/public-products";

  _log("Products", "GET → $url");

  try {
    final response = await http.get(Uri.parse(url));

    _log("Products", "Status: ${response.statusCode}");
    _log("Products", "Body: ${response.body}");

    // ❗ Prevent HTML crash
    if (response.body.trim().startsWith("<!DOCTYPE")) {
      _logError("Products", "Server returned HTML instead of JSON");
      return [];
    }

    if (response.statusCode != 200) {
      _logError("Products", "HTTP ${response.statusCode}: ${response.body}");
      return [];
    }

    final decoded = jsonDecode(response.body);

    // Case 1: direct list
    if (decoded is List) {
      return decoded;
    }

    // Case 2: wrapped in object
    if (decoded is Map && decoded.containsKey("products")) {
      return decoded["products"] as List;
    }

    // Case 3: server-side error object
    if (decoded is Map && decoded.containsKey("error")) {
      _logError("Products", "Server error: ${decoded["error"]}");
      return [];
    }

    _logError("Products", "Unexpected format: ${response.body}");
    return [];
  } catch (e) {
    _logError("Products", "Exception: $e");
    return [];
  }
}

  // ── ADD TO CART (stateless – user_id in body) ─────────────────────────────
  static Future<Map<String, dynamic>> addToCart({
    required dynamic productId,
    required int userId,
    int quantity = 1,
  }) async {
    const url = '$baseUrl/api/cart/add';
    _log('Cart', 'POST → $url  product_id=$productId  user=$userId  qty=$quantity');
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({'user_id': userId, 'product_id': productId, 'quantity': quantity});
      final response = await http.post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 10));
      _log('Cart', 'Status: ${response.statusCode}');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException catch (e) {
      _logError('Cart', 'JSON decode failed: $e');
      return {'success': false, 'message': 'Unexpected server response.'};
    } catch (e) {
      _logError('Cart', 'Exception: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── GET CART ───────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getCart(int userId) async {
    final url = '$baseUrl/api/cart/$userId';
    _log('Cart', 'GET → $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body);
      if (decoded['success'] == true) return decoded['items'] as List;
      return [];
    } catch (e) {
      _logError('Cart', 'getCart error: $e');
      return [];
    }
  }

  // ── REMOVE CART ITEM ───────────────────────────────────────────────────────
  static Future<bool> removeCartItem({required int cartId, required int userId}) async {
    const url = '$baseUrl/api/cart/remove';
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({'cart_id': cartId, 'user_id': userId});
      final response = await http.post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 10));
      return (jsonDecode(response.body) as Map)['success'] == true;
    } catch (e) {
      _logError('Cart', 'removeCartItem error: $e');
      return false;
    }
  }

  // ── UPDATE CART ITEM ───────────────────────────────────────────────────────
  static Future<bool> updateCartItem({
    required int cartId,
    required int userId,
    required int quantity,
  }) async {
    const url = '$baseUrl/api/cart/update';
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({'cart_id': cartId, 'user_id': userId, 'quantity': quantity});
      final response = await http.post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 10));
      return (jsonDecode(response.body) as Map)['success'] == true;
    } catch (e) {
      _logError('Cart', 'updateCartItem error: $e');
      return false;
    }
  }

  // ── CREATE PAYMENT SESSION (PayMongo) ──────────────────────────────────────
  static Future<Map<String, dynamic>> createPaymentSession({
    required int userId,
    List<int>? cartIds,
    int? productId,
    int quantity = 1,
    required String paymentType,
  }) async {
    const url = '$baseUrl/api/payment/create-session';
    _log('Payment', 'POST → $url');
    try {
      final headers = await _getHeaders();
      final Map<String, dynamic> bodyMap = {
        'user_id': userId,
        'payment_type': paymentType,
      };
      if (cartIds != null) bodyMap['cart_ids'] = cartIds;
      if (productId != null) {
        bodyMap['product_id'] = productId;
        bodyMap['quantity']   = quantity;
      }
      final response = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(bodyMap))
          .timeout(const Duration(seconds: 20));
      _log('Payment', 'Status: ${response.statusCode}');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _logError('Payment', 'createPaymentSession error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── GET ORDERS ──────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getOrders(int userId) async {
    final url = '$baseUrl/api/orders/$userId';
    _log('Orders', 'GET → $url');
    try {
      final response = await http.get(Uri.parse(url), headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));
      _log('Orders', 'Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true ? data['orders'] : [];
      }
      return [];
    } catch (e) {
      _logError('Orders', 'Exception: $e');
      return [];
    }
  }

  // ── CHECK PAYMENT SESSION STATUS ──────────────────────────────────────────
  static Future<Map<String, dynamic>> handlePaymentSuccess(String sessionId, {int? userId}) async {
    final query = userId != null ? '?user_id=$userId' : '';
    final url   = '$baseUrl/api/payment/check-session/$sessionId$query';
    _log('Payment', 'GET → $url');
    try {
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      _log('Payment', 'Status: ${response.statusCode}');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _logError('Payment', 'handlePaymentSuccess error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── PAYMENT SIMULATION ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> simulatePaymentSuccess(String sessionId) async {
    const url = '$baseUrl/api/payment/simulate-success';
    _log('Simulate Success', 'POST → $url');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode({'session_id': sessionId}),
      ).timeout(const Duration(seconds: 10));
      _log('Simulate Success', 'Status: ${response.statusCode}');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _logError('Simulate Success', 'Exception: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> simulatePaymentFailure(String sessionId) async {
    const url = '$baseUrl/api/payment/simulate-failure';
    _log('Simulate Failure', 'POST → $url');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode({'session_id': sessionId}),
      ).timeout(const Duration(seconds: 10));
      _log('Simulate Failure', 'Status: ${response.statusCode}');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _logError('Simulate Failure', 'Exception: $e');
      rethrow;
    }
  }

  // ── SELLER APPLICATION ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> submitSellerApplication({
    required int userId,
    required String storeName,
    required String ownerName,
    required String phone,
    required String email,
    required String region,
    required String province,
    required String city,
    required String barangay,
    required String exactAddress,
    required String zipCode,
    required String productCategory,
    required String validIdPath,
    required String documentPath,
  }) async {
    final url = '$baseUrl/apply';
    _log('SellerApply', 'POST (multipart) → $url');
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionCookie = prefs.getString('session_cookie') ?? '';
      final request = http.MultipartRequest('POST', Uri.parse(url));
      if (sessionCookie.isNotEmpty) request.headers['Cookie'] = sessionCookie;
      request.headers['Accept'] = 'application/json';
      request.fields.addAll({
        'user_id': userId.toString(),
        'store_name': storeName, 'owner_name': ownerName, 'phone': phone,
        'email': email, 'region_name': region, 'province_name': province,
        'city_name': city, 'barangay_name': barangay, 'exact_address': exactAddress,
        'zip_code': zipCode, 'product_category': productCategory,
      });
      if (validIdPath.isNotEmpty)
        request.files.add(await http.MultipartFile.fromPath('valid_id', validIdPath));
      if (documentPath.isNotEmpty)
        request.files.add(await http.MultipartFile.fromPath('document', documentPath));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      _log('SellerApply', 'Status: ${response.statusCode}');
      await _saveSessionCookie(response);
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        if (response.statusCode == 302 || response.statusCode == 200)
          return {'success': true, 'message': 'Application submitted successfully!'};
        return {'success': false, 'message': 'Unexpected server response (${response.statusCode}).'};
      }
    } catch (e) {
      _logError('SellerApply', 'Exception: $e');
      rethrow;
    }
  }

  // ── RIDER APPLICATION ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> submitRiderApplication({
    required int userId,
    required String firstName,
    required String lastName,
    required String birthday,
    required String age,
    required String gender,
    required String contactNumber,
    required String email,
    required String region,
    required String province,
    required String city,
    required String barangay,
    required String exactAddress,
    required String zipCode,
    required String vehicleType,
    required String vehicleModel,
    required String plateNumber,
    required String vehicleFrontPath,
    required String vehicleBackPath,
    required String validIdPath,
    required String licensePath,
    required String orcrPath,
  }) async {
    final url = '$baseUrl/RiderApply';
    _log('RiderApply', 'POST (multipart) → $url');
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionCookie = prefs.getString('session_cookie') ?? '';
      final request = http.MultipartRequest('POST', Uri.parse(url));
      if (sessionCookie.isNotEmpty) request.headers['Cookie'] = sessionCookie;
      request.headers['Accept'] = 'application/json';
      request.fields.addAll({
        'user_id': userId.toString(),
        'first_name': firstName, 'last_name': lastName, 'birthday': birthday,
        'age': age, 'gender': gender, 'contact_number': contactNumber,
        'email': email, 'region_name': region, 'province_name': province,
        'city_name': city, 'barangay_name': barangay, 'exact_address': exactAddress,
        'zip_code': zipCode, 'vehicle_type': vehicleType,
        'vehicle_model': vehicleModel, 'plate_number': plateNumber,
      });
      Future<void> attach(String path, String field) async {
        if (path.isNotEmpty)
          request.files.add(await http.MultipartFile.fromPath(field, path));
      }
      await attach(vehicleFrontPath, 'vehicle_front');
      await attach(vehicleBackPath,  'vehicle_back');
      await attach(validIdPath,      'valid_id');
      await attach(licensePath,      'license');
      await attach(orcrPath,         'orcr');
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      _log('RiderApply', 'Status: ${response.statusCode}');
      await _saveSessionCookie(response);
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        if (response.statusCode == 302 || response.statusCode == 200)
          return {'success': true, 'message': 'Rider application submitted successfully!'};
        return {'success': false, 'message': 'Unexpected server response (${response.statusCode}).'};
      }
    } catch (e) {
      _logError('RiderApply', 'Exception: $e');
      rethrow;
    }
  }

  // ── RIDER DASHBOARD ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getRiderStats(int userId) async {
    final url = '$baseUrl/api/flutter/rider/$userId/stats';
    _log('Rider', 'GET stats → $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _logError('Rider', 'Stats exception: $e');
      return {'deliveries_today': 0, 'completed': 0, 'pending': 0, 'earnings_today': 0.0};
    }
  }

  static Future<List<dynamic>> getRiderActiveDeliveries(int userId) async {
    final url = '$baseUrl/api/flutter/rider/$userId/active';
    _log('Rider', 'GET active → $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body);
      return (decoded['deliveries'] as List?) ?? [];
    } catch (e) {
      _logError('Rider', 'Active deliveries exception: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getRiderAvailableDeliveries(int userId) async {
    final url = '$baseUrl/api/flutter/rider/$userId/available';
    _log('Rider', 'GET available → $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body);
      return (decoded['deliveries'] as List?) ?? [];
    } catch (e) {
      _logError('Rider', 'Available deliveries exception: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> riderTakeDelivery(int userId, int orderId) async {
    final url = '$baseUrl/api/flutter/rider/$userId/take';
    _log('Rider', 'POST take → $url  order=$orderId');
    try {
      final response = await http.post(Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'order_id': orderId})).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _logError('Rider', 'Take delivery exception: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> riderMarkDelivered(int userId, int orderId) async {
    final url = '$baseUrl/api/flutter/rider/$userId/delivered';
    _log('Rider', 'POST delivered → $url  order=$orderId');
    try {
      final response = await http.post(Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'order_id': orderId})).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _logError('Rider', 'Mark delivered exception: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<dynamic>> getRiderHistory(int userId) async {
    final url = '$baseUrl/api/flutter/rider/$userId/history';
    _log('Rider', 'GET history → $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body);
      return (decoded['history'] as List?) ?? [];
    } catch (e) {
      _logError('Rider', 'History exception: $e');
      return [];
    }
  }

  // ── SELLER APPROVAL ────────────────────────────────────────────────────

  static Future<List<dynamic>> getSellerOrders(int userId) async {
    final url = '$baseUrl/api/flutter/seller/$userId/orders';
    _log('Seller', 'GET orders → $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body);
      return (decoded['orders'] as List?) ?? [];
    } catch (e) {
      _logError('Seller', 'Orders exception: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> sellerAcceptOrder(int userId, int orderId) async {
    final url = '$baseUrl/api/flutter/seller/$userId/accept_order';
    try {
      final response = await http.post(Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'order_id': orderId})).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> sellerRejectOrder(int userId, int orderId) async {
    final url = '$baseUrl/api/flutter/seller/$userId/reject_order';
    try {
      final response = await http.post(Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'order_id': orderId})).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> sellerMarkReady(int userId, int orderId) async {
    final url = '$baseUrl/api/flutter/seller/$userId/mark_ready';
    try {
      final response = await http.post(Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'order_id': orderId})).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<dynamic>> getSellerPendingRiders(int userId) async {
    final url = '$baseUrl/api/flutter/seller/$userId/pending_riders';
    _log('Seller', 'GET pending riders → $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body);
      return (decoded['pending'] as List?) ?? [];
    } catch (e) {
      _logError('Seller', 'Pending riders exception: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> sellerApproveRider(int userId, int orderId) async {
    final url = '$baseUrl/api/flutter/seller/$userId/approve_rider';
    _log('Seller', 'POST approve_rider order=$orderId → $url');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'order_id': orderId}),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _logError('Seller', 'Approve exception: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> sellerRejectRider(int userId, int orderId) async {
    final url = '$baseUrl/api/flutter/seller/$userId/reject_rider';
    _log('Seller', 'POST reject_rider order=$orderId → $url');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'order_id': orderId}),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _logError('Seller', 'Reject exception: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── NOTIFICATIONS ─────────────────────────────────────────────────────────
  static Future<List<dynamic>> getNotifications(int userId) async {
    final url = '$baseUrl/api/flutter/notifications/$userId';
    _log('Notifications', 'GET → $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body);
      return (decoded is List) ? decoded : [];
    } catch (e) {
      _logError('Notifications', 'Get notifications exception: $e');
      return [];
    }
  }

  static Future<bool> markNotificationRead(int notificationId, int userId) async {
    final url = '$baseUrl/api/flutter/notifications/$notificationId/read';
    _log('Notifications', 'POST mark_read notif=$notificationId → $url');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      ).timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['success'] == true;
    } catch (e) {
      _logError('Notifications', 'Mark read exception: $e');
      return false;
    }
  }

  static Future<bool> markAllNotificationsRead(int userId) async {
    const url = '$baseUrl/api/flutter/notifications/read-all';
    _log('Notifications', 'POST mark_all_read → $url');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      ).timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['success'] == true;
    } catch (e) {
      _logError('Notifications', 'Mark all read exception: $e');
      return false;
    }
  }

  // ── SHIPPING CALCULATOR ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> calculateShipping({
    required double sellerLat,
    required double sellerLng,
    required double buyerLat,
    required double buyerLng,
    required double weightKg,
    required int quantity,
  }) async {
    const url = '$baseUrl/api/calculate-shipping';
    _log('Shipping', 'POST calculate_shipping → $url');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'seller_lat': sellerLat,
          'seller_lng': sellerLng,
          'buyer_lat': buyerLat,
          'buyer_lng': buyerLng,
          'weight_kg': weightKg,
          'quantity': quantity,
        }),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _logError('Shipping', 'Calculate exception: $e');
      return {'success': false, 'fee': 50.0, 'error': e.toString()};
    }
  }

  // ── PROOF OF DELIVERY ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> uploadProofOfDelivery(
    int riderId,
    int orderId,
    String imagePath,
  ) async {
    final url = '$baseUrl/api/flutter/rider/$riderId/upload_proof';
    _log('Delivery', 'POST upload_proof order=$orderId → $url');
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..fields['order_id'] = orderId.toString()
        ..files.add(await http.MultipartFile.fromPath('proof_image', imagePath));

      final response = await request.send().timeout(const Duration(seconds: 30));
      final decoded = jsonDecode(await response.stream.bytesToString()) as Map<String, dynamic>;
      _logSuccess('Delivery', 'Upload proof successful');
      return decoded;
    } catch (e) {
      _logError('Delivery', 'Upload proof exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── BUYER CONFIRM RECEIPT ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> confirmOrderReceived(int userId, int orderId) async {
    final url = '$baseUrl/api/flutter/buyer/$userId/confirm_received';
    _log('Buyer', 'POST confirm_received order=$orderId → $url');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'order_id': orderId}),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _logError('Buyer', 'Confirm received exception: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── ORDER DETAIL ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getOrderDetail(int orderId) async {
    final url = '$baseUrl/api/flutter/order/$orderId/detail';
    _log('Order', 'GET detail order=$orderId → $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _logError('Order', 'Get detail exception: $e');
      return {'error': e.toString()};
    }
  }

  // ── MANUAL PAYMENT ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> createManualPaymentOrder(
    int userId,
    List<int> cartIds,
    String paymentType,
  ) async {
    const url = '$baseUrl/api/payment/manual';
    _log('Payment', 'POST manual_payment → $url');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'cart_ids': cartIds,
          'payment_type': paymentType,
        }),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _logError('Payment', 'Manual payment exception: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── PROOF OF PAYMENT ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> uploadProofOfPayment(
    int userId,
    int orderId,
    String imagePath,
  ) async {
    const url = '$baseUrl/api/payment/upload-proof';
    _log('Payment', 'POST upload_proof order=$orderId → $url');
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..fields['user_id'] = userId.toString()
        ..fields['order_id'] = orderId.toString()
        ..files.add(await http.MultipartFile.fromPath('proof_image', imagePath));

      final response = await request.send().timeout(const Duration(seconds: 30));
      final decoded = jsonDecode(await response.stream.bytesToString()) as Map<String, dynamic>;
      _logSuccess('Payment', 'Upload proof of payment successful');
      return decoded;
    } catch (e) {
      _logError('Payment', 'Upload proof exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── SELLER VERIFY PAYMENT ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> verifyPayment(
    int sellerUserId,
    int orderId,
    String action,
  ) async {
    final url = '$baseUrl/api/flutter/seller/$sellerUserId/verify_payment';
    _log('Seller', 'POST verify_payment order=$orderId action=$action → $url');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'order_id': orderId, 'action': action}),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _logError('Seller', 'Verify payment exception: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── LOCATION & ADDRESSES ──────────────────────────────────────────────────
  static Future<List<dynamic>> getRegions() async {
    final url = '$baseUrl/api/locations/regions';
    _log('Location', 'GET regions → $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _logSuccess('Location', 'Regions loaded: ${data['regions']?.length ?? 0}');
        return data['regions'] ?? [];
      }
      throw Exception('Failed to load regions');
    } catch (e) {
      _logError('Location', 'Get regions exception: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getProvinces(int regionId) async {
    final url = '$baseUrl/api/locations/provinces/$regionId';
    _log('Location', 'GET provinces → $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _logSuccess('Location', 'Provinces loaded: ${data['provinces']?.length ?? 0}');
        return data['provinces'] ?? [];
      }
      throw Exception('Failed to load provinces');
    } catch (e) {
      _logError('Location', 'Get provinces exception: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getCities(int provinceId) async {
    final url = '$baseUrl/api/locations/cities/$provinceId';
    _log('Location', 'GET cities → $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _logSuccess('Location', 'Cities loaded: ${data['cities']?.length ?? 0}');
        return data['cities'] ?? [];
      }
      throw Exception('Failed to load cities');
    } catch (e) {
      _logError('Location', 'Get cities exception: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getBarangays(int cityId) async {
    final url = '$baseUrl/api/locations/barangays/$cityId';
    _log('Location', 'GET barangays → $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _logSuccess('Location', 'Barangays loaded: ${data['barangays']?.length ?? 0}');
        return data['barangays'] ?? [];
      }
      throw Exception('Failed to load barangays');
    } catch (e) {
      _logError('Location', 'Get barangays exception: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getAddresses(int userId) async {
    final url = '$baseUrl/api/buyer/$userId/addresses';
    _log('Address', 'GET addresses → $url');
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _logSuccess('Address', 'Addresses loaded: ${data['addresses']?.length ?? 0}');
        return data['addresses'] ?? [];
      }
      throw Exception('Failed to load addresses');
    } catch (e) {
      _logError('Address', 'Get addresses exception: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> addAddress(
    int userId, {
    required String label,
    required String fullname,
    required String phonenumber,
    required String fullAddress,
    required double latitude,
    required double longitude,
  }) async {
    final url = '$baseUrl/api/buyer/$userId/addresses';
    _log('Address', 'POST add address → $url');
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'label': label,
        'fullname': fullname,
        'Phonenumber': phonenumber,
        'full_address': fullAddress,
        'latitude': latitude,
        'longitude': longitude,
      });
      final response = await http.post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        _logSuccess('Address', 'Address added: ${data['address_id']}');
      }
      return data;
    } catch (e) {
      _logError('Address', 'Add address exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateAddress(
    int userId,
    int addressId, {
    String? label,
    String? fullname,
    String? phonenumber,
    double? latitude,
    double? longitude,
  }) async {
    final url = '$baseUrl/api/buyer/$userId/addresses/$addressId';
    _log('Address', 'PUT update address → $url');
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        if (label != null) 'label': label,
        if (fullname != null) 'fullname': fullname,
        if (phonenumber != null) 'Phonenumber': phonenumber,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });
      final response = await http.put(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        _logSuccess('Address', 'Address updated');
      }
      return data;
    } catch (e) {
      _logError('Address', 'Update address exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteAddress(int userId, int addressId) async {
    final url = '$baseUrl/api/buyer/$userId/addresses/$addressId';
    _log('Address', 'DELETE address → $url');
    try {
      final response = await http.delete(Uri.parse(url)).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        _logSuccess('Address', 'Address deleted');
      }
      return data;
    } catch (e) {
      _logError('Address', 'Delete address exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
