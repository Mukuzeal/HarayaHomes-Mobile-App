import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/haraya_widgets.dart';

class SellerApplyScreen extends StatefulWidget {
  final String userEmail;
  const SellerApplyScreen({super.key, required this.userEmail});

  @override
  State<SellerApplyScreen> createState() => _SellerApplyScreenState();
}

class _SellerApplyScreenState extends State<SellerApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _submitted = false;

  // Controllers
  final _storeNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _barangayCtrl = TextEditingController();
  final _exactAddressCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  String? _productCategory;

  // Files
  String? _validIdPath;
  String? _validIdName;
  String? _documentPath;
  String? _documentName;

  static const List<String> _categories = [
    'Food & Beverages',
    'Fresh Produce',
    'Clothing & Apparel',
    'Electronics',
    'Home & Living',
    'Health & Beauty',
    'Arts & Crafts',
    'Books & Stationery',
    'Toys & Games',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.userEmail;
  }

  @override
  void dispose() {
    for (final c in [_storeNameCtrl, _ownerNameCtrl, _phoneCtrl, _emailCtrl,
      _regionCtrl, _provinceCtrl, _cityCtrl, _barangayCtrl, _exactAddressCtrl, _zipCtrl]) {
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
      if (field == 'valid_id') {
        _validIdPath = file.path;
        _validIdName = file.name;
      } else {
        _documentPath = file.path;
        _documentName = file.name;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_validIdPath == null) {
      showHarayaSnackBar(context, 'Please upload your valid ID.', isError: true);
      return;
    }
    if (_documentPath == null) {
      showHarayaSnackBar(context, 'Please upload your business document.', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await ApiService.submitSellerApplication(
        storeName: _storeNameCtrl.text.trim(),
        ownerName: _ownerNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        region: _regionCtrl.text.trim(),
        province: _provinceCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        barangay: _barangayCtrl.text.trim(),
        exactAddress: _exactAddressCtrl.text.trim(),
        zipCode: _zipCtrl.text.trim(),
        productCategory: _productCategory ?? '',
        validIdPath: _validIdPath!,
        documentPath: _documentPath!,
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
        title: Text('Apply as Seller', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
              'Your seller application has been received and is now under review. We\'ll notify you via email once it\'s approved.',
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
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [HarayaColors.primary.withOpacity(0.08), HarayaColors.primaryLight.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HarayaColors.primary.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: HarayaColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: HarayaColors.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Seller Application',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: HarayaColors.primary)),
                        const SizedBox(height: 4),
                        Text('Fill in your details to apply as a seller on Haraya.',
                            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF666666), height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Store Information ──────────────────────────────────
            FormSectionCard(
              title: 'Store Information',
              icon: Icons.store_rounded,
              children: [
                _field(_storeNameCtrl, 'Store Name', Icons.storefront_outlined, required: true),
                const SizedBox(height: 14),
                _field(_ownerNameCtrl, 'Owner / Representative Name', Icons.person_outline),
                const SizedBox(height: 14),
                _field(_phoneCtrl, 'Phone Number', Icons.phone_outlined,
                    type: TextInputType.phone, required: true),
                const SizedBox(height: 14),
                _field(_emailCtrl, 'Email Address', Icons.email_outlined,
                    type: TextInputType.emailAddress, required: true),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _productCategory,
                  decoration: const InputDecoration(
                    labelText: 'Product Category *',
                    prefixIcon: Icon(Icons.category_outlined, color: HarayaColors.primary),
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.poppins(fontSize: 14))))
                      .toList(),
                  onChanged: (v) => setState(() => _productCategory = v),
                  validator: (v) => v == null ? 'Please select a category' : null,
                ),
              ],
            ),

            // ── Address ────────────────────────────────────────────
            FormSectionCard(
              title: 'Business Address',
              icon: Icons.location_on_rounded,
              children: [
                Row(children: [
                  Expanded(child: _field(_regionCtrl, 'Region', null, required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_provinceCtrl, 'Province', null, required: true)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _field(_cityCtrl, 'City / Municipality', null, required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_barangayCtrl, 'Barangay', null, required: true)),
                ]),
                const SizedBox(height: 14),
                _field(_exactAddressCtrl, 'Street / Unit / Building', Icons.home_outlined, required: true),
                const SizedBox(height: 14),
                _field(_zipCtrl, 'ZIP Code', Icons.markunread_mailbox_outlined,
                    type: TextInputType.number, required: true),
              ],
            ),

            // ── Documents ──────────────────────────────────────────
            FormSectionCard(
              title: 'Required Documents',
              icon: Icons.folder_outlined,
              children: [
                Text(
                  'Upload clear images or PDFs. Max file size: 5MB each.',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF888888)),
                ),
                const SizedBox(height: 16),
                FilePickerField(
                  label: 'Valid Government ID',
                  fileName: _validIdName,
                  onTap: () => _pickFile('valid_id'),
                  isRequired: true,
                ),
                const SizedBox(height: 14),
                FilePickerField(
                  label: 'Business Document (DTI / BIR / Permit)',
                  fileName: _documentName,
                  onTap: () => _pickFile('document'),
                  isRequired: true,
                ),
              ],
            ),

            // ── Submit ─────────────────────────────────────────────
            LoadingButton(isLoading: _loading, label: 'Submit Application', onPressed: _submit),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData? icon, {
    TextInputType type = TextInputType.text,
    bool required = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: icon != null ? Icon(icon, color: HarayaColors.primary) : null,
      ),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
    );
  }
}
