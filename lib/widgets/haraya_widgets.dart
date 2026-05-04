import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

// ─── Haraya Logo Text ───────────────────────────────────────────────────────
class HarayaLogo extends StatelessWidget {
  final double fontSize;
  const HarayaLogo({super.key, this.fontSize = 24});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: fontSize * 1.5,
          height: fontSize * 1.5,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [HarayaColors.primary, HarayaColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(Icons.home_rounded, color: Colors.white, size: fontSize * 0.9),
        ),
        const SizedBox(width: 10),
        Text(
          'Haraya',
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: HarayaColors.textDark,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ─── Section Header ─────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: HarayaColors.primary,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF666666),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

// ─── Snack Bar Helper ────────────────────────────────────────────────────────
void showHarayaSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: isError ? HarayaColors.error : HarayaColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ),
  );
}

// ─── Loading Button ──────────────────────────────────────────────────────────
class LoadingButton extends StatelessWidget {
  final bool isLoading;
  final String label;
  final VoidCallback? onPressed;
  final double? width;

  const LoadingButton({
    super.key,
    required this.isLoading,
    required this.label,
    this.onPressed,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Text(label),
      ),
    );
  }
}

// ─── File Picker Field ───────────────────────────────────────────────────────
class FilePickerField extends StatelessWidget {
  final String label;
  final String? fileName;
  final VoidCallback onTap;
  final bool isRequired;

  const FilePickerField({
    super.key,
    required this.label,
    this.fileName,
    required this.onTap,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label${isRequired ? ' *' : ''}',
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF444444)),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: fileName != null ? HarayaColors.primary : const Color(0xFFCDD9E8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  fileName != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                  color: fileName != null ? HarayaColors.success : HarayaColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fileName ?? 'Tap to upload (PDF, JPG, PNG – max 5MB)',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: fileName != null ? HarayaColors.textDark : const Color(0xFFAAAAAA),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Form Section Card ───────────────────────────────────────────────────────
class FormSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const FormSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: HarayaColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: HarayaColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: HarayaColors.textDark),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
