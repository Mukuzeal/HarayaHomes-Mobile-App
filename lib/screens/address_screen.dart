import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/api_service.dart';
import '../theme.dart';
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
  int? _selectedAddressId;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final addresses = await ApiService.getAddresses(_userId);
      setState(() {
        _addresses = addresses.cast<Map<String, dynamic>>();
        _selectedAddressId = addresses.isNotEmpty ? addresses[0]['address_id'] : null;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Failed to load addresses: $e");
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load addresses: $e")),
        );
      }
    }
  }

  void _openAddAddressDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddAddressScreen(user: widget.user),
      ),
    ).then((_) => _loadAddresses());
  }

  void _openEditAddressDialog(Map<String, dynamic> address) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditAddressScreen(user: widget.user, address: address),
      ),
    ).then((_) => _loadAddresses());
  }

  Future<void> _deleteAddress(int addressId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Address?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteAddress(_userId, addressId);
        _loadAddresses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Address deleted")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.background,
      appBar: AppBar(
        backgroundColor: HarayaColors.primary,
        title: Text('Manage Addresses',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length,
                  itemBuilder: (_, i) {
                    final addr = _addresses[i];
                    final isDefault = addr['is_default'] == 1;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: isDefault
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.location_on, color: Colors.grey),
                        title: Text(addr['label'] ?? 'Address',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(addr['fullname'] ?? ''),
                            Text(addr['full_address'] ?? '',
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              onTap: () => _openEditAddressDialog(addr),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text("Edit"),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              onTap: () => _deleteAddress(addr['address_id']),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.delete, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text("Delete", style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context, addr);
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: HarayaColors.primary,
        onPressed: _openAddAddressDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No addresses yet',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Add your first address to get started',
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openAddAddressDialog,
            icon: const Icon(Icons.add),
            label: const Text("Add Address"),
            style: ElevatedButton.styleFrom(
              backgroundColor: HarayaColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

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

  final _labelCtrl = TextEditingController();
  final _fullnameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _barangays = [];

  Map<String, dynamic>? _selectedRegion;
  Map<String, dynamic>? _selectedProvince;
  Map<String, dynamic>? _selectedCity;
  Map<String, dynamic>? _selectedBarangay;

  double _latitude = 14.5995;
  double _longitude = 120.9842;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  bool _loading = true;
  bool _saving = false;

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
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    try {
      final regions = await ApiService.getRegions();
      setState(() {
        _regions = regions.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      debugPrint("Failed to load regions: $e");
      setState(() => _loading = false);
    }
  }

  Future<void> _onRegionSelected(Map<String, dynamic> region) async {
    setState(() {
      _selectedRegion = region;
      _selectedProvince = null;
      _selectedCity = null;
      _selectedBarangay = null;
      _provinces = [];
      _cities = [];
      _barangays = [];
    });

    try {
      final provinces = await ApiService.getProvinces(region['region_id']);
      setState(() => _provinces = provinces.cast<Map<String, dynamic>>());
    } catch (e) {
      debugPrint("Failed to load provinces: $e");
    }
  }

  Future<void> _onProvinceSelected(Map<String, dynamic> province) async {
    setState(() {
      _selectedProvince = province;
      _selectedCity = null;
      _selectedBarangay = null;
      _cities = [];
      _barangays = [];
    });

    try {
      final cities = await ApiService.getCities(province['province_id']);
      setState(() => _cities = cities.cast<Map<String, dynamic>>());
    } catch (e) {
      debugPrint("Failed to load cities: $e");
    }
  }

  Future<void> _onCitySelected(Map<String, dynamic> city) async {
    setState(() {
      _selectedCity = city;
      _selectedBarangay = null;
      _barangays = [];
      _latitude = double.tryParse(city['latitude'].toString()) ?? _latitude;
      _longitude = double.tryParse(city['longitude'].toString()) ?? _longitude;
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(_latitude, _longitude)),
    );

    try {
      final barangays = await ApiService.getBarangays(city['city_id']);
      setState(() => _barangays = barangays.cast<Map<String, dynamic>>());
    } catch (e) {
      debugPrint("Failed to load barangays: $e");
    }
  }

  void _onBarangaySelected(Map<String, dynamic> barangay) {
    setState(() {
      _selectedBarangay = barangay;
      _latitude = double.tryParse(barangay['latitude'].toString()) ?? _latitude;
      _longitude = double.tryParse(barangay['longitude'].toString()) ?? _longitude;
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(_latitude, _longitude)),
    );
  }

  Future<void> _detectLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(_latitude, _longitude)),
      );
    } catch (e) {
      debugPrint("Location detection failed: $e");
    }
  }

  void _updateMapMarker() {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected'),
          position: LatLng(_latitude, _longitude),
          infoWindow: InfoWindow(
            title: _selectedBarangay?['barangay_name'] ?? 'Selected Location',
          ),
        ),
      };
    });
  }

  Future<void> _saveAddress() async {
    if (_fullnameCtrl.text.isEmpty ||
        _phoneCtrl.text.isEmpty ||
        _labelCtrl.text.isEmpty ||
        _selectedBarangay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final fullAddress =
          "${_selectedBarangay?['barangay_name']}, ${_selectedCity?['city_name']}, ${_selectedProvince?['province_name']}, ${_selectedRegion?['region_name']}";

      await ApiService.addAddress(
        _userId,
        label: _labelCtrl.text,
        fullname: _fullnameCtrl.text,
        phonenumber: _phoneCtrl.text,
        fullAddress: fullAddress,
        latitude: _latitude,
        longitude: _longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Address added successfully")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.background,
      appBar: AppBar(
        backgroundColor: HarayaColors.primary,
        title: Text('Add Address',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection("Personal Info", [
                    TextField(
                      controller: _labelCtrl,
                      decoration: InputDecoration(
                        labelText: "Label (Home, Office, etc)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _fullnameCtrl,
                      decoration: InputDecoration(
                        labelText: "Full Name",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      decoration: InputDecoration(
                        labelText: "Phone Number",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _buildSection("Location", [
                    _buildDropdown("Region", _selectedRegion, _regions,
                        (region) => _onRegionSelected(region)),
                    const SizedBox(height: 12),
                    _buildDropdown(
                        "Province",
                        _selectedProvince,
                        _provinces,
                        _selectedRegion != null
                            ? (province) => _onProvinceSelected(province)
                            : null),
                    const SizedBox(height: 12),
                    _buildDropdown(
                        "City",
                        _selectedCity,
                        _cities,
                        _selectedProvince != null
                            ? (city) => _onCitySelected(city)
                            : null),
                    const SizedBox(height: 12),
                    _buildDropdown(
                        "Barangay",
                        _selectedBarangay,
                        _barangays,
                        _selectedCity != null
                            ? (barangay) => _onBarangaySelected(barangay)
                            : null),
                  ]),
                  const SizedBox(height: 20),
                  _buildSection("Location on Map", [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 300,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(_latitude, _longitude),
                            zoom: 13,
                          ),
                          onMapCreated: (controller) {
                            _mapController = controller;
                            _updateMapMarker();
                          },
                          markers: _markers,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          onTap: (latLng) {
                            setState(() {
                              _latitude = latLng.latitude;
                              _longitude = latLng.longitude;
                            });
                            _updateMapMarker();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _detectLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text("Use Current Location"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HarayaColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text("Save Address",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              )),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDropdown<T extends Map<String, dynamic>>(
    String label,
    T? selected,
    List<T> items,
    Function(T)? onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<T>(
        value: selected,
        isExpanded: true,
        underline: Container(),
        hint: Text(label),
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    _getItemLabel(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
        onChanged: onChanged != null && items.isNotEmpty
            ? (value) {
                if (value != null) onChanged(value);
              }
            : null,
      ),
    );
  }

  String _getItemLabel(Map<String, dynamic> item) {
    if (item.containsKey('region_name')) return item['region_name'] ?? '';
    if (item.containsKey('province_name')) return item['province_name'] ?? '';
    if (item.containsKey('city_name')) return item['city_name'] ?? '';
    if (item.containsKey('barangay_name')) return item['barangay_name'] ?? '';
    return item.toString();
  }
}

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

  double _latitude = 0;
  double _longitude = 0;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.address['label'] ?? '');
    _fullnameCtrl = TextEditingController(text: widget.address['fullname'] ?? '');
    _phoneCtrl = TextEditingController(text: widget.address['Phonenumber'] ?? '');
    _latitude = double.tryParse(widget.address['latitude'].toString()) ?? 14.5995;
    _longitude = double.tryParse(widget.address['longitude'].toString()) ?? 120.9842;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _fullnameCtrl.dispose();
    _phoneCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _updateMapMarker() {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected'),
          position: LatLng(_latitude, _longitude),
        ),
      };
    });
  }

  Future<void> _saveAddress() async {
    if (_fullnameCtrl.text.isEmpty ||
        _phoneCtrl.text.isEmpty ||
        _labelCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await ApiService.updateAddress(
        _userId,
        widget.address['address_id'],
        label: _labelCtrl.text,
        fullname: _fullnameCtrl.text,
        phonenumber: _phoneCtrl.text,
        latitude: _latitude,
        longitude: _longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Address updated successfully")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.background,
      appBar: AppBar(
        backgroundColor: HarayaColors.primary,
        title: Text('Edit Address',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelCtrl,
              decoration: InputDecoration(
                labelText: "Label",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fullnameCtrl,
              decoration: InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              decoration: InputDecoration(
                labelText: "Phone Number",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),
            Text("Location on Map",
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 300,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_latitude, _longitude),
                    zoom: 13,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _updateMapMarker();
                  },
                  markers: _markers,
                  myLocationEnabled: true,
                  onTap: (latLng) {
                    setState(() {
                      _latitude = latLng.latitude;
                      _longitude = latLng.longitude;
                    });
                    _updateMapMarker();
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HarayaColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Update Address",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
