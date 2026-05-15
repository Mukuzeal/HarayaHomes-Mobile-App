import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'product_detail_screen.dart';

class SellerStoreScreen extends StatefulWidget {
  final int sellerId;
  final String sellerName;
  final Map<String, dynamic>? user;

  const SellerStoreScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
    this.user,
  });

  @override
  State<SellerStoreScreen> createState() => _SellerStoreScreenState();
}

class _SellerStoreScreenState extends State<SellerStoreScreen> {
  List<dynamic> _products = [];
  bool _loading = true;
  double _avgRating = 0.0;
  int _reviewCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSellerProducts();
  }

  Future<void> _loadSellerProducts() async {
    try {
      final products = await ApiService.getPublicProducts();

      // Filter products by seller
      final sellerProducts = products
          .where((p) => (p['store_name'] ?? '').toString().toLowerCase() ==
                        widget.sellerName.toLowerCase())
          .toList();

      // Calculate average rating
      double totalRating = 0;
      int ratedCount = 0;
      for (var p in sellerProducts) {
        final rating = double.tryParse(p['average_rating'].toString()) ?? 0.0;
        if (rating > 0) {
          totalRating += rating;
          ratedCount++;
        }
      }

      setState(() {
        _products = sellerProducts;
        _avgRating = ratedCount > 0 ? totalRating / ratedCount : 0.0;
        _reviewCount = sellerProducts.fold(0, (sum, p) => sum + ((p['total_reviews'] as int?) ?? 0));
        _loading = false;
      });
    } catch (e) {
      debugPrint("Failed to load seller products: $e");
      setState(() => _loading = false);
    }
  }

  String _getImage(dynamic product) {
    try {
      final raw = product['image_url'];
      String path = '';

      if (raw is List && raw.isNotEmpty) {
        path = raw[0].toString().trim();
      } else if (raw is String && raw.isNotEmpty) {
        final str = raw.trim();
        if (str.startsWith('[')) {
          final decoded = json.decode(str);
          if (decoded is List && decoded.isNotEmpty) {
            path = decoded[0].toString().trim();
          }
        } else {
          path = str;
        }
      }

      if (path.isEmpty) return '';
      if (path.startsWith('http://') || path.startsWith('https://')) return path;
      return '${ApiService.baseUrl}/$path';
    } catch (_) {}
    return '';
  }

  String _formatPrice(dynamic price) {
    final p = double.tryParse(price.toString()) ?? 0.0;
    return '₱${p.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.background,
      appBar: AppBar(
        backgroundColor: HarayaColors.primary,
        foregroundColor: Colors.white,
        title: Text(widget.sellerName,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Store Header
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Store Name & Rating
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.sellerName,
                                      style: GoogleFonts.poppins(
                                          fontSize: 18, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.star, color: Colors.amber, size: 18),
                                      const SizedBox(width: 4),
                                      Text(_avgRating > 0 ? _avgRating.toStringAsFixed(1) : 'No rating',
                                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 12),
                                      Text('($_reviewCount reviews)',
                                          style: GoogleFonts.poppins(
                                              fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: HarayaColors.primary.withValues(alpha: 0.1),
                              ),
                              child: Icon(Icons.store,
                                  color: HarayaColors.primary, size: 30),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Store Stats
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStat('${_products.length}', 'Products'),
                            _buildStat('${(_avgRating * 100).toInt()}%', 'Satisfied'),
                            _buildStat('Fast', 'Delivery'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Products Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Products',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _products.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text('No products available',
                                style: GoogleFonts.poppins(color: Colors.grey)),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _products.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemBuilder: (_, i) {
                            final p = _products[i];
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen(
                                    product: p,
                                    user: widget.user,
                                  ),
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Image.network(
                                        _getImage(p),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.image_not_supported),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p['product_name'] ?? '',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600)),
                                          Text(_formatPrice(p['price']),
                                              style: const TextStyle(color: Colors.red)),
                                          Row(
                                            children: [
                                              Icon(Icons.star,
                                                  color: Colors.amber, size: 14),
                                              const SizedBox(width: 2),
                                              Text(
                                                (double.tryParse(
                                                            p['average_rating'].toString()) ??
                                                        0.0)
                                                    .toStringAsFixed(1),
                                                style: GoogleFonts.poppins(fontSize: 10),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
