import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/haraya_widgets.dart';

class RiderApplyScreen extends StatefulWidget {
  final String userEmail;
  const RiderApplyScreen({super.key, required this.userEmail});

  @override
  State<RiderApplyScreen> createState() => _RiderApplyScreenState();
}

class _RiderApplyScreenState extends State<RiderApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _submitted = false;

  // Personal info
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _birthdayCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _gender;

  // Address
  final _regionCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _barangayCtrl = TextEditingController();
  final _exactAddressCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();

  // Vehicle
  String? _vehicleType;
  final _vehicleModelCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();

  // Files
  String? _vehicleFrontPath, _vehicleFrontName;
  String? _vehicleBackPath, _vehicleBackName;
  String? _validIdPath, _validIdName;
  String? _licensePath, _licenseName;
  String? _orcrPath, _orcrName;

  static const List<String> _vehicleTypes = [
    'Motorcycle',
    'Bicycle',
    'Electric Bike',
    'Scooter',
    'Others',
  ];

  static const List<String> _genders = ['Male', 'Female', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.userEmail;
  }

  @override
  void dispose() {
    for (final c in [_firstNameCtrl, _lastNameCtrl, _birthdayCtrl, _ageCtrl,
      _contactCtrl, _emailCtrl, _regionCtrl, _provinceCtrl, _cityCtrl,
      _barangayCtrl, _exactAddressCtrl, _zipCtrl, _vehicleModelCtrl, _plateCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFile(String field) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null) return;
    final file = result.files.single;
    setState(() {
      switch (field) {
        case 'vehicle_front': _vehicleFrontPath = file.path; _vehicleFrontName = file.name; break;
        case 'vehicle_back': _vehicleBackPath = file.path; _vehicleBackName = file.name; break;
        case 'valid_id': _validIdPath = file.path; _validIdName = file.name; break;
        case 'license': _licensePath = file.path; _licenseName = file.name; break;
        case 'orcr': _orcrPath = file.path; _orcrName = file.name; break;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: HarayaColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final formatted = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _birthdayCtrl.text = formatted;
      final age = DateTime.now().year - picked.year;
      _ageCtrl.text = age.toString();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final missingFiles = <String>[];
    if (_vehicleFrontPath == null) missingFiles.add('Vehicle Front Photo');
    if (_vehicleBackPath == null) missingFiles.add('Vehicle Back Photo');
    if (_validIdPath == null) missingFiles.add('Valid ID');
    if (_licensePath == null) missingFiles.add("Driver's License");
    if (_orcrPath == null) missingFiles.add('OR/CR');

    if (missingFiles.isNotEmpty) {
      showHarayaSnackBar(context, 'Please upload: ${missingFiles.join(', ')}', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await ApiService.submitRiderApplication(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        birthday: _birthdayCtrl.text.trim(),
        age: _ageCtrl.text.trim(),
        gender: _gender ?? '',
        contactNumber: _contactCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        region: _regionCtrl.text.trim(),
        province: _provinceCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        barangay: _barangayCtrl.text.trim(),
        exactAddress: _exactAddressCtrl.text.trim(),
        zipCode: _zipCtrl.text.trim(),
        vehicleType: _vehicleType ?? '',
        vehicleModel: _vehicleModelCtrl.text.trim(),
        plateNumber: _plateCtrl.text.trim(),
        vehicleFrontPath: _vehicleFrontPath!,
        vehicleBackPath: _vehicleBackPath!,
        validIdPath: _validIdPath!,
        licensePath: _licensePath!,
        orcrPath: _orcrPath!,
      );

      if (!mounted) return;
      if (result['success'] == true) {
        setState(() => _submitted = true);
      } else {
        showHarayaSnackBar(context, result['message'] ?? 'Submission failed.', isError: true);
      }
    } catch (e) {
      if (mounted) showHarayaSnackBar(context, 'Connection error. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Apply as Rider', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HarayaColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: HarayaColors.success, size: 64),
            ),
            const SizedBox(height: 24),
            Text('Application Submitted!',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: HarayaColors.textDark),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'Your rider application has been received. We\'ll review your documents and send an approval email.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF666666), height: 1.6),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF4A90A4).withOpacity(0.08), const Color(0xFF4A90A4).withOpacity(0.03)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4A90A4).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90A4).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delivery_dining_rounded, color: Color(0xFF4A90A4), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rider Application',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF4A90A4))),
                        const SizedBox(height: 4),
                        Text('Complete all fields and upload the required documents.',
                            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF666666), height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Personal Information ───────────────────────────────
            FormSectionCard(
              title: 'Personal Information',
              icon: Icons.person_rounded,
              children: [
                Row(children: [
                  Expanded(child: _field(_firstNameCtrl, 'First Name', required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_lastNameCtrl, 'Last Name', required: true)),
                ]),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _birthdayCtrl,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: const InputDecoration(
                    labelText: 'Birthday *',
                    prefixIcon: Icon(Icons.calendar_today_outlined, color: HarayaColors.primary),
                    suffixIcon: Icon(Icons.edit_calendar_outlined, color: HarayaColors.primary),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                Row(children: [
                  SizedBox(
                    width: 100,
                    child: _field(_ageCtrl, 'Age', type: TextInputType.number, required: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(labelText: 'Gender *'),
                      items: _genders
                          .map((g) => DropdownMenuItem(value: g, child: Text(g, style: GoogleFonts.poppins(fontSize: 14))))
                          .toList(),
                      onChanged: (v) => setState(() => _gender = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                _field(_contactCtrl, 'Contact Number', type: TextInputType.phone, required: true),
                const SizedBox(height: 14),
                _field(_emailCtrl, 'Email Address', type: TextInputType.emailAddress, required: true),
              ],
            ),

            // ── Address ────────────────────────────────────────────
            FormSectionCard(
              title: 'Home Address',
              icon: Icons.home_rounded,
              children: [
                Row(children: [
                  Expanded(child: _field(_regionCtrl, 'Region', required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_provinceCtrl, 'Province', required: true)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _field(_cityCtrl, 'City / Municipality', required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_barangayCtrl, 'Barangay', required: true)),
                ]),
                const SizedBox(height: 14),
                _field(_exactAddressCtrl, 'Street / Unit / Building', required: true),
                const SizedBox(height: 14),
                _field(_zipCtrl, 'ZIP Code', type: TextInputType.number, required: true),
              ],
            ),

            // ── Vehicle ────────────────────────────────────────────
            FormSectionCard(
              title: 'Vehicle Details',
              icon: Icons.two_wheeler_rounded,
              children: [
                DropdownButtonFormField<String>(
                  value: _vehicleType,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Type *',
                    prefixIcon: Icon(Icons.two_wheeler_rounded, color: HarayaColors.primary),
                  ),
                  items: _vehicleTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.poppins(fontSize: 14))))
                      .toList(),
                  onChanged: (v) => setState(() => _vehicleType = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _field(_vehicleModelCtrl, 'Vehicle Model / Brand', required: true),
                const SizedBox(height: 14),
                _field(_plateCtrl, 'Plate Number', required: true),
              ],
            ),

            // ── Documents ──────────────────────────────────────────
            FormSectionCard(
              title: 'Required Documents',
              icon: Icons.folder_outlined,
              children: [
                Text(
                  'Upload photos or PDFs. Max 5MB per file.',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF888888)),
                ),
                const SizedBox(height: 16),
                FilePickerField(
                  label: 'Vehicle Photo – Front',
                  fileName: _vehicleFrontName,
                  onTap: () => _pickFile('vehicle_front'),
                  isRequired: true,
                ),
                const SizedBox(height: 14),
                FilePickerField(
                  label: 'Vehicle Photo – Back',
                  fileName: _vehicleBackName,
                  onTap: () => _pickFile('vehicle_back'),
                  isRequired: true,
                ),
                const SizedBox(height: 14),
                FilePickerField(
                  label: 'Valid Government ID',
                  fileName: _validIdName,
                  onTap: () => _pickFile('valid_id'),
                  isRequired: true,
                ),
                const SizedBox(height: 14),
                FilePickerField(
                  label: "Driver's License",
                  fileName: _licenseName,
                  onTap: () => _pickFile('license'),
                  isRequired: true,
                ),
                const SizedBox(height: 14),
                FilePickerField(
                  label: 'OR/CR (Official Receipt / Certificate of Registration)',
                  fileName: _orcrName,
                  onTap: () => _pickFile('orcr'),
                  isRequired: true,
                ),
              ],
            ),

            LoadingButton(isLoading: _loading, label: 'Submit Application', onPressed: _submit),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType type = TextInputType.text,
    bool required = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(labelText: required ? '$label *' : label),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
    );
  }
}
