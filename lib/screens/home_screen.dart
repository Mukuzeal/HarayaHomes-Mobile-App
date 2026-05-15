import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/notification_polling_service.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'seller_apply_screen.dart';
import 'seller_orders_screen.dart';
import 'seller_store_screen.dart';
import 'rider_apply_screen.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'notifications_screen.dart';

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
  String _sortBy = 'popularity'; // popularity, price_low, price_high, newest, rating

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

  // ───────────────────────────────────────── FILTER & SORT ─────────────────────────────────────────
  void _applyFilters() {
    List<dynamic> result = List.from(_allProducts);

    // Category filter
    if (_selectedCategory != 'All') {
      result = result.where((p) {
        final cat = (p['category'] ?? '').toString().toLowerCase();
        return cat == _selectedCategory.toLowerCase();
      }).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      result = result.where((p) {
        final name = (p['product_name'] ?? '').toString().toLowerCase();
        final desc = (p['product_description'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) || desc.contains(_searchQuery);
      }).toList();
    }

    // Apply sorting
    _applySorting(result);
    setState(() => _filtered = result);
  }

  void _applySorting(List<dynamic> products) {
    switch (_sortBy) {
      case 'price_low':
        products.sort((a, b) {
          final priceA = double.tryParse(a['price'].toString()) ?? 0.0;
          final priceB = double.tryParse(b['price'].toString()) ?? 0.0;
          return priceA.compareTo(priceB);
        });
        break;
      case 'price_high':
        products.sort((a, b) {
          final priceA = double.tryParse(a['price'].toString()) ?? 0.0;
          final priceB = double.tryParse(b['price'].toString()) ?? 0.0;
          return priceB.compareTo(priceA);
        });
        break;
      case 'rating':
        products.sort((a, b) {
          final ratingA = double.tryParse(a['average_rating'].toString()) ?? 0.0;
          final ratingB = double.tryParse(b['average_rating'].toString()) ?? 0.0;
          return ratingB.compareTo(ratingA);
        });
        break;
      case 'newest':
        products.sort((a, b) {
          final idA = (a['Product_id'] as int?) ?? 0;
          final idB = (b['Product_id'] as int?) ?? 0;
          return idB.compareTo(idA);
        });
        break;
      case 'popularity':
      default:
        products.sort((a, b) {
          final reviewsA = (a['total_reviews'] as int?) ?? 0;
          final reviewsB = (b['total_reviews'] as int?) ?? 0;
          return reviewsB.compareTo(reviewsA);
        });
    }
  }

  // ───────────────────────────────────────── IMAGE FIX (IMPORTANT) ─────────────────────────────────────────
  String _getImage(dynamic product) {
    try {
      final raw = product['image_url'];
      String path = '';

      if (raw is List && raw.isNotEmpty) {
        path = raw[0].toString().trim();
      } else if (raw is String && raw.isNotEmpty) {
        final str = raw.trim();
        if (str.startsWith('[')) {
          // JSON array stored as text — parse it
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
              : Column(
                  children: [
                    _buildFilterBar(),
                    Expanded(
                      child: _filtered.isEmpty ? _buildEmpty() : _buildGrid(),
                    ),
                  ],
                ),
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

                      if (_role == 'seller') ...[
                        _topBtn(Icons.pending_actions_rounded, "Approvals", () {
                          Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => SellerOrdersScreen(user: widget.user!)));
                        }),
                        const SizedBox(width: 6),
                      ] else ...[
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
                      ],

                      // Notifications icon with badge
                      ValueListenableBuilder<int>(
                        valueListenable: NotificationPollingService().unreadCount,
                        builder: (context, unreadCount, _) {
                          return Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NotificationsScreen(user: widget.user!),
                                  ),
                                ),
                              ),
                              if (unreadCount > 0)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      '$unreadCount',
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
                          );
                        },
                      ),

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

  // ───────────────────────────────────────── FILTER BAR ─────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Category chips
          SizedBox(
            height: 40,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_categories.length, (i) {
                  final cat = _categories[i];
                  final label = _categoryLabels[i];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(label,
                          style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? Colors.white : Colors.black87)),
                      backgroundColor: isSelected ? HarayaColors.primary : Colors.grey[200],
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat);
                        _applyFilters();
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Sort dropdown
          Row(
            children: [
              const Icon(Icons.sort, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _sortBy,
                  isExpanded: true,
                  underline: Container(),
                  items: const [
                    DropdownMenuItem(value: 'popularity', child: Text('Most Popular')),
                    DropdownMenuItem(value: 'newest', child: Text('Newest')),
                    DropdownMenuItem(value: 'price_low', child: Text('Price: Low to High')),
                    DropdownMenuItem(value: 'price_high', child: Text('Price: High to Low')),
                    DropdownMenuItem(value: 'rating', child: Text('Highest Rating')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _sortBy = value);
                      _applyFilters();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
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
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SellerStoreScreen(
                                sellerId: p['store_id'] ?? 0,
                                sellerName: p['store_name'] ?? '',
                                user: widget.user,
                              ),
                            ),
                          );
                        },
                        child: Text(p['store_name'] ?? '',
                            style: GoogleFonts.poppins(fontSize: 11, color: HarayaColors.primary, fontWeight: FontWeight.w500)),
                      ),
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