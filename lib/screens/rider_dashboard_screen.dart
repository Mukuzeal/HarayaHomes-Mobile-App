import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/app_animations.dart';
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
      showHarayaSnackBar(context, 'Delivery accepted!',
          icon: Icons.local_shipping_rounded);
      _loadActive(); _loadAvailable(); _loadStats();
    } else {
      showHarayaSnackBar(context, res['message'] ?? 'Failed to take delivery.',
          isError: true);
    }
  }

  Future<void> _markDelivered(int orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HarayaRadius.xl)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: HarayaColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline_rounded,
                    color: HarayaColors.success, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Mark as Delivered?',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: HarayaColors.textDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Confirm that order #$orderId has been successfully delivered.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: HarayaColors.textMuted, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(_, false),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: Text('Cancel',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(_, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HarayaColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Confirm',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final res = await ApiService.riderMarkDelivered(_userId, orderId);
    if (!mounted) return;
    if (res['success'] == true) {
      showHarayaSnackBar(context, 'Order marked as delivered!',
          icon: Icons.task_alt_rounded);
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
      backgroundColor: HarayaColors.sectionBg,
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
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [HarayaColors.primaryDark, HarayaColors.primary],
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
                            Text(
                              'Haraya Haul',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Hi, $_fname',
                              style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded,
                            color: Colors.white, size: 22),
                        tooltip: 'Log out',
                        onPressed: _logout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Online · Ready for deliveries',
                        style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11),
                      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: HarayaColors.border, width: 0.8),
        ),
      ),
      child: _loadingStats
          ? Row(
              children: List.generate(
                4,
                (_) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: HarayaColors.sectionBg,
                      borderRadius: BorderRadius.circular(HarayaRadius.md),
                    ),
                    child: Column(
                      children: [
                        ShimmerBox(
                            width: 20,
                            height: 20,
                            borderRadius: BorderRadius.circular(10)),
                        const SizedBox(height: 6),
                        ShimmerBox(
                            width: 32,
                            height: 14,
                            borderRadius: BorderRadius.circular(4)),
                        const SizedBox(height: 4),
                        ShimmerBox(
                            width: 24,
                            height: 10,
                            borderRadius: BorderRadius.circular(4)),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : Row(
              children: [
                _StatCard(
                    value: _stats['deliveries_today']?.toString() ?? '0',
                    label: 'Today',
                    icon: Icons.local_shipping_rounded,
                    color: HarayaColors.primary),
                _StatCard(
                    value: _stats['pending']?.toString() ?? '0',
                    label: 'Active',
                    icon: Icons.pending_actions_rounded,
                    color: const Color(0xFFE65100)),
                _StatCard(
                    value: _stats['completed']?.toString() ?? '0',
                    label: 'Done',
                    icon: Icons.check_circle_rounded,
                    color: HarayaColors.success),
                _StatCard(
                    value:
                        '₱${((_stats['earnings_today'] as num?) ?? 0).toStringAsFixed(0)}',
                    label: 'Earned',
                    icon: Icons.payments_rounded,
                    color: const Color(0xFF5C3D9F)),
              ],
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
        unselectedLabelColor: HarayaColors.textMuted,
        indicatorColor: HarayaColors.primary,
        indicatorWeight: 3,
        labelStyle:
            GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
        tabs: [
          Tab(text: 'Active (${_active.length})'),
          Tab(text: 'Available (${_available.length})'),
          const Tab(text: 'History'),
        ],
      ),
    );
  }

  Widget _buildListSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(HarayaRadius.lg),
          border: Border.all(color: HarayaColors.border, width: 0.8),
          boxShadow: HarayaShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: HarayaColors.sectionBg,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(HarayaRadius.lg)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ShimmerBox(
                      width: 100,
                      height: 12,
                      borderRadius: BorderRadius.circular(6)),
                  const Spacer(),
                  ShimmerBox(
                      width: 70,
                      height: 12,
                      borderRadius: BorderRadius.circular(6)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                      width: double.infinity,
                      height: 13,
                      borderRadius: BorderRadius.circular(6)),
                  const SizedBox(height: 8),
                  ShimmerBox(
                      width: 220,
                      height: 12,
                      borderRadius: BorderRadius.circular(6)),
                  const SizedBox(height: 8),
                  ShimmerBox(
                      width: 180,
                      height: 12,
                      borderRadius: BorderRadius.circular(6)),
                  const SizedBox(height: 16),
                  ShimmerBox(
                      width: double.infinity,
                      height: 44,
                      borderRadius:
                          BorderRadius.circular(HarayaRadius.md)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Active tab ─────────────────────────────────────────────────────────────
  Widget _buildActiveTab() {
    if (_loadingActive) return _buildListSkeleton();
    if (_active.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_rounded,
        title: 'No active deliveries',
        subtitle: 'Grab one from the Available tab.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadActive,
      color: HarayaColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _active.length,
        itemBuilder: (_, i) => FadeSlideIn(
          delay: Duration(milliseconds: (i % 8) * 50),
          child: _ActiveCard(
            delivery: _active[i],
            onMarkDelivered: () => _markDelivered(_active[i]['order_id'] as int),
          ),
        ),
      ),
    );
  }

  // ── Available tab ──────────────────────────────────────────────────────────
  Widget _buildAvailableTab() {
    if (_loadingAvailable) return _buildListSkeleton();
    if (_available.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No available deliveries',
        subtitle: 'Check back soon for new orders.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAvailable,
      color: HarayaColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _available.length,
        itemBuilder: (_, i) => FadeSlideIn(
          delay: Duration(milliseconds: (i % 8) * 50),
          child: _AvailableCard(
            delivery: _available[i],
            onTake: () => _takeDelivery(_available[i]['order_id'] as int),
          ),
        ),
      ),
    );
  }

  // ── History tab ────────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    if (_loadingHistory) return _buildListSkeleton();
    if (_history.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'No deliveries yet',
        subtitle: 'Your completed deliveries will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: HarayaColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _history.length,
        itemBuilder: (_, i) => FadeSlideIn(
          delay: Duration(milliseconds: (i % 8) * 50),
          child: _HistoryCard(item: _history[i]),
        ),
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
    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '$fromLng,$fromLat;$toLng,$toLat'
        '?overview=full&geometries=geojson&steps=true';
    final resp = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;

      if (routes != null && routes.isNotEmpty) {
        final geometry = routes[0]['geometry'];
        if (geometry is Map && geometry['coordinates'] != null) {
          final coords = (geometry['coordinates'] as List)
              .map((c) =>
                  LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();

          if (coords.isNotEmpty) {
            _routeCache[key] = coords;
            return coords;
          }
        }
      }
    }
  } catch (e) {
    debugPrint('Route fetch failed: $e');
  }

  final fallback = [LatLng(fromLat, fromLng), LatLng(toLat, toLng)];
  _routeCache[key] = fallback;
  return fallback;
}

// ── Delivery Map (inline preview) ────────────────────────────────────────────

class _DeliveryMap extends StatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;

  const _DeliveryMap({
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
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
        widget.pickupLat,
        widget.pickupLng,
        widget.dropoffLat,
        widget.dropoffLng,
      );
      if (mounted) {
        setState(() {
          _routePoints = points;
          _loadingRoute = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup  = LatLng(widget.pickupLat, widget.pickupLng);
    final dropoff = LatLng(widget.dropoffLat, widget.dropoffLng);
    final center  = LatLng(
      (widget.pickupLat + widget.dropoffLat) / 2,
      (widget.pickupLng + widget.dropoffLng) / 2,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(HarayaRadius.md),
      child: SizedBox(
        height: 190,
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
                      width: 36,
                      height: 36,
                      child: const _MapPin(
                          color: Color(0xFF2E7D32),
                          icon: Icons.store_rounded),
                    ),
                    Marker(
                      point: dropoff,
                      width: 36,
                      height: 36,
                      child: const _MapPin(
                          color: Color(0xFFC62828),
                          icon: Icons.home_rounded),
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
      widget.pickupLat,
      widget.pickupLng,
      widget.dropoffLat,
      widget.dropoffLng,
    );
    if (!mounted) return;
    setState(() => _routePoints = points);
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
    final pickup  = LatLng(widget.pickupLat, widget.pickupLng);
    final dropoff = LatLng(widget.dropoffLat, widget.dropoffLng);

    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery Route',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white)),
        backgroundColor: HarayaColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
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
                    width: 44,
                    height: 44,
                    child: const _MapPin(
                        color: Color(0xFF2E7D32), icon: Icons.store_rounded),
                  ),
                  Marker(
                    point: dropoff,
                    width: 44,
                    height: 44,
                    child: const _MapPin(
                        color: Color(0xFFC62828), icon: Icons.home_rounded),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(HarayaRadius.lg),
                boxShadow: HarayaShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LegendRow(
                    color: const Color(0xFF2E7D32),
                    icon: Icons.store_rounded,
                    label: 'Pickup: ${widget.pickupLabel}',
                  ),
                  const SizedBox(height: 8),
                  _LegendRow(
                    color: const Color(0xFFC62828),
                    icon: Icons.home_rounded,
                    label: 'Deliver to: ${widget.dropoffLabel}',
                  ),
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
  const _LegendRow(
      {required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
                fontSize: 12, color: HarayaColors.textDark),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
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
      final userId  = (widget.delivery['rider_id'] as int?) ?? 0;
      final orderId = widget.delivery['order_id'] as int;
      final result  = await ApiService.uploadProofOfDelivery(userId, orderId, imagePath);
      if (!mounted) return;

      if (result['success'] == true) {
        setState(() => _proofPath = result['photo_url']);
        showHarayaSnackBar(context, 'Proof uploaded successfully!',
            icon: Icons.camera_alt_rounded);
      } else {
        showHarayaSnackBar(
            context, result['error'] ?? 'Upload failed.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        showHarayaSnackBar(context, 'Error: $e', isError: true);
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
    final status     = widget.delivery['delivery_status'] ?? 'ontheway';
    final isPending  = status == 'pending_approval';
    final isPickedUp = status == 'picked_up';

    final statusColor = isPending
        ? const Color(0xFFF57C00)
        : isPickedUp
            ? HarayaColors.success
            : HarayaColors.primary;
    final statusLabel = isPending
        ? 'Awaiting Seller Approval'
        : isPickedUp
            ? 'Picked Up'
            : 'On the Way';
    final statusIcon = isPending
        ? Icons.hourglass_top_rounded
        : isPickedUp
            ? Icons.inventory_2_rounded
            : Icons.local_shipping_rounded;

    final sLat = _toDouble(widget.delivery['seller_lat']);
    final sLng = _toDouble(widget.delivery['seller_lng']);
    final bLat = _toDouble(widget.delivery['buyer_lat']);
    final bLng = _toDouble(widget.delivery['buyer_lng']);
    final hasMap = sLat != null &&
        sLng != null &&
        bLat != null &&
        bLng != null &&
        !(sLat == 0 && sLng == 0) &&
        !(bLat == 0 && bLng == 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(HarayaRadius.lg),
        border: Border.all(color: HarayaColors.border, width: 0.8),
        boxShadow: HarayaShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(HarayaRadius.lg)),
              border: Border(
                bottom: BorderSide(
                    color: statusColor.withValues(alpha: 0.15), width: 0.8),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, size: 15, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor),
                ),
                const Spacer(),
                Text(
                  'Order #${widget.delivery['order_id']}',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: HarayaColors.textMuted),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: (widget.delivery['customer_name'] ?? '—').toString()),
                const SizedBox(height: 6),
                _InfoRow(
                    icon: Icons.inventory_2_outlined,
                    label: (widget.delivery['product_name'] ?? '—').toString()),
                const SizedBox(height: 6),
                _InfoRow(
                    icon: Icons.location_on_outlined,
                    label:
                        (widget.delivery['delivery_address'] ?? '—').toString(),
                    maxLines: 2),

                if (hasMap) ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _FullscreenMap(
                          pickupLat: sLat,
                          pickupLng: sLng,
                          dropoffLat: bLat,
                          dropoffLng: bLng,
                          pickupLabel:
                              (widget.delivery['seller_address'] ?? 'Seller')
                                  .toString(),
                          dropoffLabel: (widget.delivery['delivery_address'] ??
                                  widget.delivery['customer_name'] ??
                                  'Buyer')
                              .toString(),
                        ),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        _DeliveryMap(
                            pickupLat: sLat,
                            pickupLng: sLng,
                            dropoffLat: bLat,
                            dropoffLng: bLng),
                        Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius:
                                BorderRadius.circular(HarayaRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.fullscreen,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text('Expand',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white, fontSize: 10)),
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
                      borderRadius: BorderRadius.circular(HarayaRadius.md),
                      border: Border.all(
                          color: const Color(0xFFF57C00).withValues(alpha: 0.4),
                          width: 0.8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.hourglass_top_rounded,
                            color: Color(0xFFF57C00), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Waiting for seller to approve your request',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: const Color(0xFFF57C00)),
                        ),
                      ],
                    ),
                  )
                else ...[
                  if (_proofPath == null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _uploadingProof ? null : _uploadProofOfDelivery,
                        icon: _uploadingProof
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera_alt_rounded, size: 18),
                        label: Text(
                          _uploadingProof
                              ? 'Uploading...'
                              : 'Upload Delivery Proof',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HarayaColors.primary,
                          foregroundColor: Colors.white,
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
                        color: HarayaColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(HarayaRadius.md),
                        border: Border.all(
                            color: HarayaColors.success.withValues(alpha: 0.3),
                            width: 0.8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              color: HarayaColors.success, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Proof of delivery uploaded',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: HarayaColors.success),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _proofPath == null ? null : widget.onMarkDelivered,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Mark as Delivered'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _proofPath == null
                            ? HarayaColors.textMuted
                            : HarayaColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
    final hasMap = sLat != null &&
        sLng != null &&
        bLat != null &&
        bLng != null &&
        !(sLat == 0 && sLng == 0) &&
        !(bLat == 0 && bLng == 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(HarayaRadius.lg),
        border: Border.all(color: HarayaColors.border, width: 0.8),
        boxShadow: HarayaShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: HarayaColors.primary.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(HarayaRadius.lg)),
              border: Border(
                bottom: BorderSide(
                    color: HarayaColors.primary.withValues(alpha: 0.15),
                    width: 0.8),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_outlined,
                    size: 15, color: HarayaColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Available for Pickup',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: HarayaColors.primary),
                ),
                const Spacer(),
                Text(
                  '₱$fee',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: HarayaColors.priceRed,
                      letterSpacing: -0.3),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: (delivery['customer_name'] ?? '—').toString()),
                const SizedBox(height: 6),
                _InfoRow(
                    icon: Icons.inventory_2_outlined,
                    label: (delivery['product_name'] ?? '—').toString()),
                const SizedBox(height: 6),
                _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: (delivery['delivery_address'] ?? '—').toString(),
                    maxLines: 2),

                if (hasMap) ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _FullscreenMap(
                          pickupLat: sLat,
                          pickupLng: sLng,
                          dropoffLat: bLat,
                          dropoffLng: bLng,
                          pickupLabel: 'Seller',
                          dropoffLabel: (delivery['delivery_address'] ??
                                  delivery['customer_name'] ??
                                  'Buyer')
                              .toString(),
                        ),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        _DeliveryMap(
                            pickupLat: sLat,
                            pickupLng: sLng,
                            dropoffLat: bLat,
                            dropoffLng: bLng),
                        Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius:
                                BorderRadius.circular(HarayaRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.fullscreen,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text('Expand',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white, fontSize: 10)),
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
                        padding: const EdgeInsets.symmetric(vertical: 12)),
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

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(HarayaRadius.lg),
        border: Border.all(color: HarayaColors.border, width: 0.8),
        boxShadow: HarayaShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: HarayaColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(HarayaRadius.md),
              ),
              child: Icon(Icons.check_circle_outline_rounded,
                  color: HarayaColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['product_name'] ?? '—').toString(),
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: HarayaColors.textDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (item['customer_name'] ?? '—').toString(),
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: HarayaColors.textMuted),
                  ),
                  Text(
                    (item['delivered_date'] ?? '—').toString(),
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: HarayaColors.textLight),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '₱${((item['shipping_fee'] as num?) ?? 0).toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: HarayaColors.priceRed),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared small widgets ───────────────────────────────────────────────────────

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
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10, color: HarayaColors.textMuted)),
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
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(HarayaRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 0.8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.3),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                  fontSize: 10, color: HarayaColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int maxLines;

  const _InfoRow(
      {required this.icon, required this.label, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: HarayaColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                fontSize: 13, color: HarayaColors.textDark, height: 1.4),
          ),
        ),
      ],
    );
  }
}
