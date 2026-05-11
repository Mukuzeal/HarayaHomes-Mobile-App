import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/haraya_widgets.dart';
import 'landing_screen.dart';

class RiderDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const RiderDashboardScreen({super.key, required this.user});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  int get _userId => (widget.user['id'] as int?) ?? 0;
  String get _fname => widget.user['fname'] ?? 'Rider';

  Map<String, dynamic> _stats = {
    'deliveries_today': 0,
    'completed': 0,
    'pending': 0,
    'earnings_today': 0.0,
  };
  List<dynamic> _active    = [];
  List<dynamic> _available = [];
  List<dynamic> _history   = [];

  bool _loadingStats     = true;
  bool _loadingActive    = true;
  bool _loadingAvailable = true;
  bool _loadingHistory   = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _refreshCurrentTab();
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadStats(), _loadActive(), _loadAvailable(), _loadHistory()]);
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    final s = await ApiService.getRiderStats(_userId);
    if (mounted) setState(() { _stats = s; _loadingStats = false; });
  }

  Future<void> _loadActive() async {
    setState(() => _loadingActive = true);
    final d = await ApiService.getRiderActiveDeliveries(_userId);
    if (mounted) setState(() { _active = d; _loadingActive = false; });
  }

  Future<void> _loadAvailable() async {
    setState(() => _loadingAvailable = true);
    final d = await ApiService.getRiderAvailableDeliveries(_userId);
    if (mounted) setState(() { _available = d; _loadingAvailable = false; });
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    final h = await ApiService.getRiderHistory(_userId);
    if (mounted) setState(() { _history = h; _loadingHistory = false; });
  }

  void _refreshCurrentTab() {
    switch (_tabs.index) {
      case 0: _loadActive();    break;
      case 1: _loadAvailable(); break;
      case 2: _loadHistory();   break;
    }
  }

  Future<void> _takeDelivery(int orderId) async {
    final res = await ApiService.riderTakeDelivery(_userId, orderId);
    if (!mounted) return;
    if (res['success'] == true) {
      showHarayaSnackBar(context, 'Delivery accepted!');
      _loadActive(); _loadAvailable(); _loadStats();
    } else {
      showHarayaSnackBar(context, res['message'] ?? 'Failed to take delivery.', isError: true);
    }
  }

  Future<void> _markDelivered(int orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Mark as Delivered?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Confirm that order #$orderId has been delivered.',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final res = await ApiService.riderMarkDelivered(_userId, orderId);
    if (!mounted) return;
    if (res['success'] == true) {
      showHarayaSnackBar(context, 'Order marked as delivered!');
      _loadActive(); _loadHistory(); _loadStats();
    } else {
      showHarayaSnackBar(context, res['message'] ?? 'Failed.', isError: true);
    }
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (_) => false,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildHeader()],
        body: Column(
          children: [
            _buildStatsRow(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildActiveTab(),
                  _buildAvailableTab(),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  SliverAppBar _buildHeader() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: HarayaColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3A6A9F), HarayaColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.two_wheeler_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Haraya Haul',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700)),
                            Text('Hi, $_fname 👋',
                                style: GoogleFonts.poppins(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        tooltip: 'Log out',
                        onPressed: _logout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.circle, color: Color(0xFF4CAF50), size: 10),
                      const SizedBox(width: 6),
                      Text('Online · Ready for deliveries',
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    if (_loadingStats) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final items = [
      (_stats['deliveries_today']?.toString() ?? '0', 'Today',
       Icons.local_shipping_rounded, HarayaColors.primary),
      (_stats['pending']?.toString() ?? '0', 'Active',
       Icons.pending_actions_rounded, const Color(0xFFE65100)),
      (_stats['completed']?.toString() ?? '0', 'Done',
       Icons.check_circle_rounded, const Color(0xFF388E3C)),
      ('₱${((_stats['earnings_today'] as num?) ?? 0).toStringAsFixed(0)}', 'Earned',
       Icons.payments_rounded, const Color(0xFF5C3D9F)),
    ];
    return Container(
      color: HarayaColors.sectionBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: items
            .map((i) => Expanded(
                child: _StatCard(value: i.$1, label: i.$2, icon: i.$3, color: i.$4)))
            .toList(),
      ),
    );
  }

  // ── Tabs ───────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabs,
        labelColor: HarayaColors.primary,
        unselectedLabelColor: const Color(0xFF888888),
        indicatorColor: HarayaColors.primary,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
        tabs: [
          Tab(text: 'Active (${_active.length})'),
          Tab(text: 'Available (${_available.length})'),
          const Tab(text: 'History'),
        ],
      ),
    );
  }

  // ── Active tab ─────────────────────────────────────────────────────────────
  Widget _buildActiveTab() {
    if (_loadingActive) return const Center(child: CircularProgressIndicator());
    if (_active.isEmpty) {
      return _buildEmpty(Icons.inbox_rounded, 'No active deliveries',
          'Grab one from Available');
    }
    return RefreshIndicator(
      onRefresh: _loadActive,
      color: HarayaColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _active.length,
        itemBuilder: (_, i) => _ActiveCard(
          delivery: _active[i],
          onMarkDelivered: () => _markDelivered(_active[i]['order_id'] as int),
        ),
      ),
    );
  }

  // ── Available tab ──────────────────────────────────────────────────────────
  Widget _buildAvailableTab() {
    if (_loadingAvailable) return const Center(child: CircularProgressIndicator());
    if (_available.isEmpty) {
      return _buildEmpty(Icons.search_off_rounded, 'No available deliveries',
          'Check back soon for new orders');
    }
    return RefreshIndicator(
      onRefresh: _loadAvailable,
      color: HarayaColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _available.length,
        itemBuilder: (_, i) => _AvailableCard(
          delivery: _available[i],
          onTake: () => _takeDelivery(_available[i]['order_id'] as int),
        ),
      ),
    );
  }

  // ── History tab ────────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    if (_loadingHistory) return const Center(child: CircularProgressIndicator());
    if (_history.isEmpty) {
      return _buildEmpty(Icons.history_rounded, 'No deliveries yet',
          'Your completed deliveries will appear here');
    }
    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: HarayaColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _history.length,
        itemBuilder: (_, i) => _HistoryCard(item: _history[i]),
      ),
    );
  }

  Widget _buildEmpty(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: const Color(0xFFCCCCCC)),
          const SizedBox(height: 14),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: HarayaColors.textDark)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF888888))),
        ],
      ),
    );
  }
}

// ── Road route fetcher ────────────────────────────────────────────────────────
// Uses OSRM public routing server (no API key required).
// Falls back to a straight line if the request fails.

final Map<String, List<LatLng>> _routeCache = {};

Future<List<LatLng>> _fetchRoadRoute(
    double fromLat, double fromLng, double toLat, double toLng) async {
  final key = '$fromLat,$fromLng,$toLat,$toLng';
  if (_routeCache.containsKey(key)) return _routeCache[key]!;

  try {
    // Use OSRM with HTTPS
    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '$fromLng,$fromLat;$toLng,$toLat'
        '?overview=full&geometries=geojson&steps=true';
    final resp = await http.get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;

      if (routes != null && routes.isNotEmpty) {
        final geometry = routes[0]['geometry'];
        if (geometry is Map && geometry['coordinates'] != null) {
          final coords = (geometry['coordinates'] as List)
              .map((c) => LatLng(
                  (c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();

          if (coords.isNotEmpty) {
            _routeCache[key] = coords;
            return coords;
          }
        }
      }
    }
  } catch (e) {
    debugPrint('⚠️ Route fetch failed: $e');
  }

  // Fallback to straight line
  final fallback = [LatLng(fromLat, fromLng), LatLng(toLat, toLng)];
  _routeCache[key] = fallback;
  return fallback;
}

// ── Delivery Map (inline preview) ────────────────────────────────────────────
// Green marker = pickup (seller), Red marker = dropoff (buyer).

class _DeliveryMap extends StatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final double height;

  const _DeliveryMap({
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    this.height = 190,
  });

  @override
  State<_DeliveryMap> createState() => _DeliveryMapState();
}

class _DeliveryMapState extends State<_DeliveryMap> {
  late List<LatLng> _routePoints;
  bool _loadingRoute = true;

  @override
  void initState() {
    super.initState();
    _routePoints = [
      LatLng(widget.pickupLat, widget.pickupLng),
      LatLng(widget.dropoffLat, widget.dropoffLng),
    ];
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    try {
      final points = await _fetchRoadRoute(
        widget.pickupLat, widget.pickupLng,
        widget.dropoffLat, widget.dropoffLng,
      );
      if (mounted) {
        setState(() {
          _routePoints = points;
          _loadingRoute = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading route: $e');
      if (mounted) {
        setState(() => _loadingRoute = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup  = LatLng(widget.pickupLat,  widget.pickupLng);
    final dropoff = LatLng(widget.dropoffLat, widget.dropoffLng);
    final center  = LatLng(
      (widget.pickupLat  + widget.dropoffLat)  / 2,
      (widget.pickupLng + widget.dropoffLng) / 2,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 12,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.haraya.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: HarayaColors.primary,
                      strokeWidth: 4,
                      borderColor: Colors.white.withValues(alpha: 0.7),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pickup,
                      width: 36, height: 36,
                      child: const _MapPin(
                          color: Color(0xFF2E7D32), icon: Icons.store_rounded),
                    ),
                    Marker(
                      point: dropoff,
                      width: 36, height: 36,
                      child: const _MapPin(
                          color: Color(0xFFC62828), icon: Icons.home_rounded),
                    ),
                  ],
                ),
              ],
            ),
            if (_loadingRoute)
              Container(
                color: Colors.black.withValues(alpha: 0.2),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _MapPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

// ── Fullscreen map ────────────────────────────────────────────────────────────

class _FullscreenMap extends StatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String pickupLabel;
  final String dropoffLabel;

  const _FullscreenMap({
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.pickupLabel,
    required this.dropoffLabel,
  });

  @override
  State<_FullscreenMap> createState() => _FullscreenMapState();
}

class _FullscreenMapState extends State<_FullscreenMap> {
  late List<LatLng> _routePoints;
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _routePoints = [
      LatLng(widget.pickupLat, widget.pickupLng),
      LatLng(widget.dropoffLat, widget.dropoffLng),
    ];
    _loadRoute();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    final points = await _fetchRoadRoute(
      widget.pickupLat, widget.pickupLng,
      widget.dropoffLat, widget.dropoffLng,
    );
    if (!mounted) return;
    setState(() => _routePoints = points);
    // Fit camera to show the entire road route
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(40, 40, 40, 180),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pickup  = LatLng(widget.pickupLat,  widget.pickupLng);
    final dropoff = LatLng(widget.dropoffLat, widget.dropoffLng);

    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery Route',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: HarayaColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                (widget.pickupLat + widget.dropoffLat) / 2,
                (widget.pickupLng + widget.dropoffLng) / 2,
              ),
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.haraya.app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: HarayaColors.primary,
                    strokeWidth: 5,
                    borderColor: Colors.white.withValues(alpha: 0.7),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: pickup,
                    width: 44, height: 44,
                    child: const _MapPin(
                        color: Color(0xFF2E7D32), icon: Icons.store_rounded),
                  ),
                  Marker(
                    point: dropoff,
                    width: 44, height: 44,
                    child: const _MapPin(
                        color: Color(0xFFC62828), icon: Icons.home_rounded),
                  ),
                ],
              ),
            ],
          ),
          // Legend panel
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LegendRow(
                      color: const Color(0xFF2E7D32),
                      icon: Icons.store_rounded,
                      label: 'Pickup: ${widget.pickupLabel}'),
                  const SizedBox(height: 8),
                  _LegendRow(
                      color: const Color(0xFFC62828),
                      icon: Icons.home_rounded,
                      label: 'Deliver to: ${widget.dropoffLabel}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  const _LegendRow({required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: GoogleFonts.poppins(fontSize: 12, color: HarayaColors.textDark),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

// ── Cards ─────────────────────────────────────────────────────────────────────

double? _toDouble(dynamic v) =>
    v == null ? null : double.tryParse(v.toString());

class _ActiveCard extends StatefulWidget {
  final Map<String, dynamic> delivery;
  final VoidCallback onMarkDelivered;

  const _ActiveCard({required this.delivery, required this.onMarkDelivered});

  @override
  State<_ActiveCard> createState() => _ActiveCardState();
}

class _ActiveCardState extends State<_ActiveCard> {
  bool _uploadingProof = false;
  String? _proofPath;

  @override
  void initState() {
    super.initState();
    _proofPath = widget.delivery['delivery_photo'] as String?;
  }

  Future<void> _uploadProofOfDelivery() async {
    final imagePath = await _pickImage();
    if (imagePath == null || !mounted) return;

    setState(() => _uploadingProof = true);
    try {
      final userId = (widget.delivery['rider_id'] as int?) ?? 0;
      final orderId = widget.delivery['order_id'] as int;
      final result = await ApiService.uploadProofOfDelivery(userId, orderId, imagePath);
      if (!mounted) return;

      if (result['success'] == true) {
        setState(() => _proofPath = result['photo_url']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proof uploaded successfully!',
                style: GoogleFonts.poppins(fontSize: 13)),
            backgroundColor: HarayaColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Upload failed',
                style: GoogleFonts.poppins(fontSize: 13)),
            backgroundColor: HarayaColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.poppins(fontSize: 13)),
            backgroundColor: HarayaColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingProof = false);
    }
  }

  Future<String?> _pickImage() async {
    try {
      final result = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      return result?.path;
    } catch (e) {
      debugPrint('Image picker error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.delivery['delivery_status'] ?? 'ontheway';
    final isPending = status == 'pending_approval';
    final statusColor = isPending
        ? const Color(0xFFF57C00)
        : status == 'picked_up'
            ? const Color(0xFF388E3C)
            : HarayaColors.primary;
    final statusLabel = isPending
        ? 'Awaiting Seller Approval'
        : status == 'picked_up'
            ? 'Picked Up'
            : 'On the Way';

    final sLat = _toDouble(widget.delivery['seller_lat']);
    final sLng = _toDouble(widget.delivery['seller_lng']);
    final bLat = _toDouble(widget.delivery['buyer_lat']);
    final bLng = _toDouble(widget.delivery['buyer_lng']);
    final hasMap = sLat != null && sLng != null && bLat != null && bLng != null
        && !(sLat == 0 && sLng == 0) && !(bLat == 0 && bLng == 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status + order ID
            Row(
              children: [
                _StatusBadge(label: statusLabel, color: statusColor),
                const Spacer(),
                Text('Order #${widget.delivery['order_id']}',
                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF888888))),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.person_rounded, label: widget.delivery['customer_name'] ?? '—'),
            const SizedBox(height: 5),
            _InfoRow(icon: Icons.inventory_2_rounded, label: widget.delivery['product_name'] ?? '—'),
            const SizedBox(height: 5),
            _InfoRow(icon: Icons.location_on_rounded,
                label: widget.delivery['delivery_address'] ?? '—', maxLines: 2),

            // Map
            if (hasMap) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _FullscreenMap(
                      pickupLat: sLat, pickupLng: sLng,
                      dropoffLat: bLat, dropoffLng: bLng,
                      pickupLabel: widget.delivery['seller_address'] ?? 'Seller',
                      dropoffLabel: widget.delivery['delivery_address'] ?? widget.delivery['customer_name'] ?? 'Buyer',
                    ),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    _DeliveryMap(
                        pickupLat: sLat, pickupLng: sLng,
                        dropoffLat: bLat, dropoffLng: bLng),
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fullscreen, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text('Expand', style: GoogleFonts.poppins(color: Colors.white, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _MapLegend(),
            ],

            const SizedBox(height: 14),
            if (isPending)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF57C00), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hourglass_top_rounded,
                        color: Color(0xFFF57C00), size: 16),
                    const SizedBox(width: 8),
                    Text('Waiting for seller to approve your request',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: const Color(0xFFF57C00))),
                  ],
                ),
              )
            else ...[
              // Proof of delivery section
              if (_proofPath == null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _uploadingProof ? null : _uploadProofOfDelivery,
                    icon: _uploadingProof
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.camera_alt_rounded, size: 18),
                    label: Text(_uploadingProof ? 'Uploading...' : 'Upload Delivery Proof',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Proof uploaded',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.green)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _proofPath == null ? null : widget.onMarkDelivered,
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Mark as Delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _proofPath == null ? Colors.grey : const Color(0xFF388E3C),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvailableCard extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final VoidCallback onTake;

  const _AvailableCard({required this.delivery, required this.onTake});

  @override
  Widget build(BuildContext context) {
    final fee = (delivery['shipping_fee'] as num?)?.toStringAsFixed(2) ?? '0.00';

    final sLat = _toDouble(delivery['seller_lat']);
    final sLng = _toDouble(delivery['seller_lng']);
    final bLat = _toDouble(delivery['buyer_lat']);
    final bLng = _toDouble(delivery['buyer_lng']);
    final hasMap = sLat != null && sLng != null && bLat != null && bLng != null
        && !(sLat == 0 && sLng == 0) && !(bLat == 0 && bLng == 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusBadge(label: 'For Pickup', color: HarayaColors.primary),
                const Spacer(),
                Text('₱$fee',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: HarayaColors.primary)),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.person_rounded, label: delivery['customer_name'] ?? '—'),
            const SizedBox(height: 5),
            _InfoRow(icon: Icons.inventory_2_rounded, label: delivery['product_name'] ?? '—'),
            const SizedBox(height: 5),
            _InfoRow(icon: Icons.location_on_rounded,
                label: delivery['delivery_address'] ?? '—', maxLines: 2),

            // Map — pickup (green/seller) to dropoff (red/buyer)
            if (hasMap) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _FullscreenMap(
                      pickupLat: sLat, pickupLng: sLng,
                      dropoffLat: bLat, dropoffLng: bLng,
                      pickupLabel: 'Garcia Home Furnishings',
                      dropoffLabel: delivery['delivery_address'] ?? delivery['customer_name'] ?? 'Buyer',
                    ),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    _DeliveryMap(
                        pickupLat: sLat, pickupLng: sLng,
                        dropoffLat: bLat, dropoffLng: bLng),
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fullscreen, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text('Expand', style: GoogleFonts.poppins(color: Colors.white, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _MapLegend(),
            ],

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onTake,
                icon: const Icon(Icons.local_shipping_rounded, size: 18),
                label: const Text('Accept Delivery'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF388E3C).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: Color(0xFF388E3C), size: 22),
        ),
        title: Text(item['product_name'] ?? '—',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['customer_name'] ?? '—',
                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF666666))),
            Text(item['delivered_date'] ?? '—',
                style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFFAAAAAA))),
          ],
        ),
        trailing: Text(
          '₱${((item['shipping_fee'] as num?) ?? 0).toStringAsFixed(0)}',
          style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: HarayaColors.primary),
        ),
      ),
    );
  }
}

// ── Shared small widgets ───────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _MapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LegendDot(color: const Color(0xFF2E7D32), label: 'Pickup (Seller)'),
        const SizedBox(width: 16),
        _LegendDot(color: const Color(0xFFC62828), label: 'Dropoff (Buyer)'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF666666))),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 6)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF888888))),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int maxLines;
  const _InfoRow({required this.icon, required this.label, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF888888)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 13, color: HarayaColors.textDark)),
        ),
      ],
    );
  }
}
