import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5000';

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

    final decoded = jsonDecode(response.body);

    // Case 1: direct list
    if (decoded is List) {
      return decoded;
    }

    // Case 2: wrapped in object
    if (decoded is Map && decoded.containsKey("products")) {
      return decoded["products"] as List;
    }

    _logError("Products", "Unexpected format");
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
        'store_name': storeName, 'owner_name': ownerName, 'phone': phone,
        'email': email, 'region': region, 'province': province,
        'city': city, 'barangay': barangay, 'exact_address': exactAddress,
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
        'first_name': firstName, 'last_name': lastName, 'birthday': birthday,
        'age': age, 'gender': gender, 'contact_number': contactNumber,
        'email': email, 'region': region, 'province': province,
        'city': city, 'barangay': barangay, 'exact_address': exactAddress,
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
}
