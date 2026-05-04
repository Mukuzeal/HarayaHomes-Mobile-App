import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/haraya_widgets.dart';
import 'login_screen.dart';
import 'seller_apply_screen.dart';
import 'rider_apply_screen.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const HomeScreen({super.key, this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String get _role => widget.user?['role'] ?? 'guest';
  String get _fname => widget.user?['fname'] ?? 'Guest';
  String get _email => widget.user?['email'] ?? '';
  int get _userId {
    final id = widget.user?['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '0') ?? 0;
  }
  bool get _isGuest => widget.user == null || _role == 'guest' || _userId == 0;

  List<dynamic> _allProducts = [];
  List<dynamic> _filtered = [];
  bool _loadingProducts = true;
  int _cartCount = 0;

  String _searchQuery = '';
  String _selectedCategory = 'All';

  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _categories = [
    'All', 'Furniture', 'Home_Decor', 'Kitchen_Dining',
    'Bedding_Bath', 'Garden_Outdoor', 'Cleaning_Storage', 'Pet_Supplies',
  ];

  final List<String> _categoryLabels = [
    'All', 'Furniture', 'Home Decor', 'Kitchen & Dining',
    'Bedding & Bath', 'Garden & Outdoor', 'Cleaning & Storage', 'Pet Supplies',
  ];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    if (!_isGuest) _loadCartCount();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────── FETCH ─────────────────────────────────────────
  Future<void> _fetchProducts() async {
    setState(() => _loadingProducts = true);

    try {
      final products = await ApiService.getPublicProducts();

      setState(() {
        _allProducts = products;
        _filtered = products;
        _loadingProducts = false;
      });
    } catch (e) {
      debugPrint("ERROR: $e");
      setState(() => _loadingProducts = false);
    }
  }

  Future<void> _loadCartCount() async {
    if (_isGuest) return;
    try {
      final items = await ApiService.getCart(_userId);
      setState(() => _cartCount = items.length);
    } catch (e) {
      debugPrint("Failed to load cart count: $e");
    }
  }

  // ───────────────────────────────────────── FILTER ─────────────────────────────────────────
  void _applyFilters() {
    List<dynamic> result = List.from(_allProducts);

    if (_selectedCategory != 'All') {
      result = result.where((p) {
        final cat = (p['category'] ?? '').toString().toLowerCase();
        return cat == _selectedCategory.toLowerCase();
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      result = result.where((p) {
        final name = (p['product_name'] ?? '').toString().toLowerCase();
        final desc = (p['product_description'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) || desc.contains(_searchQuery);
      }).toList();
    }

    setState(() => _filtered = result);
  }

  // ───────────────────────────────────────── IMAGE FIX (IMPORTANT) ─────────────────────────────────────────
  String _getImage(dynamic product) {
    try {
      final raw = product['image_url'];

      if (raw is List && raw.isNotEmpty) {
        String path = raw[0].toString();

        if (!path.startsWith('http')) {
          path = "${ApiService.baseUrl}$path";
        }

        return path;
      }
    } catch (_) {}

    return '';
  }

  String _formatPrice(dynamic price) {
    final p = double.tryParse(price.toString()) ?? 0.0;
    return '₱${p.toStringAsFixed(2)}';
  }

  // ───────────────────────────────────────── UI ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [_buildSliverAppBar()],
        body: RefreshIndicator(
          onRefresh: _fetchProducts,
          color: HarayaColors.primary,
          child: _loadingProducts
              ? _buildSkeleton()
              : _filtered.isEmpty
                  ? _buildEmpty()
                  : _buildGrid(),
        ),
      ),
    );
  }

  // ───────────────────────────────────────── APP BAR (KEPT STYLE) ─────────────────────────────────────────
  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 195,
      pinned: true,
      backgroundColor: HarayaColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3A6A9F), HarayaColors.primary],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 6, 0),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Haraya',
                              style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          Text('Hi, $_fname 👋',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),

                      _topBtn(Icons.storefront, "Sell", () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => SellerApplyScreen(userEmail: _email)));
                      }),

                      const SizedBox(width: 6),

                      _topBtn(Icons.delivery_dining, "Ride", () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => RiderApplyScreen(userEmail: _email)));
                      }),
                      const SizedBox(width: 6),

                      // Cart icon with badge
                      if (!_isGuest)
                        Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => CartScreen(user: widget.user!)),
                              ),
                            ),
                            if (_cartCount > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '$_cartCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),

                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (_) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) {
                      _searchQuery = v.toLowerCase();
                      _applyFilters();
                    },
                    decoration: InputDecoration(
                      hintText: "Search products...",
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────── GRID ─────────────────────────────────────────
  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filtered.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, i) {
        final p = _filtered[i];

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(
                  product: p,
                  user: widget.user,
                ),
              ),
            );
          },
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
                      Text(p['store_name'] ?? '',
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() => const Center(child: Text("No products"));

  Widget _buildSkeleton() =>
      const Center(child: CircularProgressIndicator());
}