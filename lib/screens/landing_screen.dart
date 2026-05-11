import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'seller_apply_screen.dart';
import 'rider_apply_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scrollCtrl = ScrollController();
  final _aboutKey  = GlobalKey();
  final _sellerKey = GlobalKey();
  final _riderKey  = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
  }

  void _goLogin() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HarayaColors.background,
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildHero()),
          SliverToBoxAdapter(child: _buildAbout()),
          SliverToBoxAdapter(child: _buildApplySeller()),
          SliverToBoxAdapter(child: _buildApplyRider()),
          SliverToBoxAdapter(child: _buildFooter()),
        ],
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: HarayaColors.headerBg,
      elevation: 2,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const Icon(Icons.home_rounded, color: HarayaColors.primary, size: 24),
          const SizedBox(width: 6),
          Text('HarayaHomes',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: HarayaColors.primary)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _scrollTo(_aboutKey),
          child: Text('About', style: GoogleFonts.poppins(fontSize: 12, color: HarayaColors.textDark)),
        ),
        TextButton(
          onPressed: () => _scrollTo(_sellerKey),
          child: Text('Seller', style: GoogleFonts.poppins(fontSize: 12, color: HarayaColors.textDark)),
        ),
        TextButton(
          onPressed: () => _scrollTo(_riderKey),
          child: Text('Rider', style: GoogleFonts.poppins(fontSize: 12, color: HarayaColors.textDark)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ElevatedButton(
            onPressed: _goLogin,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            child: const Text('Log in'),
          ),
        ),
      ],
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHero() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFE8DB), Color(0xFFD6E8F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: HarayaColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('🏠  Filipino Marketplace',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HarayaColors.primary)),
              ),
              const SizedBox(height: 20),
              Text('HarayaHomes',
                  style: GoogleFonts.poppins(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: HarayaColors.textDark,
                      height: 1.1)),
              const SizedBox(height: 14),
              Text(
                'The Filipino Marketplace for\nHome Essentials & Garden Living',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: const Color(0xFF555555),
                    height: 1.6),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _scrollTo(_aboutKey),
                    child: const Text('Explore Now'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _goLogin,
                    child: const Text('Get Started'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── About ─────────────────────────────────────────────────────────────────
  Widget _buildAbout() {
    return Container(
      key: _aboutKey,
      color: HarayaColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionBadge(label: 'About Us'),
          const SizedBox(height: 16),
          Text('Connecting Filipino\nHomes & Hearts',
              style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: HarayaColors.textDark,
                  height: 1.25)),
          const SizedBox(height: 20),
          Text(
            'Welcome to HarayaHomes — the Filipino marketplace built for every home and garden lover. '
            'We believe that every home deserves a touch of creativity and comfort. '
            'Our platform connects local sellers and artisans offering sustainable, high-quality home '
            'essentials, furniture, and garden products that bring your space to life.',
            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF555555), height: 1.7),
          ),
          const SizedBox(height: 14),
          Text(
            'At HarayaHomes, we aim to support small Filipino entrepreneurs and promote eco-friendly '
            'living — because a beautiful home starts with mindful choices.',
            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF555555), height: 1.7),
          ),
        ],
      ),
    );
  }

  // ── Apply as Seller ───────────────────────────────────────────────────────
  Widget _buildApplySeller() {
    return _ApplySection(
      sectionKey: _sellerKey,
      backgroundColor: HarayaColors.sectionBg,
      icon: Icons.storefront_rounded,
      title: 'Apply as a Seller',
      body: 'Share your home and garden creations with a community that loves creativity as much as you do! '
          'At HarayaHomes, we bring together passionate makers, decorators, and dreamers who turn '
          'houses into homes. Grow your small business with people who truly appreciate your craft.',
      benefits: const [
        (Icons.trending_up_rounded,   'Grow Your Business'),
        (Icons.group_rounded,         'Connect with Customers'),
        (Icons.shield_rounded,        'Secure Transactions'),
      ],
      buttonLabel: 'Become a Seller',
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SellerApplyScreen(userEmail: ''))),
    );
  }

  // ── Apply as Rider ────────────────────────────────────────────────────────
  Widget _buildApplyRider() {
    return _ApplySection(
      sectionKey: _riderKey,
      backgroundColor: HarayaColors.background,
      icon: Icons.two_wheeler_rounded,
      title: 'Apply as a Rider',
      body: 'Join Haraya Haul — our dedicated delivery network that connects sellers and customers '
          'with reliable riders across communities. As a Haraya Rider, you\'ll help deliver more '
          'than just products — you\'ll bring convenience, trust, and smiles to every Filipino household.',
      benefits: const [
        (Icons.schedule_rounded,         'Flexible Schedule'),
        (Icons.payments_rounded,         'Competitive Pay'),
        (Icons.map_rounded,              'Local Routes'),
      ],
      buttonLabel: 'Become a Rider',
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const RiderApplyScreen(userEmail: ''))),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      color: HarayaColors.headerBg,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.home_rounded, color: HarayaColors.primary, size: 18),
              const SizedBox(width: 6),
              Text('HarayaHomes',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: HarayaColors.primary,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Text('© 2025 HarayaHomes. All rights reserved.',
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF888888))),
          const SizedBox(height: 4),
          Text('DISCLAIMER: This App is a Group Project.',
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFAAAAAA))),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionBadge extends StatelessWidget {
  final String label;
  const _SectionBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: HarayaColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: HarayaColors.primary)),
    );
  }
}

class _ApplySection extends StatelessWidget {
  final Key? sectionKey;
  final Color backgroundColor;
  final IconData icon;
  final String title;
  final String body;
  final List<(IconData, String)> benefits;
  final String buttonLabel;
  final VoidCallback onTap;

  const _ApplySection({
    this.sectionKey,
    required this.backgroundColor,
    required this.icon,
    required this.title,
    required this.body,
    required this.benefits,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: sectionKey,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: HarayaColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: HarayaColors.primary, size: 28),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: HarayaColors.textDark)),
          const SizedBox(height: 14),
          Text(body,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: const Color(0xFF555555), height: 1.7)),
          const SizedBox(height: 24),
          ...benefits.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: HarayaColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(b.$1, color: HarayaColors.primary, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Text(b.$2,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: HarayaColors.textDark)),
                  ],
                ),
              )),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
