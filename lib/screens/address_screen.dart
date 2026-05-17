import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/app_animations.dart';
import '../widgets/haraya_widgets.dart';

class AddressScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const AddressScreen({super.key, this.user});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  int get _userId {
    final id = widget.user?['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '0') ?? 0;
  }

  List<Map<String, dynamic>> _addresses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _loading = true);
    try {
      final addresses = await ApiService.getAddresses(_userId);
      setState(() {
        _addresses = addresses.cast<Map<String, dynamic>>();
        _loading   = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        showHarayaSnackBar(context, 'Failed to load addresses: $e',
            isError: true);
      }
    }
  }

  void _openAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddAddressScreen(user: widget.user)),
    ).then((_) => _loadAddresses());
  }

  void _openEdit(Map<String, dynamic> address) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              EditAddressScreen(user: widget.user, address: address)),
    ).then((_) => _loadAddresses());
  }

  Future<void> _delete(int addressId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HarayaRadius.xl)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: HarayaColors.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: HarayaColors.error, size: 26),
        ),
        title: Text('Delete Address?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        content: Text('This action cannot be undone.',
            style: GoogleFonts.poppins(
                fontSize: 13, color: HarayaColors.textMuted),
            textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: HarayaColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: HarayaColors.error,
                foregroundColor: Colors.white),
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await ApiService.deleteAddress(_userId, addressId);
      await _loadAddresses();
      if (mounted) {
        showHarayaSnackBar(context, 'Address deleted',
            icon: Icons.delete_rounded);
      }
    } catch (e) {
      if (mounted) {
        showHarayaSnackBar(context, 'Error: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.sectionBg,
      appBar: AppBar(
        backgroundColor: HarayaColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Addresses',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white),
        ),
      ),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: 3,
              itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: SkeletonListTile(),
                  ))
          : _addresses.isEmpty
              ? EmptyState(
                  icon: Icons.location_off_rounded,
                  title: 'No addresses yet',
                  subtitle: 'Add a delivery address to continue checkout.',
                  buttonLabel: 'Add Address',
                  onAction: _openAdd,
                )
              : RefreshIndicator(
                  onRefresh: _loadAddresses,
                  color: HarayaColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: List.generate(_addresses.length, (i) {
                      final addr      = _addresses[i];
                      final isDefault = addr['is_default'] == 1;
                      return FadeSlideIn(
                        delay: Duration(milliseconds: i * 50),
                        child: _AddressTile(
                          address:   addr,
                          isDefault: isDefault,
                          onSelect:  () => Navigator.pop(context, addr),
                          onEdit:    () => _openEdit(addr),
                          onDelete:  () => _delete(addr['address_id'] as int),
                        ),
                      );
                    }),
                  ),
                ),
      floatingActionButton: _addresses.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: HarayaColors.primary,
              foregroundColor: Colors.white,
              onPressed: _openAdd,
              icon: const Icon(Icons.add_location_alt_rounded),
              label: Text('Add Address',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
    );
  }
}

// ── Address Tile ───────────────────────────────────────────────────────────────
class _AddressTile extends StatelessWidget {
  final Map<String, dynamic> address;
  final bool isDefault;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressTile({
    required this.address,
    required this.isDefault,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onSelect,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(HarayaRadius.lg),
          border: Border.all(
            color: isDefault
                ? HarayaColors.success.withValues(alpha: 0.4)
                : HarayaColors.border,
            width: isDefault ? 1.5 : 0.8,
          ),
          boxShadow: HarayaShadows.card,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDefault
                      ? HarayaColors.success.withValues(alpha: 0.1)
                      : HarayaColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDefault
                      ? Icons.check_circle_rounded
                      : Icons.location_on_rounded,
                  color:
                      isDefault ? HarayaColors.success : HarayaColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          (address['label'] ?? 'Address').toString(),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: HarayaColors.textDark,
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: HarayaColors.success.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(HarayaRadius.pill),
                              border: Border.all(
                                  color: HarayaColors.success
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Default',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: HarayaColors.success,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    if ((address['fullname'] ?? '').toString().isNotEmpty)
                      Text(
                        (address['fullname'] ?? '').toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: HarayaColors.textDark,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      (address['full_address'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: HarayaColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions menu
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HarayaRadius.md)),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined,
                            size: 17, color: HarayaColors.primary),
                        const SizedBox(width: 10),
                        Text('Edit',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: HarayaColors.textDark)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded,
                            size: 17, color: HarayaColors.error),
                        const SizedBox(width: 10),
                        Text('Delete',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: HarayaColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add Address Screen ─────────────────────────────────────────────────────────
class AddAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const AddAddressScreen({super.key, this.user});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  int get _userId {
    final id = widget.user?['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '0') ?? 0;
  }

  final _labelCtrl    = TextEditingController();
  final _fullnameCtrl = TextEditingController();
  final _phoneCtrl    = TextEditingController();

  List<Map<String, dynamic>> _regions   = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities    = [];
  List<Map<String, dynamic>> _barangays = [];

  Map<String, dynamic>? _selectedRegion;
  Map<String, dynamic>? _selectedProvince;
  Map<String, dynamic>? _selectedCity;
  Map<String, dynamic>? _selectedBarangay;

  double _latitude  = 14.5995;
  double _longitude = 120.9842;
  final MapController _mapController = MapController();

  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
    _detectLocation();
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _fullnameCtrl.dispose();
    _phoneCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    try {
      final regions = await ApiService.getRegions();
      setState(() {
        _regions = List<Map<String, dynamic>>.from(
            regions.map((e) => e is Map ? Map<String, dynamic>.from(e) : {}));
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _onRegionSelected(Map<String, dynamic> region) async {
    setState(() {
      _selectedRegion   = region;
      _selectedProvince = null;
      _selectedCity     = null;
      _selectedBarangay = null;
      _provinces = [];
      _cities    = [];
      _barangays = [];
    });
    try {
      final provinces = await ApiService.getProvinces(region['region_id']);
      setState(() => _provinces = List<Map<String, dynamic>>.from(
          provinces.map((e) => e is Map ? Map<String, dynamic>.from(e) : {})));
    } catch (_) {}
  }

  Future<void> _onProvinceSelected(Map<String, dynamic> province) async {
    setState(() {
      _selectedProvince = province;
      _selectedCity     = null;
      _selectedBarangay = null;
      _cities    = [];
      _barangays = [];
    });
    try {
      final cities = await ApiService.getCities(province['province_id']);
      setState(() => _cities = List<Map<String, dynamic>>.from(
          cities.map((e) => e is Map ? Map<String, dynamic>.from(e) : {})));
    } catch (_) {}
  }

  Future<void> _onCitySelected(Map<String, dynamic> city) async {
    setState(() {
      _selectedCity     = city;
      _selectedBarangay = null;
      _barangays        = [];
      _latitude  = double.tryParse(city['latitude'].toString()) ?? _latitude;
      _longitude = double.tryParse(city['longitude'].toString()) ?? _longitude;
    });
    _mapController.move(LatLng(_latitude, _longitude), 14);
    try {
      final barangays = await ApiService.getBarangays(city['city_id']);
      setState(() => _barangays = List<Map<String, dynamic>>.from(
          barangays.map((e) => e is Map ? Map<String, dynamic>.from(e) : {})));
    } catch (_) {}
  }

  void _onBarangaySelected(Map<String, dynamic> barangay) {
    setState(() {
      _selectedBarangay = barangay;
      _latitude  = double.tryParse(barangay['latitude'].toString()) ?? _latitude;
      _longitude = double.tryParse(barangay['longitude'].toString()) ?? _longitude;
    });
    _mapController.move(LatLng(_latitude, _longitude), 14);
  }

  Future<void> _detectLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude  = position.latitude;
        _longitude = position.longitude;
      });
      _mapController.move(LatLng(_latitude, _longitude), 14);
    } catch (_) {}
  }


  Future<void> _save() async {
    if (_fullnameCtrl.text.isEmpty ||
        _phoneCtrl.text.isEmpty ||
        _labelCtrl.text.isEmpty ||
        _selectedBarangay == null) {
      showHarayaSnackBar(context, 'Please fill all required fields.',
          isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final fullAddress =
          '${_selectedBarangay?['barangay_name']}, ${_selectedCity?['city_name']}, '
          '${_selectedProvince?['province_name']}, ${_selectedRegion?['region_name']}';
      await ApiService.addAddress(
        _userId,
        label:       _labelCtrl.text,
        fullname:    _fullnameCtrl.text,
        phonenumber: _phoneCtrl.text,
        fullAddress: fullAddress,
        latitude:    _latitude,
        longitude:   _longitude,
      );
      if (mounted) {
        showHarayaSnackBar(context, 'Address added successfully!',
            icon: Icons.check_circle_rounded);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showHarayaSnackBar(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.sectionBg,
      appBar: AppBar(
        backgroundColor: HarayaColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Add Address',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Personal info
                  FormSectionCard(
                    title: 'Contact Information',
                    icon: Icons.person_outline_rounded,
                    children: [
                      TextFormField(
                        controller: _labelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Label (Home, Office, etc.)',
                          prefixIcon: Icon(Icons.label_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _fullnameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Location dropdowns
                  FormSectionCard(
                    title: 'Location',
                    icon: Icons.location_on_outlined,
                    children: [
                      _LocationDropdown(
                        label: 'Region',
                        selected: _selectedRegion,
                        items: _regions,
                        enabled: _regions.isNotEmpty,
                        getLabel: (i) => i['region_name'] ?? '',
                        onChanged: _onRegionSelected,
                      ),
                      const SizedBox(height: 12),
                      _LocationDropdown(
                        label: 'Province',
                        selected: _selectedProvince,
                        items: _provinces,
                        enabled: _selectedRegion != null && _provinces.isNotEmpty,
                        getLabel: (i) => i['province_name'] ?? '',
                        onChanged: _onProvinceSelected,
                      ),
                      const SizedBox(height: 12),
                      _LocationDropdown(
                        label: 'City / Municipality',
                        selected: _selectedCity,
                        items: _cities,
                        enabled: _selectedProvince != null && _cities.isNotEmpty,
                        getLabel: (i) => i['city_name'] ?? '',
                        onChanged: _onCitySelected,
                      ),
                      const SizedBox(height: 12),
                      _LocationDropdown(
                        label: 'Barangay',
                        selected: _selectedBarangay,
                        items: _barangays,
                        enabled: _selectedCity != null && _barangays.isNotEmpty,
                        getLabel: (i) => i['barangay_name'] ?? '',
                        onChanged: _onBarangaySelected,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Map
                  FormSectionCard(
                    title: 'Pin Location on Map',
                    icon: Icons.map_outlined,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(HarayaRadius.md),
                        child: SizedBox(
                          height: 280,
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: LatLng(_latitude, _longitude),
                              initialZoom: 13,
                              onTap: (_, point) {
                                setState(() {
                                  _latitude  = point.latitude;
                                  _longitude = point.longitude;
                                });
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.haraya.homes',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(_latitude, _longitude),
                                    child: const Icon(
                                      Icons.location_pin,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _detectLocation,
                          icon: const Icon(Icons.my_location_rounded, size: 17),
                          label: Text('Use My Current Location',
                              style: GoogleFonts.poppins(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  LoadingButton(
                    isLoading: _saving,
                    label: 'Save Address',
                    onPressed: _save,
                    icon: Icons.save_rounded,
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Edit Address Screen ────────────────────────────────────────────────────────
class EditAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final Map<String, dynamic> address;
  const EditAddressScreen({super.key, this.user, required this.address});

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  int get _userId {
    final id = widget.user?['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '0') ?? 0;
  }

  late TextEditingController _labelCtrl;
  late TextEditingController _fullnameCtrl;
  late TextEditingController _phoneCtrl;

  double _latitude  = 0;
  double _longitude = 0;
  final MapController _mapController = MapController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _labelCtrl    = TextEditingController(text: widget.address['label']       ?? '');
    _fullnameCtrl = TextEditingController(text: widget.address['fullname']    ?? '');
    _phoneCtrl    = TextEditingController(text: widget.address['Phonenumber'] ?? '');
    _latitude  = double.tryParse(widget.address['latitude'].toString())  ?? 14.5995;
    _longitude = double.tryParse(widget.address['longitude'].toString()) ?? 120.9842;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _fullnameCtrl.dispose();
    _phoneCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_fullnameCtrl.text.isEmpty ||
        _phoneCtrl.text.isEmpty ||
        _labelCtrl.text.isEmpty) {
      showHarayaSnackBar(context, 'Please fill all required fields.',
          isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.updateAddress(
        _userId,
        widget.address['address_id'],
        label:       _labelCtrl.text,
        fullname:    _fullnameCtrl.text,
        phonenumber: _phoneCtrl.text,
        latitude:    _latitude,
        longitude:   _longitude,
      );
      if (mounted) {
        showHarayaSnackBar(context, 'Address updated!',
            icon: Icons.check_circle_rounded);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showHarayaSnackBar(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.sectionBg,
      appBar: AppBar(
        backgroundColor: HarayaColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Edit Address',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormSectionCard(
              title: 'Contact Information',
              icon: Icons.person_outline_rounded,
              children: [
                TextFormField(
                  controller: _labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _fullnameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            FormSectionCard(
              title: 'Pin Location on Map',
              icon: Icons.map_outlined,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(HarayaRadius.md),
                  child: SizedBox(
                    height: 280,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(_latitude, _longitude),
                        initialZoom: 14,
                        onTap: (_, point) {
                          setState(() {
                            _latitude  = point.latitude;
                            _longitude = point.longitude;
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.haraya.homes',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_latitude, _longitude),
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            LoadingButton(
              isLoading: _saving,
              label: 'Update Address',
              onPressed: _save,
              icon: Icons.save_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Location Dropdown ──────────────────────────────────────────────────────────
class _LocationDropdown extends StatelessWidget {
  final String label;
  final Map<String, dynamic>? selected;
  final List<Map<String, dynamic>> items;
  final bool enabled;
  final String Function(Map<String, dynamic>) getLabel;
  final void Function(Map<String, dynamic>) onChanged;

  const _LocationDropdown({
    required this.label,
    required this.selected,
    required this.items,
    required this.enabled,
    required this.getLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: HarayaDuration.normal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: enabled ? HarayaColors.surface : HarayaColors.sectionBg,
        borderRadius: BorderRadius.circular(HarayaRadius.md),
        border: Border.all(
          color: enabled ? HarayaColors.border : HarayaColors.border,
        ),
      ),
      child: DropdownButton<Map<String, dynamic>>(
        value: selected,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        hint: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: enabled ? HarayaColors.textMuted : HarayaColors.textLight,
          ),
        ),
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: HarayaColors.textDark,
        ),
        dropdownColor: Colors.white,
        items: enabled
            ? items
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        getLabel(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                    ))
                .toList()
            : [],
        onChanged: enabled
            ? (value) {
                if (value != null) onChanged(value);
              }
            : null,
      ),
    );
  }
}
